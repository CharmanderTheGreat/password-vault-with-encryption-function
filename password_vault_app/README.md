# Password Vault App

Offline, encrypted password manager — Android, iOS, Windows, Linux, macOS.
No internet connection is used at any point. No cloud, no sync, no telemetry.

## Features

- **One master password** unlocks the whole vault (never stored — only a
  salt + verifier are stored, per industry-standard practice)
- **AES-256-GCM encryption** for every stored username/password/note
- **Argon2id key derivation** — makes brute-forcing the master password
  computationally expensive even if someone steals your device's storage
- **Password generator** — cryptographically random, customizable length
  and character sets, so every account gets a genuinely different password
- **Entropy-based strength meter** — real bit-strength calculation, not a
  guessed "weak/medium/strong" label
- **Monthly rotation tracking** — flags any account whose password is
  30+ days old, right on the dashboard
- **Auto-lock** — vault re-locks itself after 3 minutes of inactivity or
  when the app is backgrounded

## Getting Started

You'll need the Flutter SDK installed on your own machine (this was built
without a live Flutter environment, so **build and test it locally**
before relying on it):

```bash
# 1. Install Flutter: https://docs.flutter.dev/get-started/install
flutter --version   # confirm it's installed

# 2. Get dependencies
cd password_vault_app
flutter pub get

# 3. Run on a connected device/emulator
flutter run

# 4. Build a release APK (Android)
flutter build apk --release

# 5. Build for desktop (enable the platform first if needed)
flutter config --enable-windows-desktop   # or --enable-linux-desktop / --enable-macos-desktop
flutter build windows   # or: flutter build linux / flutter build macos
```

## Architecture

```
lib/
├── main.dart                          # entry point, routing, auto-lock enforcement
├── core/
│   ├── encryption/
│   │   ├── key_derivation.dart        # Argon2id: master password -> AES key
│   │   └── vault_cipher.dart          # AES-256-GCM encrypt/decrypt
│   ├── database/
│   │   ├── database_helper.dart       # SQLite setup (mobile + desktop)
│   │   └── vault_repository.dart      # CRUD, encrypts/decrypts transparently
│   ├── models/
│   │   └── vault_entry.dart           # one saved account
│   └── session/
│       └── vault_session.dart         # in-memory unlocked session state
├── features/
│   ├── auth/
│   │   └── master_password_service.dart  # setup / unlock / change master pass
│   ├── generator/
│   │   └── password_generator.dart    # secure random password generator
│   └── strength_checker/
│       └── strength_calculator.dart   # entropy + estimated crack time
└── ui/screens/
    ├── setup_screen.dart              # first-run: create master password
    ├── unlock_screen.dart             # every other run: enter master password
    ├── vault_list_screen.dart         # dashboard: all accounts, rotation warnings
    └── add_edit_entry_screen.dart     # add/edit an account, generate password
```

## Important security notes (please read)

- **There is no password recovery.** If you forget your master password,
  the vault cannot be decrypted — by design. Nobody, including you, can
  bypass this. Consider writing your master password down and storing it
  somewhere physically secure (not digitally) as a backup.
- **This protects data at rest on your device.** It does not protect you
  if your device itself is compromised (e.g. malware with root/keylogger
  access) or if someone watches you type your master password.
- **Real login-alert monitoring (who logged into your Facebook, from what
  device/location) is only available from the platforms themselves** —
  Facebook's "Where You're Logged In," Google's "Your devices," etc. This
  app can't pull that data since those platforms don't expose it to
  third-party apps. Enabling 2FA and reviewing those native security pages
  regularly is still the most effective step you can take there.
- Before relying on this for real accounts, consider having someone else
  review the encryption code, and back up the SQLite database file
  (`vault.db`, found in the app's documents directory) somewhere safe —
  it's encrypted, so a backup copy is not a security risk by itself.

## Possible next additions

- Biometric unlock (fingerprint/Face ID) layered on top of the master password
- Encrypted export/import (for moving vaults between your own devices)
- Password breach checking against Have I Been Pwned (would require
  opting into internet access for that one lookup, using k-anonymity so
  your actual password is never sent anywhere)
