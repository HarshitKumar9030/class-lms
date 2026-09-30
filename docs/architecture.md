# Architecture

## Layers

`lib/core` owns configuration, theme, routing, shared widgets, and Supabase access. Each folder under `lib/features` owns its models, repository, application state, and screens. Widgets consume Riverpod providers; repositories own all remote queries and writes. Supabase authentication owns the persistent session. PostgreSQL Row Level Security (RLS) is the authorization boundary.

The app boots only when `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` are present. A missing configuration produces a setup screen rather than a pretend local account.

## Roles and content

- `profiles` has one row per Auth user and a database controlled `student`, `teacher`, or `admin` role.
- `batch_members` maps students to batches. All assigned content has a `batch_ids` array. An empty array means all enrolled students.
- Students read assigned content and their own progress, submissions, attempts and notifications. Staff can manage class content. Only admins can change roles and membership.
- Uploaded files remain in private Storage buckets. The client requests signed URLs after the database has established that the resource is visible to that user.

## Routes

| Path | Destination | Access |
| --- | --- | --- |
| `/sign-in`, `/forgot-password` | Authentication | Signed out |
| `/home` | Today, announcements, learning and upcoming work | Student |
| `/learn`, `/learn/:id` | Resource library and viewer | Student |
| `/schedule` | Weekly classes | Student |
| `/quizzes`, `/quizzes/:id`, `/quizzes/:id/attempt` | Quiz list, introduction and attempt | Student |
| `/assignments`, `/assignments/:id` | Homework and submission | Student |
| `/announcements`, `/announcements/:id` | Feed and detail | Student |
| `/notifications`, `/profile` | Inbox and settings | Student |
| `/teacher` and `/teacher/*` | Staff overview and content management | Teacher/admin |

The five student tabs are Home, Learn, Schedule, Quizzes and Profile. Secondary pages push over the shell. Teacher routes use their own shell.

## Query and state conventions

Repositories return typed models and throw errors to providers. Screens show loading, empty, error, and populated states. Mutations invalidate the affected providers. Long lists use paginated queries. An attempt's answers are written individually, and final submission is a database transaction through an RPC so retries cannot create duplicate results.

## Release configuration

Set a private Supabase project, configure email authentication and SMTP, run migrations, invite a first admin through a trusted SQL or server side process, and test RLS with separate student, teacher and admin accounts. Push notifications require Firebase/APNs credentials and a server side sender; no sender keys belong in the app.
