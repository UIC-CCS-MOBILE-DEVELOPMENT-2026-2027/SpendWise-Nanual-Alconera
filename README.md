# SpendWise

SpendWise is an offline Flutter expense tracker with account balances, budgeting,
a calendar, and Money Quest rewards.

## Features

- Record, edit and delete expenses with a spending category and payment account.
- Track Cash on Hand, Bank, E-Wallet and custom accounts. Rename an account across
  its recorded expenses and transfers. Accounts with activity or money cannot be deleted.
- Transfer between accounts without adding to expense totals.
- Search expense descriptions, categories and accounts. Filter by payment account
  and current month. The displayed history total follows the active filters.
- Set an overall monthly budget and category limits, receive overspending warnings,
  or remove the overall limit. An unset budget is distinct from an exceeded limit.
- Browse monthly spending and individual days in Calendar.
- Earn persistent quests, badges, streaks and daily/weekly challenges. Spend reward
  coins on themes. These coins have no monetary value.
- Copy a backup, validate and restore a backup, or copy preserved recovery data.

## Development

The tested toolchain is **Flutter 3.47.2 / Dart 3.13.2**. The package declares
Dart `^3.12.2`. Install Flutter and an Android SDK/JDK appropriate for the Flutter
release. CI uses Java 17 and the pinned Flutter version above.

```sh
flutter pub get --enforce-lockfile
flutter analyze
flutter test
flutter run
```

Keep `pubspec.lock` committed so developers and CI use the same dependency set.
The Android SharedPreferences implementation override retains the tested release
startup-fix floor. Do not remove or upgrade it without Android release testing.

## Accounts and money

Opening balances represent the amount held **before all recorded transactions**.
They are setup values, not income records. New accounts start at zero. Expenses
can make a balance negative when the opening amount is missing or spending exceeds
funds. Transfers require sufficient available funds.

For a withdrawal, transfer from Bank or E-Wallet to Cash on Hand. Record any
withdrawal fee separately from the account charged. Transfers preserve the total
across accounts and do not count toward expense budgets or expense challenges.

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
Writes are serialized across storage instances and UI mutations are coordinated.
Legacy preference records are read and validated when no snapshot exists. The first
successful write creates the snapshot and preserves the legacy keys. Older app
versions do not understand the new snapshot; avoid downgrading after entering data.

A malformed saved record opens a recovery screen instead of silently resetting
history. Normal editing stays disabled until loading succeeds or a valid backup is
restored. There is no automatic destructive reset.

Open **Backup and restore** from the dashboard icon or an app-bar action:

1. Choose **Copy backup**, then paste into a text file and save it securely.
2. To restore, paste a previously exported SpendWise backup and choose **Review restore**.
3. Review the expense count and confirm replacement. Import replaces, rather than
   merges, the data. Validation happens before any replacement.

Before restoring, a raw recovery copy is retained on-device under
`spendwise_before_restore`. The recovery screen can also copy unreadable data for
troubleshooting. Recovery dumps are not directly importable backups.

Backups contain private financial information and are **not encrypted**. Clipboard
contents may be visible to other applications or clipboard managers. SharedPreferences
remains a lightweight local store with platform-specific disk-persistence guarantees;
the snapshot approach prevents split-key updates but is not a transactional database.
Keep an external backup for important records. Platform backup/restore may apply
according to device settings. There is no app-managed cloud sync, bank integration,
login or app lock.

## Project structure

- `lib/main.dart`: app shell, screens, dialogs and coordinated UI actions.
- `lib/expense_history.dart`: filtered history with lazy record construction.
- `lib/wallet_panel.dart`: account management and transfer interfaces.
- `lib/backup_dialog.dart`: backup/recovery and restore confirmation.
- `lib/domain/money.dart`: decimal input parsing and centavo arithmetic.
- `lib/domain/reward_engine.dart`: pure, date-aware reward and streak calculations.
- `lib/models/`: financial models and backward-compatible serialization.
- `lib/services/expense_storage.dart`: snapshot validation, migration and grouped writes.
- `test/`: financial integrity, reward rules, failure paths and widget regression tests.

Git history replaces the old `*_before_badges.dart` copies and troubleshooting logs.

## Android testing and distribution

```sh
flutter build apk --release --no-pub
```

Test APK output: `build/app/outputs/flutter-apk/app-release.apk`.
**Release builds currently use the development signing key.** Configure a permanent
application ID, protected release signing credentials and a versioning policy before
public distribution. Changing identity/signing may prevent existing installations
from updating normally. Never commit signing keys or passwords.

CI runs analysis, tests and an Android release-build check. Automated tests mock
storage and phone keyboard insets; they do not replace physical-device testing.
Before distribution, verify expense and budget saving with the keyboard open,
account rename/delete, transfers, backup/restore, cold restart persistence, calendar
navigation and theme purchases on a physical Android device. Test upgrades using
realistic legacy records, large text and screen-reader navigation.

## License

No license has been specified. Contact the project owners before redistribution.
