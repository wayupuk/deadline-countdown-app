import 'package:flutter/material.dart';

/// Shown when notifications are blocked. One-line text only: unbounded text measuring in a banner
/// pushed the whole layout off-screen in the Mac app.
class NotificationsOffBanner extends StatelessWidget {
  const NotificationsOffBanner({super.key, required this.onOpenSettings, this.detail = 'Turn on for daily reminders.'});

  final VoidCallback onOpenSettings;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const orange = Color(0xFFFF9F0A);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: orange.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        const Icon(Icons.notifications_off_rounded, color: orange, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Notifications are off',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelLarge),
            Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
          ]),
        ),
        TextButton(onPressed: onOpenSettings, child: const Text('Open Settings')),
      ]),
    );
  }
}
