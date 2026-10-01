import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_components.dart';
import '../auth/auth_repository.dart';
import 'staff_repository.dart';

class StaffUsersScreen extends ConsumerStatefulWidget {
  const StaffUsersScreen({super.key});
  @override
  ConsumerState<StaffUsersScreen> createState() => _StaffUsersState();
}

class _StaffUsersState extends ConsumerState<StaffUsersScreen> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final users = ref.watch(managedUsersProvider);
    return AppPage(
      title: 'User management',
      onRefresh: () async => ref.invalidate(managedUsersProvider),
      children: [
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Search name or email',
          ),
          onChanged: (value) =>
              setState(() => query = value.trim().toLowerCase()),
        ),
        const SectionHeader(title: 'Accounts'),
        users.when(
          loading: () => const LoadingRows(),
          error: (_, _) => ErrorState(
            message: 'Couldn’t load users.',
            onRetry: () => ref.invalidate(managedUsersProvider),
          ),
          data: (items) {
            final filtered = items
                .where(
                  (item) => '${item.name} ${item.email}'.toLowerCase().contains(
                    query,
                  ),
                )
                .toList();
            if (filtered.isEmpty) {
              return const CompactEmptyState(
                title: 'No matching accounts',
                message: 'Try another name or email.',
                icon: Icons.people_outline,
              );
            }
            return Column(
              children: [
                for (final user in filtered)
                  AppRow(
                    title: user.name.isEmpty ? user.email : user.name,
                    subtitle: '${user.email} · ${user.role}',
                    icon: Icons.person_outline,
                    onTap: () => context.push('/teacher/users/${user.id}'),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class StaffUserDetailScreen extends ConsumerStatefulWidget {
  const StaffUserDetailScreen({super.key, required this.userId});
  final String userId;
  @override
  ConsumerState<StaffUserDetailScreen> createState() => _StaffUserDetailState();
}

class _StaffUserDetailState extends ConsumerState<StaffUserDetailScreen> {
  bool busy = false;

  Future<void> changeRole(ManagedUser user, String role) async {
    if (role == user.role) return;
    final ownId = ref.read(authRepositoryProvider).client.auth.currentUser?.id;
    if (user.id == ownId) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Make ${user.name.isEmpty ? user.email : user.name} a $role?',
        ),
        content: const Text(
          'Changing a role changes what this account can access.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Change role'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => busy = true);
    try {
      await ref.read(staffRepositoryProvider).setUserRole(user.id, role);
      ref.invalidate(managedUsersProvider);
      ref.invalidate(staffStudentsProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Couldn’t change role.')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> toggleBatch(String batchId, bool enrolled) async {
    setState(() => busy = true);
    try {
      final repo = ref.read(staffRepositoryProvider);
      if (enrolled) {
        await repo.removeStudent(batchId, widget.userId);
      } else {
        await repo.addStudent(batchId, widget.userId);
      }
      ref.invalidate(managedUserBatchesProvider(widget.userId));
      ref.invalidate(staffBatchStudentIdsProvider(batchId));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn’t update batch enrollment.')),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(managedUsersProvider);
    final batches = ref.watch(staffBatchesProvider);
    final memberships = ref.watch(managedUserBatchesProvider(widget.userId));
    return AppPage(
      title: 'Manage account',
      children: users.when(
        loading: () => [const LoadingRows(count: 1)],
        error: (_, _) => [
          ErrorState(
            message: 'Couldn’t load account.',
            onRetry: () => ref.invalidate(managedUsersProvider),
          ),
        ],
        data: (items) {
          final matches = items.where((item) => item.id == widget.userId);
          if (matches.isEmpty) {
            return [
              const CompactEmptyState(
                title: 'Account unavailable',
                message: 'This account may have been removed.',
                icon: Icons.person_off_outlined,
              ),
            ];
          }
          final user = matches.first;
          final ownId = ref
              .read(authRepositoryProvider)
              .client
              .auth
              .currentUser
              ?.id;
          return [
            AppSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name.isEmpty ? 'Unnamed account' : user.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.email,
                    style: TextStyle(color: context.palette.secondary),
                  ),
                ],
              ),
            ),
            const SectionHeader(title: 'Access role'),
            Text(
              user.id == ownId
                  ? 'You cannot change your own role.'
                  : 'Choose the access this account should have.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              key: ValueKey(user.role),
              initialValue: user.role,
              decoration: const InputDecoration(labelText: 'Role'),
              items: const [
                DropdownMenuItem(value: 'student', child: Text('Student')),
                DropdownMenuItem(value: 'teacher', child: Text('Teacher')),
                DropdownMenuItem(value: 'admin', child: Text('Admin')),
              ],
              onChanged: user.id == ownId || busy
                  ? null
                  : (value) {
                      if (value != null) changeRole(user, value);
                    },
            ),
            if (user.role == 'student') ...[
              const SectionHeader(title: 'Batch enrollment'),
              Text(
                'Add or remove this student from batches. Content for selected batches will become available to them.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              batches.when(
                loading: () => const LoadingRows(count: 1),
                error: (_, _) => ErrorState(
                  message: 'Couldn’t load batches.',
                  onRetry: () => ref.invalidate(staffBatchesProvider),
                ),
                data: (all) => memberships.when(
                  loading: () => const LoadingRows(count: 1),
                  error: (_, _) => ErrorState(
                    message: 'Couldn’t load enrollment.',
                    onRetry: () => ref.invalidate(
                      managedUserBatchesProvider(widget.userId),
                    ),
                  ),
                  data: (ids) => all.isEmpty
                      ? const CompactEmptyState(
                          title: 'No batches yet',
                          message: 'Create a batch in the teacher workspace.',
                          icon: Icons.groups_outlined,
                        )
                      : Column(
                          children: [
                            for (final batch in all)
                              SwitchListTile(
                                title: Text(batch.title),
                                value: ids.contains(batch.id),
                                onChanged: busy
                                    ? null
                                    : (_) => toggleBatch(
                                        batch.id,
                                        ids.contains(batch.id),
                                      ),
                              ),
                          ],
                        ),
                ),
              ),
              const SectionHeader(title: 'Progress'),
              AppRow(
                title: 'Generate report card',
                icon: Icons.assessment_outlined,
                onTap: () => context.push('/teacher/reports/${user.id}'),
              ),
            ],
          ];
        },
      ),
    );
  }
}
