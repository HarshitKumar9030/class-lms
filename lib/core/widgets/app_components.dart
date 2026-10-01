import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.title,
    required this.children,
    this.trailing,
    this.onRefresh,
  });
  final String title;
  final List<Widget> children;
  final Widget? trailing;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final content = CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          title: Text(title, style: Theme.of(context).textTheme.titleLarge),
          actions: trailing == null ? null : [trailing!],
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            12,
            AppSpacing.page,
            40,
          ),
          sliver: SliverList.list(children: children),
        ),
      ],
    );
    return Scaffold(
      body: SafeArea(
        child: onRefresh == null
            ? content
            : RefreshIndicator(onRefresh: onRefresh!, child: content),
      ),
    );
  }
}

class AppSurface extends StatelessWidget {
  const AppSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: context.palette.surface,
    borderRadius: BorderRadius.circular(AppRadius.large),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(padding: padding, child: child),
    ),
  );
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.action,
    this.onAction,
  });
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(
      top: AppSpacing.section,
      bottom: AppSpacing.md,
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        if (action != null)
          TextButton(onPressed: onAction, child: Text(action!)),
      ],
    ),
  );
}

class AppRow extends StatelessWidget {
  const AppRow({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
    this.onTap,
  });
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: AppSurface(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      onTap: onTap,
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 22, color: context.palette.accent),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
          trailing ??
              (onTap == null
                  ? const SizedBox.shrink()
                  : Icon(
                      Icons.chevron_right_rounded,
                      color: context.palette.secondary,
                    )),
        ],
      ),
    ),
  );
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 54,
    child: FilledButton(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: context.palette.accent,
        foregroundColor: Theme.of(context).brightness == Brightness.dark
            ? Colors.black
            : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
        elevation: 0,
      ),
      child: busy
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label),
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
  });
  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 12),
    child: Column(
      children: [
        Icon(icon, size: 32, color: context.palette.secondary),
        const SizedBox(height: 16),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          message,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: context.palette.secondary),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

class CompactEmptyState extends StatelessWidget {
  const CompactEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
  });
  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) => AppSurface(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 24, color: context.palette.secondary),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 3),
              Text(message, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    ),
  );
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      EmptyState(
        title: 'Couldn’t load this',
        message: message,
        icon: Icons.wifi_off_rounded,
      ),
      TextButton(onPressed: onRetry, child: const Text('Try again')),
    ],
  );
}

class LoadingRows extends StatelessWidget {
  const LoadingRows({super.key, this.count = 3});
  final int count;

  @override
  Widget build(BuildContext context) => Column(
    children: List.generate(
      count,
      (index) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          height: 76,
          decoration: BoxDecoration(
            color: context.palette.muted,
            borderRadius: BorderRadius.circular(AppRadius.large),
          ),
        ),
      ),
    ),
  );
}
