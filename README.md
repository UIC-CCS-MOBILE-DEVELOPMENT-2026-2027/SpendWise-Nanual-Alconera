# SpendWise

**SpendWise** is a Flutter-based personal finance application designed to help users track expenses, manage budgets, and build better money-management habits through a simple and engaging experience.

## Features

- **Expense Tracking** — Add, edit, and delete expenses with a spending category and payment account.
- **Accounts** — Track Cash on Hand, Bank, GCash, and custom accounts with dashboard balances.
- **Transfers** — Move money between accounts without counting it as spending; review or delete transfers in the dashboard history.
- **Monthly Summaries** — Review expenses and monitor monthly spending.
- **Category Budgets** — Set budgets for individual spending categories and track progress.
- **Budget Alerts** — Receive warnings when spending exceeds the overall monthly budget.
- **Money Quest** — Complete financial challenges and earn XP and coins.
- **Data Persistence** — Keep saved expense and budget information when reopening the app.

## Built With

- [Flutter](https://flutter.dev/) — Cross-platform application framework
- [Dart](https://dart.dev/) — Programming language
- Flutter testing and static analysis tools

## Getting Started

### Prerequisites

Install the following before running the project:

- [Flutter SDK](https://docs.flutter.dev/get-started/install)
- [Git](https://git-scm.com/)
- [Visual Studio Code](https://code.visualstudio.com/) or another compatible IDE
- An Android emulator or compatible device, if running on Android

### Installation

1. Clone the repository:

   ```bash
   git clone https://github.com/UIC-CCS-MOBILE-DEVELOPMENT-2026-2027/SpendWise-Nanual-Alconera.git
   ```

2. Navigate to the project directory:

   ```bash
   cd SpendWise-Nanual-Alconera
   ```

3. Install the project dependencies:

   ```bash
   flutter pub get
   ```

4. Run the application:

   ```bash
   flutter run
   ```

## Testing

Run the automated tests:

```bash
flutter test
```

Check the project for potential issues:

```bash
flutter analyze
```

## Project Structure

```text
spendwise/
|-- android/
|-- ios/
|-- lib/
|-- linux/
|-- macos/
|-- test/
|-- web/
|-- windows/
|-- analysis_options.yaml
|-- pubspec.yaml
|-- pubspec.lock
`-- README.md
```

## Development Status

Core expense tracking, budgeting, Money Quest rewards, and saved-data persistence have been tested during development.

## License

No license has been specified yet. Please contact the project owner before reusing or redistributing this project.

## Account balances and withdrawals

On the dashboard, tap an account to enter its opening balance: the amount held
before all transactions recorded in this app. New accounts start at zero;
the previous fixed demo income is no longer used. Existing expenses are preserved
and assigned to Cash on Hand. Edit an expense to correct its payment account.
Spending categories (for example, Food & Dining) remain separate from accounts.

Use **Transfer / withdraw** for Bank → Cash on Hand or GCash → Cash on Hand.
Transfers change the two account balances but do not affect expense totals,
budgets, or expense quests. Record withdrawal fees separately as expenses from
the account charged. Transfers require sufficient funds in the source account.
Expense edits and deletions automatically recalculate account balances.

Data is stored locally on the device using shared preferences. There is no remote
backend, login, or cloud sync. Opening balances are setup values, not income records.

## Android release and form checks

Build an installable APK with `flutter build apk --release`. The output is
`build/app/outputs/flutter-apk/app-release.apk`. The project currently uses the
development signing key for release builds.

Phone-size regression tests cover saving expenses and monthly budgets with the
keyboard open. Budget and quest reward dialogs scroll on small screens so their
contents remain accessible. To verify on a device, save an expense, dismiss its
reward popup, set both overall and category budgets, and reopen the app to check
persistence. Also check account setup and a Bank → Cash on Hand transfer.
