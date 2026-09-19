# Grand Vault

An offline-first, encrypted password manager built with Flutter. Runs on Android and Windows desktop from a single codebase.

## Features

- **AES-256-GCM encryption + Argon2id key derivation** — all credentials are encrypted locally before they ever touch disk. No network call is required to unlock or use the vault.
- **Master password + Quick Unlock** — unlock with your master password, or use device biometrics/PIN via `local_auth` for faster daily access.
- **Optional cloud account & sync** — sign in with Google to back up and sync your encrypted vault across devices via Firebase/Firestore. Fully optional; the vault works entirely offline without an account.
- **Explicit per-entry actions** — every saved account has four dedicated controls: copy username, copy password, open the site link, and edit. No ambiguous "tap to auto-login" behavior.
- **Self-clearing clipboard** — copied credentials automatically clear from the clipboard after 30 seconds, with a live countdown shown in a system notification (visible even outside the app) so you always know when it's safe.
- **Password rotation reminders** — entries older than 30 days are flagged so stale passwords don't go unnoticed.
- **CSV import/export** — bring in existing passwords from a browser export, or export your vault as a plain CSV backup.
- **Dark / light theme** — toggle anytime; layout adapts responsively between a mobile list view and a wide-screen grid view.

## Tech stack

| Layer | Choice |
|---|---|
| Framework | Flutter (Android + Windows) |
| Local storage | SQLite (`sqflite` on mobile, `sqflite_common_ffi` on desktop) |
| Encryption | `cryptography` (pure Dart, AES-256-GCM + Argon2id) |
| Auth & sync | Firebase Auth, Cloud Firestore, Google Sign-In |
| Biometrics | `local_auth` |
| State management | `provider` |
| Notifications | `flutter_local_notifications` |
| Desktop window control | `window_manager` |

## Project structure

```
lib/
├── core/
│   ├── database/        # local SQLite access, sync queue, cloud sync service
│   ├── encryption/       # AES-256-GCM + Argon2id implementation
│   ├── models/            # VaultEntry and other data models
│   ├── session/           # in-memory unlocked vault session
│   ├── storage/           # non-secret metadata (salt, verifier)
│   ├── theme/             # app theming, dark/light mode
│   └── utils/              # app launcher, clipboard cooldown service, etc.
├── features/
│   ├── auth/               # master password, Google Sign-In services
│   └── import_export/      # CSV import/export
└── ui/
    ├── screens/            # unlock, setup, vault list, add/edit entry, settings
    └── widgets/            # shared UI components
```

## Getting started

1. **Clone the repo**
   ```
   git clone https://github.com/CharmanderTheGreat/password-vault-with-encryption-function.git
   cd password-vault-with-encryption-function
   ```

2. **Install dependencies**
   ```
   flutter pub get
   ```

3. **Firebase setup**
   This project uses Firebase for optional account sign-in and cloud sync. Firebase config files (`firebase_options.dart`, `google-services.json`) are **not included** in this repo for security — you'll need to create your own Firebase project and generate these via the [FlutterFire CLI](https://firebase.google.com/docs/flutter/setup).

4. **Check available devices**
   ```
   flutter devices
   ```
   This lists every connected device/emulator along with its device ID.

5. **Run the app**
   ```
   flutter run -d windows
   ```
   or, for a connected Android device, using the ID from the previous step:
   ```
   flutter run -d <device-id>
   ```

## Security notes

- Master passwords are never stored — only a verifier derived via Argon2id is kept, used to confirm a correct unlock attempt.
- All vault entries are encrypted at rest with AES-256-GCM before being written to local storage or synced to the cloud.
- The app makes no network calls unless a Google account is signed in for cloud sync; the vault is fully usable offline.

## Status

Actively in development. Android is the current primary build target; Windows desktop support is also functional.

## License

Not yet specified.