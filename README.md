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
