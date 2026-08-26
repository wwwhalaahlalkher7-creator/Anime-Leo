import 'package:flutter/material.dart';

class UiStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  const UiStateCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? 18 : 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: compact ? 42 : 56, color: theme.colorScheme.onSurfaceVariant),
            SizedBox(height: compact ? 10 : 16),
            Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: compact ? 17 : 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 7),
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, height: 1.5)),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(onPressed: onAction, icon: const Icon(Icons.refresh), label: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class InlineNotice extends StatelessWidget {
  final String text;
  final IconData icon;
  final bool warning;

  const InlineNotice({
    super.key,
    required this.text,
    this.icon = Icons.info_outline,
    this.warning = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = warning ? scheme.tertiary : scheme.primary;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: .22)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: color, fontSize: 12, height: 1.4))),
        ],
      ),
    );
  }
}

class LoadingGrid extends StatelessWidget {
  final int count;
  const LoadingGrid({super.key, this.count = 6});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: count,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: .52,
        crossAxisSpacing: 10,
        mainAxisSpacing: 18,
      ),
      itemBuilder: (_, __) => const _SkeletonCard(),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: DecoratedBox(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)))),
        const SizedBox(height: 8),
        FractionallySizedBox(widthFactor: .85, child: SizedBox(height: 12, child: DecoratedBox(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.all(Radius.circular(6)))))),
        const SizedBox(height: 5),
        FractionallySizedBox(widthFactor: .5, child: SizedBox(height: 10, child: DecoratedBox(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.all(Radius.circular(6)))))),
      ],
    );
  }
}
