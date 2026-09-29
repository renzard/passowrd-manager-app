"""
vault_backend.py
-----------------
PyOtherSide backend bridge between the QML UI and the local vault.

The vault is now a standard KeePass KDBX 4 database (see kdbx.py), so the
very same file can be opened by KeePass / KeePassXC / KeePassDX on any
device, and a database made in KeePass can be opened here.

  * Everything lives in ONE file (default: vault.kdbx).
  * The master password is never written to disk; the derived key only
    lives in memory while the vault is unlocked.
  * Every save is verified (decrypted again) before replacing the file,
    and the previous version is kept next to it as vault.kdbx.bak.
  * A legacy vault.pmvault from older versions of this app is migrated
    to vault.kdbx automatically on first unlock (the old file is kept).
"""

import os
import sys
import json
import base64
import shutil
import threading

_here = os.path.dirname(os.path.abspath(__file__))
for _p in (os.path.join(_here, "vendor"), os.path.join(_here, "..", "vendor")):
    if os.path.isdir(_p) and _p not in sys.path:
        sys.path.insert(0, _p)   # optional vendored argon2-cffi

import pyotherside

from password_generator import generate_password
import kdbx

_lock = threading.Lock()
_db = None              # kdbx.KdbxDatabase while unlocked
_vault_path = None
_unlocked = False

_FALLBACK_APP_NAME = "password-manager.yourdomain"
_VAULT_FILENAME = "vault.kdbx"
_LEGACY_FILENAME = "vault.pmvault"
LEGACY_MAGIC = "pmvault"


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
    for name in (_VAULT_FILENAME, _LEGACY_FILENAME):
        for d in candidates:
            path = os.path.join(d, name)
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


def vault_exists(vault_path=None):
    """Whether a vault file has already been created on this device."""
    vault_path = vault_path or _default_vault_path()
    exists = os.path.isfile(vault_path)
    pyotherside.send("vault-exists-result", exists)
    return exists


def _save_locked():
    """Caller must hold _lock and the vault must be unlocked."""
    _db.save(_vault_path)


def _legacy_entries(path, password):
    """Read an old vault.pmvault (PBKDF2 + AES-GCM JSON). Returns the entry
    list, or None if the password is wrong."""
    from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
    from cryptography.hazmat.primitives import hashes
    from cryptography.hazmat.primitives.ciphers.aead import AESGCM
    with open(path, "r", encoding="utf-8") as f:
        env = json.load(f)
    if env.get("magic") != LEGACY_MAGIC:
        raise kdbx.KdbxError("not-kdbx")
    b = lambda s: base64.b64decode(s.encode("ascii"))  # noqa: E731
    key = PBKDF2HMAC(algorithm=hashes.SHA256(), length=32, salt=b(env["salt"]),
                     iterations=env.get("iterations", 310000)
                     ).derive(password.encode("utf-8"))
    try:
        plain = AESGCM(key).decrypt(b(env["nonce"]), b(env["ciphertext"]), None)
    except Exception:
        return None
    return json.loads(plain.decode("utf-8")).get("entries", [])


def _fail_reason(err):
    if err.code in ("wrong-password", "argon2-unavailable",
                    "unsupported-version", "corrupt"):
        return err.code
    return "not-a-vault"


def create_vault(vault_path, master_password):
    """First-time setup: create a brand-new empty KDBX vault."""
    global _vault_path, _db, _unlocked
    vault_path = vault_path or _default_vault_path()
    if vault_path.endswith(".pmvault"):
        vault_path = os.path.join(os.path.dirname(vault_path), _VAULT_FILENAME)
    with _lock:
        try:
            if os.path.isfile(vault_path):
                pyotherside.send("vault-unlock-failed", "already-exists")
                return
            db = kdbx.KdbxDatabase.create(master_password)
            db.save(vault_path)
            _vault_path, _db, _unlocked = vault_path, db, True
            pyotherside.send("vault-unlocked")
        except Exception as e:
            _emit_error("create_vault", e)


def unlock_vault(vault_path, master_password):
    """Open the KDBX file (or migrate a legacy .pmvault) with the master
    password."""
    global _vault_path, _db, _unlocked
    vault_path = vault_path or _default_vault_path()
    with _lock:
        try:
            if not os.path.isfile(vault_path):
                pyotherside.send("vault-unlock-failed", "not-found")
                return
            if not kdbx.is_kdbx(vault_path):
                entries = _legacy_entries(vault_path, master_password)
                if entries is None:
                    pyotherside.send("vault-unlock-failed", "wrong-password")
                    return
                new_path = os.path.join(os.path.dirname(vault_path),
                                        _VAULT_FILENAME)
                if os.path.isfile(new_path):
                    pyotherside.send("vault-unlock-failed", "already-exists")
                    return
                db = kdbx.KdbxDatabase.create(master_password)
                for e in entries:
                    db.add_entry(e.get("title", ""), e.get("username", ""),
                                 e.get("password", ""), e.get("url", ""),
                                 e.get("notes", ""), e.get("category", ""))
                db.save(new_path)
                vault_path = new_path
            else:
                db = kdbx.KdbxDatabase.load(vault_path, master_password)
            _vault_path, _db, _unlocked = vault_path, db, True
            pyotherside.send("vault-unlocked")
        except kdbx.KdbxError as e:
            pyotherside.send("vault-unlock-failed", _fail_reason(e))
        except Exception as e:
            _emit_error("unlock_vault", e)


def change_master_password(old_password, new_password):
    """Re-encrypt the vault under a new master password (the current one
    must be re-entered)."""
    if not _unlocked:
        _emit_error("change_master_password", "vault-locked")
        return
    with _lock:
        try:
            if not _db.check_password(old_password):
                pyotherside.send("change-password-failed", "wrong-password")
                return
            _db.set_password(new_password)
            _save_locked()
            pyotherside.send("master-password-changed")
        except Exception as e:
            _emit_error("change_master_password", e)


def export_vault(dest_path, vault_path=None):
    """Copy the encrypted .kdbx somewhere else (SD card, Documents, a
    synced folder ...). The copy opens in KeePass as-is."""
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
    """Copy a .kdbx (from KeePass, or an app backup) into the app's vault
    location. It is NOT unlocked here -- call unlock_vault afterwards with
    that database's master password. An existing vault is kept as .bak."""
    vault_path = vault_path or _default_vault_path()
    if vault_path.endswith(".pmvault"):
        vault_path = os.path.join(os.path.dirname(vault_path), _VAULT_FILENAME)
    try:
        if not os.path.isfile(src_path):
            _emit_error("import_vault", "source-not-found")
            return
        if not kdbx.is_kdbx(src_path):
            _emit_error("import_vault", "not-a-kdbx-file")
            return
        os.makedirs(os.path.dirname(vault_path), exist_ok=True)
        if os.path.isfile(vault_path):
            shutil.copyfile(vault_path, vault_path + ".bak")
        shutil.copyfile(src_path, vault_path)
        pyotherside.send("vault-imported", vault_path)
    except Exception as e:
        _emit_error("import_vault", e)


def lock_vault():
    """Forget the key and the decrypted database. The file on disk is
    untouched."""
    global _unlocked, _db
    with _lock:
        _unlocked = False
        _db = None
    pyotherside.send("vault-locked")


def is_unlocked():
    return _unlocked


def list_entries(query=""):
    if not _unlocked:
        _emit_error("list_entries", "vault-locked")
        return
    query = (query or "").strip().lower()
    results = []
    for e in _db.entries():
        haystack = "%s %s %s" % (e["title"], e["username"], e["category"])
        if query and query not in haystack.lower():
            continue
        results.append({k: e[k] for k in
                        ("uuid", "title", "username", "url", "category", "modified")})
    results.sort(key=lambda x: x["title"].lower())
    pyotherside.send("entries-list-result", results)


def _is_weak(pw):
    if len(pw) < 8:
        return True
    classes = sum(bool(x) for x in (
        any(c.islower() for c in pw), any(c.isupper() for c in pw),
        any(c.isdigit() for c in pw), any(not c.isalnum() for c in pw)))
    return classes < 2


def get_overview():
    """Data for the "Aegis" home screen: counters, per-category counts and
    the most recently changed entries. Passwords never leave the backend;
    only the weak / reused flags are computed here."""
    if not _unlocked:
        _emit_error("get_overview", "vault-locked")
        return
    all_entries = _db.entries()
    seen = {}
    for e in all_entries:
        pw = e.get("password") or ""
        if pw:
            seen[pw] = seen.get(pw, 0) + 1
    at_risk = 0
    cats = {}
    for e in all_entries:
        pw = e.get("password") or ""
        if pw and (_is_weak(pw) or seen[pw] > 1):
            at_risk += 1
        cats[e["category"]] = cats.get(e["category"], 0) + 1
    recent = sorted(all_entries, key=lambda x: x.get("modified", 0), reverse=True)[:5]
    pyotherside.send("overview-result", {
        "total": len(all_entries),
        "atRisk": at_risk,
        "secure": len(all_entries) - at_risk,
        "categories": [{"name": k, "count": v} for k, v in
                       sorted(cats.items(), key=lambda kv: (-kv[1], kv[0].lower()))],
        "recent": [{k: e[k] for k in ("uuid", "title", "username", "url",
                                      "category", "modified")} for e in recent],
    })


def get_entry(uuid):
    if not _unlocked:
        _emit_error("get_entry", "vault-locked")
        return
    entry = _db.get_entry(uuid)
    if entry is None:
        _emit_error("get_entry", "not-found")
        return
    pyotherside.send("entry-detail-result", entry)


def get_entry_secret(uuid, field):
    if not _unlocked:
        _emit_error("get_entry_secret", "vault-locked")
        return
    entry = _db.get_entry(uuid)
    if entry is None:
        _emit_error("get_entry_secret", "not-found")
        return
    pyotherside.send("secret-ready", field, entry.get(field, "") or "")


def add_entry(title, username, password, url, notes, category):
    if not _unlocked:
        _emit_error("add_entry", "vault-locked")
        return
    with _lock:
        try:
            _db.add_entry(title or "Untitled", username or "", password or "",
                          url or "", notes or "", category)
            _save_locked()
        except Exception as e:
            _emit_error("add_entry", e)
            return
    pyotherside.send("entry-saved")


def update_entry(uuid, title, username, password, url, notes, category):
    if not _unlocked:
        _emit_error("update_entry", "vault-locked")
        return
    with _lock:
        try:
            # empty password = keep the existing one
            if not _db.update_entry(uuid, title, username, password, url,
                                    notes, category):
                _emit_error("update_entry", "not-found")
                return
            _save_locked()
        except Exception as e:
            _emit_error("update_entry", e)
            return
    pyotherside.send("entry-saved")


def delete_entry(uuid):
    if not _unlocked:
        _emit_error("delete_entry", "vault-locked")
        return
    with _lock:
        try:
            _db.delete_entry(uuid)
            _save_locked()
        except Exception as e:
            _emit_error("delete_entry", e)
            return
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
    """Wipe the vault file and start over with an empty one. Destructive:
    the old entries are unrecoverable unless a backup/.bak exists."""
    vault_path = vault_path or _default_vault_path()
    try:
        if os.path.isfile(vault_path):
            os.remove(vault_path)
        create_vault(vault_path, new_master_password)
    except Exception as e:
        _emit_error("reset_vault", e)
