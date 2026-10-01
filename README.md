# Class LMS

A Flutter app for private English tuition. Students see only material assigned to their batches; teachers publish lessons, classes, quizzes and homework.

## Local setup

1. Install Flutter 3.38 or newer and run `flutter pub get`.
2. Create a Supabase project and run the SQL in `supabase/migrations` in order.
3. Copy `.env.example.json` to `.env.local.json`, add your project URL and **publishable** key, then run:

```sh
flutter run --dart-define-from-file=.env.local.json
```

The publishable key is safe for the client. Never put the service role key in the app. The database policies enforce roles and batch access.

See [docs/architecture.md](docs/architecture.md) for feature boundaries and routes.

## Accounts

Students can create an account from **Sign in → New here? Create an account**. Email confirmation must remain enabled, and a teacher must assign each student to a batch. The two verified staff addresses are assigned by the database: `harshitkumar9030@gmail.com` is admin and `sharmashriju14@gmail.com` is teacher. Staff use the same email/password or Google sign-in buttons as students.

Google sign-in needs a Google OAuth Web client and Supabase Auth provider setup. See [docs/auth-setup.md](docs/auth-setup.md).

## Managing classes

Admins and teachers open **Home → Manage class content** or **Profile → Teacher workspace**. Create a course and batch first, then enroll students in **User management** (admin only). Resources need a course; announcements, events, assignments, and quizzes can target selected batches. Announcements can instead target individual students. Open an existing item in its section to edit, unpublish, reschedule, or delete it. Teachers can change their own content; admins can change any content. Quiz questions are locked once a student starts an attempt.

**Report cards** in the workspace show scored quizzes, due assignments, on-time submissions, resource opens, trends, and practical next steps. Select 30 days, 90 days, or all time, then generate and share a PDF. Reports reflect recorded activity only; attendance and reading completion are not tracked.
