# Authentication setup

## Email accounts

Keep **Confirm email** enabled in Supabase Auth. Student sign-up creates a student profile, and staff assign them to a batch. For production sign-up and password reset emails, configure custom SMTP in Supabase Auth.

Staff use the same sign-in screen. The database grants admin to verified `harshitkumar9030@gmail.com` and teacher to verified `sharmashriju14@gmail.com`. Matching an unverified email does not grant a staff role. This mapping lives in the `verified_staff_accounts` migration, not Flutter.

## Google sign-in

1. In Google Auth Platform, create an OAuth **Web application** client.
2. Add `https://nrkckivcqfejawlrcskh.supabase.co/auth/v1/callback` as its authorized redirect URI.
3. In Supabase Dashboard → Authentication → Sign In / Providers → Google, enable Google and enter the Web client ID and secret. Keep the secret in Supabase, never in the Flutter app.
4. In Supabase Dashboard → Authentication → URL Configuration, add `com.harshitkumar.classlms://login-callback` to **Additional Redirect URLs**.
5. Build and install a new APK. Sign in with Google and check that the app receives the session. Verified staff addresses get their assigned role automatically.

The Android and iOS apps register the same callback scheme. If you change it, update both native manifests and `AuthRepository.signInWithGoogle`.

Email confirmation uses this callback too. Open the confirmation email on the phone with the app installed. Supabase verifies the address and returns to the app. The project's default Site URL is currently `localhost:3000`; replace it in **Authentication → URL Configuration** with a real web address for links opened on a computer. An inaccessible Site URL can show a browser error after verification even when the email was confirmed.
