"""
kdbx.py
-------
Minimal KeePass KDBX 4.x reader/writer built only on `cryptography` and
the standard library (no pykeepass / lxml needed on the device).

Supported
  * KDBX 4.0 / 4.1 (KeePass 2.35+, KeePassXC, KeePassDX, Strongbox ...)
  * Outer cipher: AES-256-CBC and ChaCha20
  * KDF: AES-KDF (always) and Argon2d / Argon2id (needs `argon2-cffi`
    importable; Argon2id also works with cryptography >= 44)
  * Inner stream: ChaCha20 (the KeePass default)
  * Password-only credentials

Not supported (a clear KdbxError is raised instead of guessing)
  * KDBX 3.x, Salsa20 inner stream, key files / Windows-account keys

Safety: the XML tree is kept as-is in memory and only the standard
fields the app edits are touched, so custom fields, attachments, history,
icons, nested groups, TOTP secrets etc. survive a save untouched.
"""

import base64
import copy
import gzip
import hashlib
import hmac
import os
import secrets
import shutil
import struct
import time
import uuid as uuid_mod
import xml.etree.ElementTree as ET
from datetime import datetime, timezone

from cryptography.hazmat.primitives import padding
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes

SIG1 = 0x9AA2D903
SIG2 = 0xB54BFB67

CIPHER_AES = bytes.fromhex("31c1f2e6bf714350be5805216afc5aff")
CIPHER_CHACHA = bytes.fromhex("d6038a2b8b6f4cb5a524339a31dbb59a")
KDF_AES = bytes.fromhex("c9d9f39a628a4460bf740d08c18a4fea")
KDF_ARGON2D = bytes.fromhex("ef636ddf8c29444b91f7a9a403e30a0c")
KDF_ARGON2ID = bytes.fromhex("9e298b1956db4773b23dfc3ec6f0a1e6")

BLOCK_SIZE = 1024 * 1024
GENERAL = "General"
PATH_SEP = " / "


class KdbxError(Exception):
    """`.code` is a short machine-readable reason (used by the UI)."""

    def __init__(self, code, detail=""):
        super().__init__(code + (": " + detail if detail else ""))
        self.code = code


# --------------------------------------------------------------------- utils

def _sha256(*parts):
    h = hashlib.sha256()
    for p in parts:
        h.update(p)
    return h.digest()


def _sha512(*parts):
    h = hashlib.sha512()
    for p in parts:
        h.update(p)
    return h.digest()


def is_kdbx(path):
    try:
        with open(path, "rb") as f:
            s1, s2 = struct.unpack("<II", f.read(8))
        return s1 == SIG1 and s2 == SIG2
    except Exception:
        return False


def _ticks_now():
    """KDBX4 timestamp: base64(uint64 LE seconds since 0001-01-01 UTC)."""
    epoch = datetime(1, 1, 1, tzinfo=timezone.utc)
    secs = int((datetime.now(timezone.utc) - epoch).total_seconds())
    return base64.b64encode(struct.pack("<Q", secs)).decode("ascii")


def _ticks_to_unix(text):
    """Inverse of _ticks_now(); also accepts KDBX3-style ISO strings.
    Returns seconds since the Unix epoch, or 0 when unknown."""
    if not text:
        return 0
    try:
        raw = base64.b64decode(text)
        if len(raw) == 8:
            secs = struct.unpack("<Q", raw)[0]
            return max(0, secs - 62135596800)   # 0001-01-01 -> 1970-01-01
    except Exception:
        pass
    try:
        dt = datetime.strptime(text.strip(), "%Y-%m-%dT%H:%M:%SZ")
        return int(dt.replace(tzinfo=timezone.utc).timestamp())
    except Exception:
        return 0


# ------------------------------------------------------------ VariantDictionary

def _vd_parse(data):
    d = {}
    pos = 2  # version (uint16)
    while True:
        t = data[pos]
        pos += 1
        if t == 0:
            break
        klen = struct.unpack_from("<I", data, pos)[0]
        pos += 4
        key = data[pos:pos + klen].decode("utf-8")
        pos += klen
        vlen = struct.unpack_from("<I", data, pos)[0]
        pos += 4
        raw = data[pos:pos + vlen]
        pos += vlen
        if t == 0x04:
            val = struct.unpack("<I", raw)[0]
        elif t == 0x05:
            val = struct.unpack("<Q", raw)[0]
        elif t == 0x08:
            val = raw != b"\x00"
        elif t == 0x0C:
            val = struct.unpack("<i", raw)[0]
        elif t == 0x0D:
            val = struct.unpack("<q", raw)[0]
        elif t == 0x18:
            val = raw.decode("utf-8")
        else:  # 0x42 byte array (and anything unknown)
            val = raw
        d[key] = (t, val)
    return d


def _vd_dump(d):
    out = bytearray(struct.pack("<H", 0x0100))
    for key, (t, val) in d.items():
        if t == 0x04:
            raw = struct.pack("<I", val)
        elif t == 0x05:
            raw = struct.pack("<Q", val)
        elif t == 0x08:
            raw = b"\x01" if val else b"\x00"
        elif t == 0x0C:
            raw = struct.pack("<i", val)
        elif t == 0x0D:
            raw = struct.pack("<q", val)
        elif t == 0x18:
            raw = val.encode("utf-8")
        else:
            raw = bytes(val)
        kb = key.encode("utf-8")
        out += bytes([t]) + struct.pack("<I", len(kb)) + kb
        out += struct.pack("<I", len(raw)) + raw
    out += b"\x00"
    return bytes(out)


# ------------------------------------------------------------------------ KDF

def argon2_available():
    try:
        import argon2.low_level  # noqa: F401
        return True
    except Exception:
        return False


def _argon2(kind, key, salt, par, mem_bytes, iters, version):
    try:
        from argon2.low_level import hash_secret_raw, Type
        return hash_secret_raw(
            key, salt, time_cost=iters, memory_cost=mem_bytes // 1024,
            parallelism=par, hash_len=32,
            type=Type.D if kind == "d" else Type.ID, version=version)
    except ImportError:
        pass
    if kind == "id":
        try:
            from cryptography.hazmat.primitives.kdf.argon2 import Argon2id
            return Argon2id(salt=salt, length=32, iterations=iters, lanes=par,
                            memory_cost=mem_bytes // 1024).derive(key)
        except Exception:
            pass
    raise KdbxError("argon2-unavailable",
                    "this database uses Argon2%s but no Argon2 library is "
                    "installed" % kind)


def _transform(composite, kdf):
    uid = kdf["$UUID"][1]
    g = lambda k: kdf[k][1]  # noqa: E731
    if uid == KDF_AES:
        enc = Cipher(algorithms.AES(g("S")), modes.ECB()).encryptor()
        k = composite
        for _ in range(g("R")):
            k = enc.update(k)
        return _sha256(k)
    if uid in (KDF_ARGON2D, KDF_ARGON2ID):
        return _argon2("d" if uid == KDF_ARGON2D else "id", composite,
                       g("S"), g("P"), g("M"), g("I"), g("V"))
    raise KdbxError("unsupported-kdf")


def _aes_kdf_params(rounds):
    return {
        "$UUID": (0x42, KDF_AES),
        "S": (0x42, secrets.token_bytes(32)),
        "R": (0x05, rounds),
    }


def _argon2_params(kind):
    return {
        "$UUID": (0x42, KDF_ARGON2D if kind == "d" else KDF_ARGON2ID),
        "S": (0x42, secrets.token_bytes(32)),
        "P": (0x04, 2),
        "M": (0x05, 64 * 1024 * 1024),
        "I": (0x05, 3),
        "V": (0x04, 0x13),
    }


def _calibrated_aes_rounds(target_seconds=1.0, floor=200_000, cap=6_000_000):
    """Pick an AES-KDF round count that takes ~1 s on *this* device."""
    enc = Cipher(algorithms.AES(b"\x01" * 32), modes.ECB()).encryptor()
    k, n = b"\x02" * 32, 50_000
    t0 = time.perf_counter()
    for _ in range(n):
        k = enc.update(k)
    dt = max(time.perf_counter() - t0, 1e-6)
    return int(min(cap, max(floor, n * target_seconds / dt)))


def _composite(password):
    return _sha256(_sha256(password.encode("utf-8")))


# ------------------------------------------------------- inner (protected) XOR

class _Keystream:
    def __init__(self, key):
        h = _sha512(key)
        self._enc = Cipher(algorithms.ChaCha20(h[:32], b"\x00" * 4 + h[32:44]),
                           mode=None).encryptor()

    def xor(self, data):
        ks = self._enc.update(b"\x00" * len(data))
        return bytes(a ^ b for a, b in zip(data, ks))


def _protected_values(root):
    return [v for v in root.iter("Value") if v.get("Protected") == "True"]


# ------------------------------------------------------------------- database

class KdbxDatabase:
    def __init__(self):
        self.minor = 0
        self.cipher = CIPHER_AES
        self.compression = 1
        self.kdf = None
        self.public_custom = None
        self.binaries = []          # raw inner-header binary fields, preserved
        self.root_xml = None
        self._composite = None
        self._tk = None             # cached transformed key (skip KDF on save)

    # ---- creation / loading ------------------------------------------------
    @classmethod
    def create(cls, password, name="Passwords"):
        db = cls()
        if argon2_available():
            db.kdf = _argon2_params("d")
        else:
            db.kdf = _aes_kdf_params(_calibrated_aes_rounds())
        db._composite = _composite(password)
        db._tk = _transform(db._composite, db.kdf)
        now = _ticks_now()
        rid = base64.b64encode(uuid_mod.uuid4().bytes).decode()
        xml = (
            "<KeePassFile><Meta><Generator>Password Manager (Ubuntu Touch)"
            "</Generator><DatabaseName>%s</DatabaseName>"
            "<RecycleBinEnabled>True</RecycleBinEnabled>"
            "<RecycleBinUUID>AAAAAAAAAAAAAAAAAAAAAA==</RecycleBinUUID>"
            "</Meta><Root><Group><UUID>%s</UUID><Name>%s</Name>"
            "<IconID>49</IconID><Times><CreationTime>%s</CreationTime>"
            "<LastModificationTime>%s</LastModificationTime></Times>"
            "<IsExpanded>True</IsExpanded></Group><DeletedObjects/></Root>"
            "</KeePassFile>" % (name, rid, name, now, now))
        db.root_xml = ET.fromstring(xml)
        return db

    @classmethod
    def load(cls, path, password):
        with open(path, "rb") as f:
            data = f.read()
        return cls._decode(data, composite=_composite(password))

    @classmethod
    def _decode(cls, data, composite=None, tk=None):
        try:
            return cls._decode_inner(data, composite, tk)
        except KdbxError:
            raise
        except (struct.error, IndexError, ValueError, ET.ParseError, OSError,
                KeyError) as e:
            raise KdbxError("corrupt", repr(e))

    @classmethod
    def _decode_inner(cls, data, composite, tk):
        s1, s2, minor, major = struct.unpack_from("<IIHH", data, 0)
        if s1 != SIG1 or s2 != SIG2:
            raise KdbxError("not-kdbx")
        if major != 4:
            raise KdbxError("unsupported-version",
                            "KDBX %d.%d (only KDBX 4 is supported; in KeePass: "
                            "File > Database Settings > Security, or save as "
                            "KDBX 4)" % (major, minor))
        pos, fields = 12, {}
        while True:
            fid = data[pos]
            size = struct.unpack_from("<I", data, pos + 1)[0]
            pos += 5
            fields[fid] = data[pos:pos + size]
            pos += size
            if fid == 0:
                break
        header = data[:pos]
        if _sha256(header) != data[pos:pos + 32]:
            raise KdbxError("corrupt", "header hash mismatch")
        stored_hmac = data[pos + 32:pos + 64]
        pos += 64

        db = cls()
        db.minor = minor
        db.cipher = fields[2]
        db.compression = struct.unpack("<I", fields[3])[0]
        db.kdf = _vd_parse(fields[11])
        db.public_custom = fields.get(12)
        if db.cipher not in (CIPHER_AES, CIPHER_CHACHA):
            raise KdbxError("unsupported-cipher")

        if tk is None:
            tk = _transform(composite, db.kdf)
        mseed = fields[4]
        enckey = _sha256(mseed, tk)
        hkey = _sha512(mseed, tk, b"\x01")
        blockkey = lambda i: _sha512(struct.pack("<Q", i), hkey)  # noqa: E731

        good = hmac.new(blockkey(2 ** 64 - 1), header, hashlib.sha256).digest()
        if not hmac.compare_digest(good, stored_hmac):
            raise KdbxError("wrong-password")

        chunks, idx = [], 0
        while True:
            bmac = data[pos:pos + 32]
            size = struct.unpack_from("<I", data, pos + 32)[0]
            pos += 36
            blk = data[pos:pos + size]
            pos += size
            calc = hmac.new(blockkey(idx), struct.pack("<QI", idx, size) + blk,
                            hashlib.sha256).digest()
            if not hmac.compare_digest(calc, bmac):
                raise KdbxError("corrupt", "block %d hmac mismatch" % idx)
            if size == 0:
                break
            chunks.append(blk)
            idx += 1
        enc_payload = b"".join(chunks)

        iv = fields[7]
        if db.cipher == CIPHER_AES:
            dec = Cipher(algorithms.AES(enckey), modes.CBC(iv)).decryptor()
            padded = dec.update(enc_payload) + dec.finalize()
            un = padding.PKCS7(128).unpadder()
            payload = un.update(padded) + un.finalize()
        else:
            dec = Cipher(algorithms.ChaCha20(enckey, b"\x00" * 4 + iv),
                         mode=None).decryptor()
            payload = dec.update(enc_payload)
        if db.compression == 1:
            payload = gzip.decompress(payload)

        p, stream_id, stream_key = 0, None, None
        while True:
            iid = payload[p]
            isz = struct.unpack_from("<I", payload, p + 1)[0]
            p += 5
            val = payload[p:p + isz]
            p += isz
            if iid == 0:
                break
            if iid == 1:
                stream_id = struct.unpack("<I", val)[0]
            elif iid == 2:
                stream_key = val
            elif iid == 3:
                db.binaries.append(val)
        if stream_id != 3:
            raise KdbxError("unsupported-stream",
                            "inner stream %s (only ChaCha20)" % stream_id)

        db.root_xml = ET.fromstring(payload[p:])
        ks = _Keystream(stream_key)
        for v in _protected_values(db.root_xml):
            raw = base64.b64decode(v.text or "")
            v.text = ks.xor(raw).decode("utf-8")
        db._composite = composite
        db._tk = tk
        return db

    # ---- serialisation -----------------------------------------------------
    def dumps(self):
        mseed = secrets.token_bytes(32)
        iv = secrets.token_bytes(16 if self.cipher == CIPHER_AES else 12)
        stream_key = secrets.token_bytes(64)

        tree = copy.deepcopy(self.root_xml)
        ks = _Keystream(stream_key)
        for v in _protected_values(tree):
            v.text = base64.b64encode(ks.xor((v.text or "").encode("utf-8"))
                                      ).decode("ascii")
        xml = ('<?xml version="1.0" encoding="utf-8" standalone="yes"?>\n'
               + ET.tostring(tree, encoding="unicode")).encode("utf-8")

        inner = (b"\x01" + struct.pack("<I", 4) + struct.pack("<I", 3)
                 + b"\x02" + struct.pack("<I", len(stream_key)) + stream_key)
        for b in self.binaries:
            inner += b"\x03" + struct.pack("<I", len(b)) + b
        inner += b"\x00" + struct.pack("<I", 0)
        payload = inner + xml
        if self.compression == 1:
            payload = gzip.compress(payload)

        enckey = _sha256(mseed, self._tk)
        hkey = _sha512(mseed, self._tk, b"\x01")
        blockkey = lambda i: _sha512(struct.pack("<Q", i), hkey)  # noqa: E731
        if self.cipher == CIPHER_AES:
            pad = padding.PKCS7(128).padder()
            padded = pad.update(payload) + pad.finalize()
            enc = Cipher(algorithms.AES(enckey), modes.CBC(iv)).encryptor()
            enc_payload = enc.update(padded) + enc.finalize()
        else:
            enc = Cipher(algorithms.ChaCha20(enckey, b"\x00" * 4 + iv),
                         mode=None).encryptor()
            enc_payload = enc.update(payload)

        def field(fid, val):
            return bytes([fid]) + struct.pack("<I", len(val)) + val

        header = struct.pack("<IIHH", SIG1, SIG2, self.minor, 4)
        header += field(2, self.cipher)
        header += field(3, struct.pack("<I", self.compression))
        header += field(4, mseed)
        header += field(7, iv)
        header += field(11, _vd_dump(self.kdf))
        if self.public_custom is not None:
            header += field(12, self.public_custom)
        header += field(0, b"\r\n\r\n")

        out = bytearray(header)
        out += _sha256(header)
        out += hmac.new(blockkey(2 ** 64 - 1), header, hashlib.sha256).digest()
        idx = 0
        for off in range(0, len(enc_payload), BLOCK_SIZE):
            blk = enc_payload[off:off + BLOCK_SIZE]
            m = hmac.new(blockkey(idx), struct.pack("<QI", idx, len(blk)) + blk,
                         hashlib.sha256).digest()
            out += m + struct.pack("<I", len(blk)) + blk
            idx += 1
        m = hmac.new(blockkey(idx), struct.pack("<QI", idx, 0),
                     hashlib.sha256).digest()
        out += m + struct.pack("<I", 0)
        return bytes(out)

    def save(self, path):
        """Serialise, verify by decrypting the result, keep a .bak of the
        previous file, then atomically replace it."""
        blob = self.dumps()
        check = KdbxDatabase._decode(blob, tk=self._tk)
        if len(list(check._iter_entries())) != len(list(self._iter_entries())):
            raise KdbxError("verify-failed", "entry count mismatch")
        os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
        tmp = path + ".tmp"
        with open(tmp, "wb") as f:
            f.write(blob)
            f.flush()
            os.fsync(f.fileno())
        if os.path.isfile(path):
            shutil.copyfile(path, path + ".bak")
        os.replace(tmp, path)

    def set_password(self, new_password):
        params = dict(self.kdf)
        params["S"] = (0x42, secrets.token_bytes(32))  # fresh KDF salt/seed
        composite = _composite(new_password)
        self._tk = _transform(composite, params)
        self.kdf = params
        self._composite = composite

    def check_password(self, password):
        return hmac.compare_digest(_composite(password), self._composite)

    # ---- tree helpers ------------------------------------------------------
    @property
    def _root_group(self):
        return self.root_xml.find("Root/Group")

    def _recycle_id(self):
        n = self.root_xml.find("Meta/RecycleBinUUID")
        return n.text if n is not None else None

    def _iter_groups(self, group=None, path=None, in_bin=False):
        group = self._root_group if group is None else group
        path = [] if path is None else path
        yield group, path, in_bin
        for sub in group.findall("Group"):
            name = (sub.findtext("Name") or "")
            sub_bin = in_bin or (sub.findtext("UUID") == self._recycle_id())
            yield from self._iter_groups(sub, path + [name], sub_bin)

    def _iter_entries(self, include_bin=False):
        for group, path, in_bin in self._iter_groups():
            if in_bin and not include_bin:
                continue
            for e in group.findall("Entry"):
                yield group, path, e

    @staticmethod
    def _eid(entry):
        raw = base64.b64decode(entry.findtext("UUID") or "")
        return str(uuid_mod.UUID(bytes=raw)) if len(raw) == 16 else ""

    @staticmethod
    def _get(entry, key):
        for s in entry.findall("String"):
            if s.findtext("Key") == key:
                return s.findtext("Value") or ""
        return ""

    @staticmethod
    def _set(entry, key, value, protected=False):
        for s in entry.findall("String"):
            if s.findtext("Key") == key:
                v = s.find("Value")
                if v is None:
                    v = ET.SubElement(s, "Value")
                v.text = value
                if protected:
                    v.set("Protected", "True")
                return
        s = ET.SubElement(entry, "String")
        ET.SubElement(s, "Key").text = key
        v = ET.SubElement(s, "Value")
        v.text = value
        if protected:
            v.set("Protected", "True")

    @staticmethod
    def _touch(entry, created=False):
        times = entry.find("Times")
        if times is None:
            times = ET.SubElement(entry, "Times")
        now = _ticks_now()
        names = ["LastModificationTime", "LastAccessTime"]
        if created:
            names = ["CreationTime"] + names
        for n in names:
            t = times.find(n)
            if t is None:
                t = ET.SubElement(times, n)
            t.text = now
        if created:
            ET.SubElement(times, "ExpiryTime").text = now
            ET.SubElement(times, "Expires").text = "False"
            ET.SubElement(times, "UsageCount").text = "0"
            ET.SubElement(times, "LocationChanged").text = now

    def _find(self, eid):
        for group, path, e in self._iter_entries():
            if self._eid(e) == eid:
                return group, path, e
        return None, None, None

    def _group_for(self, category):
        category = (category or "").strip()
        if not category or category == GENERAL:
            return self._root_group
        group = self._root_group
        for name in category.split(PATH_SEP):
            name = name.strip()
            nxt = next((g for g in group.findall("Group")
                        if (g.findtext("Name") or "") == name), None)
            if nxt is None:
                nxt = ET.SubElement(group, "Group")
                ET.SubElement(nxt, "UUID").text = base64.b64encode(
                    uuid_mod.uuid4().bytes).decode()
                ET.SubElement(nxt, "Name").text = name
                ET.SubElement(nxt, "IconID").text = "48"
                ET.SubElement(nxt, "IsExpanded").text = "True"
            group = nxt
        return group

    # ---- public entry API (same shape the QML layer already uses) ---------
    def _as_dict(self, path, e):
        return {
            "uuid": self._eid(e),
            "title": self._get(e, "Title"),
            "username": self._get(e, "UserName"),
            "password": self._get(e, "Password"),
            "url": self._get(e, "URL"),
            "notes": self._get(e, "Notes"),
            "category": PATH_SEP.join(path) if path else GENERAL,
            "modified": _ticks_to_unix(
                (e.find("Times/LastModificationTime").text
                 if e.find("Times/LastModificationTime") is not None else "")),
        }

    def entries(self):
        return [self._as_dict(p, e) for _, p, e in self._iter_entries()]

    def get_entry(self, eid):
        _, path, e = self._find(eid)
        return None if e is None else self._as_dict(path, e)

    def add_entry(self, title, username, password, url, notes, category):
        group = self._group_for(category)
        e = ET.SubElement(group, "Entry")
        ET.SubElement(e, "UUID").text = base64.b64encode(
            uuid_mod.uuid4().bytes).decode()
        ET.SubElement(e, "IconID").text = "0"
        self._touch(e, created=True)
        self._fill(e, title, username, password, url, notes)

    def _fill(self, e, title, username, password, url, notes):
        self._set(e, "Title", title)
        self._set(e, "UserName", username)
        if password is not None:
            self._set(e, "Password", password, protected=True)
        self._set(e, "URL", url)
        self._set(e, "Notes", notes)

    def update_entry(self, eid, title, username, password, url, notes,
                     category):
        group, _, e = self._find(eid)
        if e is None:
            return False
        self._fill(e, title, username, password or None, url, notes)
        self._touch(e)
        target = self._group_for(category)
        if target is not group:
            group.remove(e)
            target.append(e)
        return True

    def delete_entry(self, eid):
        group, _, e = self._find(eid)
        if e is None:
            return False
        group.remove(e)
        root = self.root_xml.find("Root")
        dobjs = root.find("DeletedObjects")
        if dobjs is None:
            dobjs = ET.SubElement(root, "DeletedObjects")
        d = ET.SubElement(dobjs, "DeletedObject")
        ET.SubElement(d, "UUID").text = e.findtext("UUID")
        ET.SubElement(d, "DeletionTime").text = _ticks_now()
        return True
