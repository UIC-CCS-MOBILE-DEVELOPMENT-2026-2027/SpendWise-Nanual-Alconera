# SpendWise

**A Gamified Expense Tracking Mobile Application with Budgeting, Spending Insights, and Money Quest**

SpendWise is an offline Flutter personal finance application for recording expenses,
tracking account balances, managing budgets, and reviewing spending. Money Quest
adds XP, coins, levels, badges, themes, and daily and weekly challenges.

Developed for academic and mobile application development purposes by
**Louie Jay Alconera** and **Jayce Bruce Nanual**.

## Table of contents

- [Features](#features)
- [Technology stack](#technology-stack)
- [Application architecture](#application-architecture)
- [Project structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Installation and setup](#installation-and-setup)
- [Running the application](#running-the-application)
- [Accounts and money](#accounts-and-money)
- [Storage, backups and recovery](#storage-backups-and-recovery)
- [Testing and Android distribution](#testing-and-android-distribution)
- [AI disclosure and human accountability](#ai-disclosure-and-human-accountability)
- [Known limitations](#known-limitations)
- [License](#license)

## Features

### Expense tracking

- Add, edit, and delete expenses with a description, amount, spending category,
  payment account, and date.
- Use direct pencil and trash controls in expense history and Calendar.
- Search descriptions, categories, and payment accounts. Filter by payment account
  and current month. The displayed history total follows the active filters.

### Accounts and transfers

- Track Cash on Hand, Bank, E-Wallet, and custom accounts, such as GCash.
- Set opening balances and view calculated account balances on the dashboard.
- Rename accounts across recorded expenses and transfers.
- Prevent deletion of accounts with recorded activity or a nonzero balance.
- Transfer money between accounts without adding to expense totals.

### Budget management

- Set an overall monthly spending limit and category-specific limits.
- Monitor spending against configured limits, or remove a limit.
- Show in-app warnings when adding or editing an expense increases current-month
  spending beyond an overall or category limit. These are not push notifications.
- Distinguish an unset budget from an exceeded limit.

### Spending insights and Calendar

- Review spending summaries and category breakdowns.
- Navigate between calendar months and inspect individual dates.
- View daily expense totals and dates with recorded expenses.
- Edit or delete expenses from the selected day's records.

### Money Quest

- Earn XP and coins through eligible expense-tracking and budgeting activities.
- Progress through levels and titles, complete quests, and unlock persistent badges.
- Maintain expense-recording streaks and complete daily and weekly challenges.
- Spend reward coins on selectable themes. Coins have no monetary value.

### Local persistence and backups

- Save expenses, wallet data, budgets, reward progress, and theme selections locally.
- Copy a backup, validate and restore a backup, or copy unreadable data for recovery.
- Preserve records across sessions subject to platform storage behavior.

## Technology stack

| Technology | Purpose |
|---|---|
| Flutter | Application UI and platform integration |
| Dart | Application and domain logic |
| `StatefulWidget` and `setState()` | Built-in UI state management |
| `shared_preferences` | Local key-value persistence |
| Flutter Test and Flutter Lints | Automated tests and static analysis |
| Git, GitHub, and GitHub Actions | Version control and automated checks |
| Android SDK and Java | Android builds and device testing |

The current implementation does not use Riverpod, a custom remote backend,
a remote database, or external financial data APIs for its core features.

## Application architecture

SpendWise uses a lightweight, UI-centered architecture rather than formal MVVM.
Much of the screen state and coordination remains in `main.dart`, with separate
widgets, financial models, domain utilities, and a storage service.

| Component | Responsibilities |
|---|---|
| Presentation | Dashboard, Expenses, Insights, Quest, Budget, Calendar, account dialogs, and backup interface |
| Application state | In-memory state, coordinated UI actions, saving, and feedback through `StatefulWidget` and `setState()` |
| Financial models | `Expense`, `Wallet`, and `Transfer` represent records and calculate account balances |
| Domain logic | `Money` parses decimal input and performs centavo arithmetic; `RewardEngine` evaluates date-aware rewards and streaks |
| Persistence | `ExpenseStorage` validates and migrates saved data and coordinates snapshot writes to SharedPreferences |

User actions pass from widgets to application logic, which updates financial or
reward data through the storage service. The UI reflects saved changes or displays
failure feedback. Related financial and reward changes are saved together where
supported by the corresponding storage operation.

## Project structure

```text
SpendWise-Nanual-Alconera/
├── lib/
│   ├── main.dart                  # App shell, screens, dialogs, and coordination
│   ├── expense_history.dart       # Searchable, filtered expense history
│   ├── expense_actions.dart       # Shared pencil and trash buttons
│   ├── wallet_panel.dart          # Account and transfer interfaces
│   ├── backup_dialog.dart         # Backup, recovery, and restore confirmation
│   ├── domain/
│   │   ├── money.dart             # Parsing and centavo arithmetic
│   │   └── reward_engine.dart     # Reward, challenge, and streak rules
│   ├── models/
│   │   ├── expense.dart           # Expense model and serialization
│   │   └── wallet.dart            # Wallet, transfers, and balance calculations
│   └── services/
│       └── expense_storage.dart   # Snapshot validation, migration, and writes
├── test/                         # Integrity, rewards, and widget regression tests
├── .github/workflows/flutter.yml # Automated analysis, tests, and Android build
├── android/
├── ios/
├── web/
├── windows/
├── linux/
├── macos/
├── pubspec.yaml
├── pubspec.lock
├── analysis_options.yaml
└── README.md
```

Platform directories do not imply that every platform has been fully tested.
Git history replaces the old `*_before_badges.dart` copies and troubleshooting logs.

## Prerequisites

The verified local toolchain is **Flutter 3.47.2 / Dart 3.13.2**. The package declares
Dart `^3.12.2`. CI pins Flutter 3.47.2 and uses Java 17; Android compilation targets
Java 17.

Install:

- [Flutter SDK](https://docs.flutter.dev/get-started/install), which includes Dart.
- [Git](https://git-scm.com/downloads).
- [Visual Studio Code](https://code.visualstudio.com/) or another compatible IDE.
- Android SDK tools, typically installed through Android Studio, and a compatible JDK.
- An Android emulator or physical Android device for Android testing.

Check the environment and resolve required toolchain issues:

```sh
flutter --version
dart --version
flutter doctor
git --version
```

## Installation and setup

```sh
git clone https://github.com/UIC-CCS-MOBILE-DEVELOPMENT-2026-2027/SpendWise-Nanual-Alconera.git
cd SpendWise-Nanual-Alconera
flutter pub get --enforce-lockfile
flutter analyze
flutter test
```

If already cloned, open the existing project folder instead. Access to the
repository may require an authorized GitHub account.

Keep `pubspec.lock` committed so developers and CI use the same dependency set.
The Android SharedPreferences implementation override retains the tested release
startup-fix floor. Re-evaluate it only alongside Android release testing.

## Running the application

Connect an Android device with USB debugging enabled or start an emulator:

```sh
flutter devices
flutter run
```

To select a device explicitly:

```sh
flutter run -d DEVICE_ID
```

Replace `DEVICE_ID` with the identifier reported by `flutter devices`.

## Accounts and money

Opening balances represent the amount held **before all recorded transactions**.
They are setup values, not income records. New accounts default to zero unless an
opening balance is entered. Expenses can make a balance negative when the opening
amount is missing or spending exceeds funds. Transfers require sufficient available
funds.

For a withdrawal, transfer from Bank or E-Wallet to Cash on Hand. Record any
withdrawal fee separately from the account charged. Transfers preserve the total
across accounts and do not count toward expense budgets or expense challenges.

Account and overall monthly budget amount fields use placeholders. Leaving an
amount blank when editing an account or an existing overall monthly budget preserves
its saved value. Use the explicit remove-limit action to clear the overall budget.

Expense and transfer amounts use integer centavos internally. Account balances and
summary calculations aggregate centavos. Forms accept ordinary positive decimal
amounts with at most two fractional digits; opening balances also allow zero.
Recorded expenses use today or an earlier date. Existing future-dated entries are
retained during upgrades, but excluded from earned activity rewards. Correct their
dates before saving an edit. Legacy fractional values round to the nearest centavo
when converted; the original legacy storage keys remain on the device.

## Storage, backups and recovery

The app uses a versioned snapshot (`spendwise_snapshot_v1`) in SharedPreferences.
Financial account renames save wallet and expense references in one update. Reward
claims and balances save together, as do theme purchases and coin deductions.
Writes are serialized across storage instances within the running Dart isolate;
UI mutations are coordinated. Legacy preference records are read and validated when
no snapshot exists. The first successful write creates the snapshot and preserves
the legacy keys. Older app versions do not understand the new snapshot; avoid
downgrading after entering data.

A malformed saved record opens a recovery screen instead of silently resetting
history. Normal editing stays disabled until loading succeeds or a valid backup is
restored. There is no automatic destructive reset.

Open **Backup and restore** from the dashboard icon or an app-bar action:

1. Choose **Copy backup**, then paste into a text file and save it securely.
2. To restore, paste a previously exported SpendWise backup and choose **Review restore**.
3. Review the expense count and confirm replacement. Import replaces, rather than
   merges, the data. Validation happens before any replacement.

Before a restore writes replacement data, a raw recovery copy is saved on-device
under `spendwise_before_restore`. This holds the latest pre-restore copy, not a
history of backups. The recovery screen can also copy unreadable data for
troubleshooting. Recovery dumps are not directly importable backups.

Backups contain private financial information and are **not encrypted**. Clipboard
contents may be visible to other applications or clipboard managers. SharedPreferences
remains a lightweight local store with platform-specific disk-persistence guarantees;
the snapshot approach prevents split-key updates but is not a transactional database.
Keep an external backup for important records. Clearing app data or uninstalling may
remove local records. Platform backup/restore may apply according to device settings.

## Testing and Android distribution

```sh
flutter analyze
flutter test
flutter build apk --release --no-pub
```

Run dependency installation first, as shown in setup. Analysis checks source and
lint issues; tests exercise the included regression scenarios; the build checks
Android compilation. These commands do not establish complete device compatibility.

Test APK output: `build/app/outputs/flutter-apk/app-release.apk`.
**Release builds currently use the debug signing key.** Configure a permanent
application ID, protected release signing credentials, and a versioning policy before
public distribution. Changing identity/signing may prevent existing installations
from updating normally. Never commit signing keys or passwords.

The GitHub Actions workflow is configured to run analysis, tests, and an Android
release-build check on pushes and pull requests. Check the workflow results for
actual pass/fail status. Automated tests mock storage and phone keyboard insets;
they do not replace physical-device testing.

Before distribution, verify expense and budget saving with the keyboard open,
account rename/delete, transfers, backup/restore, cold restart persistence, calendar
navigation, challenge rewards, and theme purchases on a physical Android device.
Test upgrades using realistic legacy records, large text, and screen-reader navigation.

## AI disclosure and human accountability

### Team

**Louie Jay Alconera and Jayce Bruce Nanual** collaborated on the project overall,
including its code and documentation. Work was shared rather than assigned as
exclusive ownership of individual modules. The team remains accountable for
reviewing the source code, verifying behavior, understanding technical decisions,
and submitting the final application and documentation.

### AI tools used

| Tool | Disclosed assistance |
|---|---|
| ChatGPT (OpenAI) | Code and documentation assistance, as reported by the team |
| Claude (Anthropic) | Code and documentation assistance, as reported by the team |
| Codex (OpenAI) | Code review, account and transfer implementation assistance, debugging, data integrity and reward improvements, UI updates, automated test and build checks, and documentation updates in this project workflow |

AI assistance included code generation and direct project edits, not only explanations
or suggestions. Codex also executed development checks during the workflow; those
checks should not be attributed to independent manual execution by a team member.
AI output and passing automated checks do not establish correctness on every device.
The team must review generated changes and perform the necessary device testing.

## Known limitations

- No app-managed cloud sync, bank integration, login, or app lock.
- Backups use copied text rather than automatic cloud backup or multi-device sync.
- Opening balances and transfers do not provide a separate income-tracking feature.
- Expense balances may become negative; this is a manual tracker, not a banking service.
- Key-value persistence and unencrypted exports are not a production banking database.
- Much application state and coordination remains in `main.dart`, so future growth may
  benefit from gradual extraction into smaller components.
- Platform scaffolding, automated checks, and development builds do not establish
  production readiness or comprehensive device compatibility.

## License

No license has been specified. Contact the project owners before redistribution.
