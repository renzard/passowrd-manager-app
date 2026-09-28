"""
vault_backend.py
-----------------
PyOtherSide backend bridge between the QML UI and the local vault.

Design (KeePass-style, single portable encrypted file):
  * Everything lives in ONE file on disk (default: vault.pmvault). That
    file is a small JSON envelope containing a random salt, a random
    nonce and an AES-256-GCM ciphertext. The ciphertext is the only
    place the entries exist on disk, and it can only be opened with the
    master password.
  * The master password is never written to disk anywhere, in any form.
    It is used to derive an AES-256 key with PBKDF2-HMAC-SHA256 (310,000
    iterations) and a per-vault random salt. The derived key lives only
    in memory (`_key`) while the vault is unlocked, and is dropped on
    lock.
  * Because the vault file is fully self-contained and fully encrypted,
    it is portable by design: copy `vault.pmvault` off the device (to a
    computer, SD card, cloud drive, etc.), wipe/format/reinstall, copy
    the same file back into place (or use `import_vault` to copy it into
    place from another location) and unlocking with the same master
    password restores the exact same entries. Nothing else is needed.
  * `export_vault` / `import_vault` are just safe file-copy helpers
    around that same file, so the user doesn't need a terminal to make
    or restore a backup.
"""

import os
import json
import base64
import secrets
import shutil
import threading

import pyotherside

from password_generator import generate_password

from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

KDF_ITERATIONS = 310_000
VAULT_MAGIC = "pmvault"
VAULT_VERSION = 1

_lock = threading.Lock()
_entries = []          # in-memory list of entry dicts, mirrors the decrypted vault
_vault_path = None
_key = None             # derived AES-256 key, only while unlocked; never persisted
_unlocked = False


_FALLBACK_APP_NAME = "password-manager.yourdomain"
_VAULT_FILENAME = "vault.pmvault"


def _app_name():
    """The click package name. Ubuntu Touch's AppArmor profile only lets
    the app write inside directories named after its *installed* package
    name, so prefer the name the launcher gives us (APP_ID looks like
    "<package>_<app>_<version>") over a hardcoded one."""
    app_id = os.environ.get("APP_ID", "")
    if app_id:
        name = app_id.split("_")[0]
        if name:
            return name
    return _FALLBACK_APP_NAME


def _candidate_dirs():
    """Directories a confined Ubuntu Touch app is allowed to use, best
    first. Data dir is preferred; config is a fallback that is also
    writable and persistent; cache is the last resort."""
    home = os.path.expanduser("~")
    name = _app_name()
    dirs = []
    xdg_data = os.environ.get("XDG_DATA_HOME")
    if xdg_data:
        dirs.append(os.path.join(xdg_data, name))
    dirs.append(os.path.join(home, ".local", "share", name))
    xdg_config = os.environ.get("XDG_CONFIG_HOME")
    if xdg_config:
        dirs.append(os.path.join(xdg_config, name))
    dirs.append(os.path.join(home, ".config", name))
    xdg_cache = os.environ.get("XDG_CACHE_HOME")
    if xdg_cache:
        dirs.append(os.path.join(xdg_cache, name))
    dirs.append(os.path.join(home, ".cache", name))
    seen, unique = set(), []
    for d in dirs:
        if d not in seen:
            seen.add(d)
            unique.append(d)
    return unique


def _dir_is_writable(directory):
    """Actually try to create the dir and write a file in it -- AppArmor
    denials only show up when you really attempt the operation."""
    try:
        os.makedirs(directory, exist_ok=True)
        probe = os.path.join(directory, ".write-test")
        with open(probe, "w") as f:
            f.write("ok")
        os.remove(probe)
        return True
    except OSError:
        return False


def _default_vault_path():
    """Pick where the vault lives. An already-existing vault always wins
    (so we keep finding it); otherwise use the first directory that we can
    genuinely write to."""
    candidates = _candidate_dirs()
    for d in candidates:
        path = os.path.join(d, _VAULT_FILENAME)
        if os.path.isfile(path):
            return path
    for d in candidates:
        if _dir_is_writable(d):
            return os.path.join(d, _VAULT_FILENAME)
    # Nothing worked; return the primary location so the error message
    # points at the most likely culprit.
    return os.path.join(candidates[0], _VAULT_FILENAME)


def get_vault_path():
    """Exposed to QML so it doesn't need to compute/guess the path itself."""
    path = _default_vault_path()
    pyotherside.send("vault-path-result", path)
    return path


def _emit_error(context, message):
    pyotherside.send("backend-error", context, str(message))


def _derive_key(password, salt):
    kdf = PBKDF2HMAC(
        algorithm=hashes.SHA256(),
        length=32,
        salt=salt,
        iterations=KDF_ITERATIONS,
    )
    return kdf.derive(password.encode("utf-8"))


def _b64e(data):
    return base64.b64encode(data).decode("ascii")


def _b64d(data):
    return base64.b64decode(data.encode("ascii"))


def vault_exists(vault_path=None):
    """Whether a vault file has already been created on this device."""
    vault_path = vault_path or _default_vault_path()
    exists = os.path.isfile(vault_path)
    pyotherside.send("vault-exists-result", exists)
    return exists


def _write_vault(vault_path, salt, key, entries):
    """Encrypt `entries` with `key` and atomically overwrite the single
    vault file. A fresh random nonce is used on every save (required for
    AES-GCM safety) -- the salt (tied to the password/key) stays fixed
    for the life of the vault."""
    nonce = secrets.token_bytes(12)
    plaintext = json.dumps({"entries": entries}).encode("utf-8")
    ciphertext = AESGCM(key).encrypt(nonce, plaintext, None)
    envelope = {
        "magic": VAULT_MAGIC,
        "version": VAULT_VERSION,
        "kdf": "pbkdf2-sha256",
        "iterations": KDF_ITERATIONS,
        "salt": _b64e(salt),
        "nonce": _b64e(nonce),
        "ciphertext": _b64e(ciphertext),
    }
    os.makedirs(os.path.dirname(vault_path), exist_ok=True)
    tmp_path = vault_path + ".tmp"
    with open(tmp_path, "w", encoding="utf-8") as f:
        json.dump(envelope, f)
    os.replace(tmp_path, vault_path)


def _read_vault_envelope(vault_path):
    with open(vault_path, "r", encoding="utf-8") as f:
        return json.load(f)


def _save_entries_locked():
    """Caller must hold _lock and the vault must be unlocked."""
    envelope = _read_vault_envelope(_vault_path)
    salt = _b64d(envelope["salt"])
    _write_vault(_vault_path, salt, _key, _entries)


def create_vault(vault_path, master_password):
    """First-time setup: create a brand-new, empty encrypted vault
    protected by `master_password`. Fails if a vault already exists at
    that path (use unlock_vault instead)."""
    global _vault_path, _entries, _key, _unlocked
    vault_path = vault_path or _default_vault_path()
    with _lock:
        try:
            if os.path.isfile(vault_path):
                pyotherside.send("vault-unlock-failed", "already-exists")
                return
            salt = secrets.token_bytes(16)
            key = _derive_key(master_password, salt)
            _write_vault(vault_path, salt, key, [])
            _vault_path = vault_path
            _entries = []
            _key = key
            _unlocked = True
            pyotherside.send("vault-unlocked")
        except Exception as e:
            _emit_error("create_vault", e)


def unlock_vault(vault_path, master_password):
    """Decrypt the single vault file with the given master password.
    Everything the app knows about the entries comes out of this one
    call -- there is no separate PIN/sidecar file anymore."""
    global _vault_path, _entries, _key, _unlocked
    vault_path = vault_path or _default_vault_path()
    with _lock:
        try:
            envelope = _read_vault_envelope(vault_path)
            if envelope.get("magic") != VAULT_MAGIC:
                pyotherside.send("vault-unlock-failed", "not-a-vault")
                return
            salt = _b64d(envelope["salt"])
            nonce = _b64d(envelope["nonce"])
            ciphertext = _b64d(envelope["ciphertext"])
            key = _derive_key(master_password, salt)
            try:
                plaintext = AESGCM(key).decrypt(nonce, ciphertext, None)
            except Exception:
                # Wrong password (or corrupted/tampered file) -- AES-GCM's
                # authentication tag simply fails to verify.
                pyotherside.send("vault-unlock-failed", "wrong-password")
                return
            data = json.loads(plaintext.decode("utf-8"))
            _vault_path = vault_path
            _entries = data.get("entries", [])
            _key = key
            _unlocked = True
            pyotherside.send("vault-unlocked")
        except FileNotFoundError:
            pyotherside.send("vault-unlock-failed", "not-found")
        except Exception as e:
            _emit_error("unlock_vault", e)


def change_master_password(old_password, new_password):
    """Re-encrypt the whole vault under a new master password. Requires
    the vault to already be unlocked (so we know the entries) and the
    caller to re-prove the *current* password, since that password is
    the only thing standing between "change password" and "anyone with
    the app open can silently swap it"."""
    global _key
    if not _unlocked:
        _emit_error("change_master_password", "vault-locked")
        return
    with _lock:
        try:
            envelope = _read_vault_envelope(_vault_path)
            salt = _b64d(envelope["salt"])
            check_key = _derive_key(old_password, salt)
            if not secrets.compare_digest(check_key, _key):
                pyotherside.send("change-password-failed", "wrong-password")
                return
            new_salt = secrets.token_bytes(16)
            new_key = _derive_key(new_password, new_salt)
            _write_vault(_vault_path, new_salt, new_key, _entries)
            _key = new_key
            pyotherside.send("master-password-changed")
        except Exception as e:
            _emit_error("change_master_password", e)


def export_vault(dest_path, vault_path=None):
    """Copy the single encrypted vault file somewhere else (SD card,
    Documents, a cloud-synced folder, etc.) so it survives a factory
    reset / reinstall. This is a plain file copy -- the file is already
    fully encrypted at rest, so this works whether or not the vault is
    currently unlocked, and no extra step is needed to make the copy
    "safe" to put elsewhere."""
    vault_path = vault_path or _vault_path or _default_vault_path()
    if not os.path.isfile(vault_path):
        _emit_error("export_vault", "no-vault-to-export")
        return
    try:
        os.makedirs(os.path.dirname(dest_path), exist_ok=True)
        shutil.copyfile(vault_path, dest_path)
        pyotherside.send("vault-exported", dest_path)
    except Exception as e:
        _emit_error("export_vault", e)


def import_vault(src_path, vault_path=None):
    """Copy a previously-exported vault file into the app's normal vault
    location (e.g. right after a factory reset / fresh install). This
    only stages the file -- it does not unlock it. Call unlock_vault
    with the master password afterwards, same as any other time."""
    vault_path = vault_path or _default_vault_path()
    try:
        if not os.path.isfile(src_path):
            _emit_error("import_vault", "source-not-found")
            return
        envelope = _read_vault_envelope(src_path)
        if envelope.get("magic") != VAULT_MAGIC:
            _emit_error("import_vault", "not-a-vault")
            return
        os.makedirs(os.path.dirname(vault_path), exist_ok=True)
        shutil.copyfile(src_path, vault_path)
        pyotherside.send("vault-imported", vault_path)
    except Exception as e:
        _emit_error("import_vault", e)


def lock_vault():
    """Drop the derived key and decrypted entries from memory. The vault
    file on disk is untouched -- it was never decrypted there, only in
    RAM -- so locking is just forgetting the key."""
    global _unlocked, _key, _entries
    with _lock:
        _unlocked = False
        _key = None
        _entries = []
    pyotherside.send("vault-locked")


def is_unlocked():
    return _unlocked


def list_entries(query=""):
    if not _unlocked:
        _emit_error("list_entries", "vault-locked")
        return
    query = (query or "").strip().lower()
    results = []
    for e in _entries:
        title = e.get("title", "")
        username = e.get("username", "")
        category = e.get("category", "")
        haystack = f"{title} {username} {category}".lower()
        if query and query not in haystack:
            continue
        results.append({
            "uuid": e["uuid"],
            "title": title,
            "username": username,
            "url": e.get("url", ""),
            "category": category,
        })
    results.sort(key=lambda x: x["title"].lower())
    pyotherside.send("entries-list-result", results)


def get_entry(uuid):
    if not _unlocked:
        _emit_error("get_entry", "vault-locked")
        return
    entry = next((e for e in _entries if e["uuid"] == uuid), None)
    if entry is None:
        _emit_error("get_entry", "not-found")
        return
    pyotherside.send("entry-detail-result", entry)


def get_entry_secret(uuid, field):
    if not _unlocked:
        _emit_error("get_entry_secret", "vault-locked")
        return
    entry = next((e for e in _entries if e["uuid"] == uuid), None)
    if entry is None:
        _emit_error("get_entry_secret", "not-found")
        return
    pyotherside.send("secret-ready", field, entry.get(field, "") or "")


def add_entry(title, username, password, url, notes, category):
    if not _unlocked:
        _emit_error("add_entry", "vault-locked")
        return
    import uuid as uuid_mod
    with _lock:
        entry = {
            "uuid": str(uuid_mod.uuid4()),
            "title": title or "Untitled",
            "username": username or "",
            "password": password or "",
            "url": url or "",
            "notes": notes or "",
            "category": (category or "General").strip() or "General",
        }
        _entries.append(entry)
        _save_entries_locked()
    pyotherside.send("entry-saved")


def update_entry(uuid, title, username, password, url, notes, category):
    if not _unlocked:
        _emit_error("update_entry", "vault-locked")
        return
    with _lock:
        entry = next((e for e in _entries if e["uuid"] == uuid), None)
        if entry is None:
            _emit_error("update_entry", "not-found")
            return
        entry["title"] = title
        entry["username"] = username
        if password:  # only overwrite if the user actually changed it
            entry["password"] = password
        entry["url"] = url
        entry["notes"] = notes
        entry["category"] = (category or "General").strip() or "General"
        _save_entries_locked()
    pyotherside.send("entry-saved")


def delete_entry(uuid):
    global _entries
    if not _unlocked:
        _emit_error("delete_entry", "vault-locked")
        return
    with _lock:
        _entries = [e for e in _entries if e["uuid"] != uuid]
        _save_entries_locked()
    pyotherside.send("entry-deleted", uuid)


def make_password(length, use_upper, use_lower, use_digits, use_symbols):
    pwd = generate_password(
        length=length,
        use_upper=use_upper,
        use_lower=use_lower,
        use_digits=use_digits,
        use_symbols=use_symbols,
    )
    pyotherside.send("password-generated", pwd)


def reset_vault(vault_path, new_master_password):
    """Wipe the vault file entirely and start over with a brand-new
    empty vault under a new master password. Genuinely destructive --
    unlike the old PIN-only design, there is no way to recover the old
    entries this way if the master password is forgotten, because they
    really were encrypted with it and nothing else. The only recovery
    path is restoring a previously exported vault file instead."""
    global _entries
    vault_path = vault_path or _default_vault_path()
    try:
        if os.path.isfile(vault_path):
            os.remove(vault_path)
        _entries = []
        create_vault(vault_path, new_master_password)
    except Exception as e:
        _emit_error("reset_vault", e)
