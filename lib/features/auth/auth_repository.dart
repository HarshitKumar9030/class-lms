import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/supabase_provider.dart';

enum AppRole { student, teacher, admin }

class UserProfile {
  const UserProfile({
    required this.id,
    required this.fullName,
    required this.role,
  });
  final String id;
  final String fullName;
  final AppRole role;

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['id'] as String,
    fullName: json['full_name'] as String? ?? '',
    role: AppRole.values.byName(json['role'] as String? ?? 'student'),
  );
}

class AuthRepository {
  const AuthRepository(this.client);
  final SupabaseClient client;

  Future<void> signIn(String email, String password) async =>
      client.auth.signInWithPassword(email: email.trim(), password: password);
  Future<void> resetPassword(String email) async =>
      client.auth.resetPasswordForEmail(email.trim());
  Future<void> signOut() async => client.auth.signOut();

  Future<UserProfile> profile() async {
    final id = client.auth.currentUser?.id;
    if (id == null) throw const AuthException('Please sign in again.');
    final data = await client
        .from('profiles')
        .select('id,full_name,role')
        .eq('id', id)
        .single();
    return UserProfile.fromJson(data);
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(supabaseProvider)),
);
final profileProvider = FutureProvider<UserProfile>(
  (ref) => ref.watch(authRepositoryProvider).profile(),
);
