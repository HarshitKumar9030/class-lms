import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_components.dart';
import 'auth_repository.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});
  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool busy = false;
  String? error;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (email.text.trim().isEmpty || password.text.isEmpty) {
      setState(() => error = 'Enter your email and password.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref.read(authRepositoryProvider).signIn(email.text, password.text);
      if (mounted) context.go('/home');
    } on AuthException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              error = 'Couldn’t sign in. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.page),
            shrinkWrap: true,
            children: [
              Icon(
                Icons.menu_book_rounded,
                size: 32,
                color: context.palette.accent,
              ),
              const SizedBox(height: 32),
              Text(
                'Welcome back',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Your English class, all in one place.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: context.palette.secondary,
                ),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Email address'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: password,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) => submit(),
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 24),
              PrimaryButton(label: 'Sign in', onPressed: submit, busy: busy),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.push('/forgot-password'),
                child: const Text('Forgot password?'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final email = TextEditingController();
  bool busy = false;
  bool sent = false;
  String? error;

  @override
  void dispose() {
    email.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (email.text.trim().isEmpty) {
      setState(() => error = 'Enter your email address.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref.read(authRepositoryProvider).resetPassword(email.text);
      if (mounted) setState(() => sent = true);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Couldn’t send the email. Try again.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Reset password')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.page),
            shrinkWrap: true,
            children: [
              Text(
                sent ? 'Check your inbox' : 'Forgot your password?',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 10),
              Text(
                sent
                    ? 'If this address has an account, you’ll receive a reset link shortly.'
                    : 'Enter the email you use for class.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: context.palette.secondary,
                ),
              ),
              if (!sent) ...[
                const SizedBox(height: 32),
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(labelText: 'Email address'),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                PrimaryButton(
                  label: 'Send reset link',
                  onPressed: submit,
                  busy: busy,
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
