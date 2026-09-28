# Password Manager for Ubuntu Touch

A local-only password manager for Ubuntu Touch / Lomiri built with QML, Python, and PyOtherSide. It stores all saved entries in a single encrypted vault file, protected by a master password, and keeps the vault fully portable by design.

Copyright (C) 2026 Renzard Politakis.
This project is licensed under the GNU Affero General Public License v3 or any later version. See the LICENSE file for details.

## Overview

This app follows a KeePass-style model:

- all data is stored in one encrypted file: `vault.pmvault`
- the vault is opened with a master password
- the master password is never stored on disk
- the data remains portable and can be restored after reinstall or factory reset
- the app is designed for local use only and does not require network access

The backend is implemented in Python, while the interface is built with QML and Ubuntu/Lomiri components. Communication between the two is handled through PyOtherSide.

## Features

- master password unlock / vault creation flow
- encrypted single-file vault storage
- searchable entries by title, username, or category
- add, edit, and delete credential entries
- copy username or password to clipboard with automatic clearing
- password generator with configurable length and character classes
- backup and restore by copying the encrypted vault file
- re-encrypting the vault when changing the master password
- local-only app design with no networking permissions

## Security model

The vault is not stored as plaintext JSON. Instead, it is saved as a small encrypted envelope containing:

- a random salt
- a random nonce
- AES-256-GCM ciphertext
- PBKDF2-HMAC-SHA256 key derivation settings

The master password is never written to disk. A key is derived from the password using PBKDF2-HMAC-SHA256 with 310,000 iterations, and the resulting AES key lives only in memory while the vault is unlocked.

When the vault is locked, the app clears the in-memory key and decrypted entry list. The vault file itself is never decrypted in place; it remains encrypted on disk at all times.

## Project structure

```text
password-manager-app-main/
├── LICENSE
├── README.md
├── manifest.json
├── clickable.json
├── password-manager.apparmor
├── password-manager.desktop
├── requirements.txt
├── backend/
│   ├── password_generator.py
│   └── vault_backend.py
├── qml/
│   ├── Main.qml
│   ├── components/
│   │   ├── EntryListItem.qml
│   │   └── SelfClearingClipboard.qml
│   └── pages/
│       ├── AddEditEntryPage.qml
│       ├── GeneratorPage.qml
│       ├── UnlockPage.qml
│       └── VaultPage.qml
├── build/
│   └── all/
│       └── app/
└── tools/
    └── vendor_pykeepass.sh
```

## How it works

### Frontend

The UI layer is implemented in QML under the `qml/` directory. Pages such as `UnlockPage.qml`, `VaultPage.qml`, `AddEditEntryPage.qml`, and `GeneratorPage.qml` display the application flow and invoke backend functions.

### Backend

The Python backend in `backend/vault_backend.py` exposes functions for:

- creating a vault
- unlocking a vault
- locking the vault
- listing entries
- fetching entry details
- retrieving secret fields
- adding, updating, and deleting entries
- exporting and importing the vault file
- changing the master password

### Bridge

The connection between QML and Python is handled through PyOtherSide. The backend emits events such as `vault-unlocked`, `entry-saved`, or `password-generated`, and the QML layer listens for them and updates the UI accordingly.

## Usage

### Create a vault

On first launch, the app will prompt for a master password. After confirming it, a new encrypted vault is created at the app's data directory as `vault.pmvault`.

### Unlock the vault

Open the app, enter the correct master password, and the vault is decrypted in memory. All entries remain available while the app is unlocked.

### Add entries

Use the `+` button to create a new entry. Each entry can include:

- title
- username/email
- password
- URL
- category
- notes

### Search entries

The main vault page includes a search box. It searches across title, username, and category without exposing the password list in the result view.

### Copy secrets

The app exposes copy actions for username and password, and the copied secret is cleared automatically after a short delay to reduce clipboard exposure.

### Generator

The built-in generator creates secure passwords using Python's `secrets` module, with options for uppercase, lowercase, digits, and symbols. It avoids ambiguous characters such as `I`, `l`, `1`, `O`, and `0` by default.

## Backup and restore

Because the full vault is stored as a single encrypted file, backup and restore are simple:

1. Open the app and use the backup/restore panel.
2. Choose a safe destination path such as Documents, an SD card, or another external storage location.
3. Save the backup file.
4. After reinstall or reset, restore the file and unlock it using the same master password.

This works because the vault file is self-contained and already encrypted at rest.

## Build and run

This project is designed for Ubuntu Touch / UBports and uses Clickable for packaging and deployment.

### Requirements

- Ubuntu Touch / UBports device or emulator
- Clickable installed on your host machine
- target runtime packages:
  - `python3-pyotherside`
  - `python3-cryptography`

### Build

```bash
pip install clickable
clickable
```

This builds the app and deploys it to a connected device or emulator, depending on your Clickable setup.

The project already declares runtime dependencies in `clickable.json`, and the build also runs a Python compile check on the backend:

```json
"dependencies_target": [
  "python3-cryptography"
]
```

## Notes

This project is a working reference implementation for an Ubuntu Touch app. It is structurally sound and follows a practical architecture for encrypted local storage, but it should still be verified on a real device or emulator before being treated as a production-ready release.

Possible follow-ups include:

- adding a proper app icon
- improving backup path selection with file-picker integration
- adding an inactivity auto-lock timer
- adding unit tests for the Python backend

## License

This project is licensed under the GNU Affero General Public License v3 or any later version. See the LICENSE file for details.
