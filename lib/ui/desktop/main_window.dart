import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/selection.dart';
import '../widgets/deadline_editor.dart';
import '../widgets/quick_add_field.dart';
import 'detail_pane.dart';
import 'month_grid.dart';
import 'sidebar.dart';

/// Calendar window: sidebar | quick add + month grid | detail. Columns drop out as the window narrows.
class MainWindow extends ConsumerStatefulWidget {
  const MainWindow({super.key, this.banner, this.onOpenSettings});

  /// Shown above the quick-add field (e.g. "Notifications are off").
  final Widget? banner;
  final VoidCallback? onOpenSettings;

  @override
  ConsumerState<MainWindow> createState() => _MainWindowState();
}

class _MainWindowState extends ConsumerState<MainWindow> {
  var _showDetail = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selection = ref.watch(calendarSelectionProvider);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true): () => showDeadlineEditor(context),
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): () => showDeadlineEditor(context),
        if (widget.onOpenSettings != null) ...{
          const SingleActivator(LogicalKeyboardKey.comma, meta: true): widget.onOpenSettings!,
          const SingleActivator(LogicalKeyboardKey.comma, control: true): widget.onOpenSettings!,
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: LayoutBuilder(builder: (context, box) {
            final sidebar = box.maxWidth >= 760;
            final detail = _showDetail && box.maxWidth >= 1080;
            return Row(children: [
              if (sidebar) ...[
                SizedBox(width: 260, child: Material(color: theme.colorScheme.surfaceContainerLow, child: const SafeArea(child: Sidebar()))),
                const VerticalDivider(width: 1),
              ],
              Expanded(
                child: SafeArea(
                  child: Column(children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
                      child: Row(children: [
                        Text('Deadlines', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                        const Spacer(),
                        IconButton(
                            tooltip: 'New deadline (⌘N)',
                            onPressed: () => showDeadlineEditor(context, day: selection.day),
                            icon: const Icon(Icons.add_rounded)),
                        IconButton(
                            tooltip: _showDetail ? 'Hide details' : 'Show details',
                            onPressed: () => setState(() => _showDetail = !_showDetail),
                            icon: Icon(_showDetail ? Icons.view_sidebar_rounded : Icons.view_sidebar_outlined)),
                        if (widget.onOpenSettings != null)
                          IconButton(tooltip: 'Settings', onPressed: widget.onOpenSettings, icon: const Icon(Icons.settings_rounded)),
                      ]),
                    ),
                    if (widget.banner != null) Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 0), child: widget.banner),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: QuickAddField(onAdded: ref.read(calendarSelectionProvider.notifier).selectDeadline),
                    ),
                    Expanded(child: MonthGrid(month: selection.month)),
                  ]),
                ),
              ),
              if (detail) ...[
                const VerticalDivider(width: 1),
                SizedBox(width: 340, child: Material(color: theme.colorScheme.surfaceContainerLowest, child: const SafeArea(child: DetailPane()))),
              ],
            ]);
          }),
        ),
      ),
    );
  }
}
