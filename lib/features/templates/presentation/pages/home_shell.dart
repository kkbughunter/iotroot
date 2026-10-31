import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../controllers/template_controller.dart';
import '../../../settings/presentation/settings_page.dart';
import 'activity_page.dart';
import '../../../workspace/presentation/workspace_header.dart';
import 'topic_dashboard_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.controller});

  final TemplateController controller;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  TemplateController get controller => widget.controller;
  int? _promptedDeviceId;
  bool _dialogOpen = false;

  void _promptSetup() {
    final id = controller.selectedDevice?.id;
    if (!controller.needsClientSetup ||
        controller.busy ||
        controller.loadingRules ||
        id == null ||
        _promptedDeviceId == id ||
        _dialogOpen) {
      return;
    }
    _promptedDeviceId = id;
    _dialogOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => ConnectionDialog(controller: controller),
      );
      if (mounted) setState(() => _dialogOpen = false);
    });
  }

  static const _destinations = <NavigationDestination>[
    NavigationDestination(
      icon: Icon(Icons.grid_view_rounded),
      label: 'My home',
    ),
    NavigationDestination(
      icon: Icon(Icons.swap_vert_rounded),
      label: 'Activity',
    ),
    NavigationDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings_rounded),
      label: 'Settings',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        _promptSetup();
        if (controller.reconnecting) {
          return const Scaffold(
            body: SafeArea(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 18),
                    Text('Reconnecting to your device…'),
                  ],
                ),
              ),
            ),
          );
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            final pages = <Widget>[
              controller.connected && !controller.connecting
                  ? TopicDashboardPage(controller: controller)
                  : _HomeConnectionGate(controller: controller),
              ActivityPage(controller: controller),
              SettingsPage(controller: controller),
            ];

            return Scaffold(
              body: SafeArea(
                child: Column(
                  children: [
                    WorkspaceHeader(controller: controller),
                    Expanded(
                      child: Row(
                        children: [
                          if (wide) _SideNavigation(controller: controller),
                          Expanded(
                            child: IndexedStack(
                              index: controller.pageIndex,
                              children: pages,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              bottomNavigationBar: wide
                  ? null
                  : NavigationBar(
                      selectedIndex: controller.pageIndex,
                      onDestinationSelected: controller.setPage,
                      destinations: _destinations,
                    ),
            );
          },
        );
      },
    );
  }
}

class _HomeConnectionGate extends StatelessWidget {
  const _HomeConnectionGate({required this.controller});

  final TemplateController controller;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (controller.connecting) ...[
            const CircularProgressIndicator(),
            const SizedBox(height: 18),
            Text(
              controller.connected
                  ? 'Loading retained topic state…'
                  : 'Connecting to your device…',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ] else ...[
            const Icon(
              Icons.cloud_off_rounded,
              size: 42,
              color: AppTheme.muted,
            ),
            const SizedBox(height: 12),
            Text(
              'Connect your device to load the home controls.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ],
      ),
    ),
  );
}

class _SideNavigation extends StatelessWidget {
  const _SideNavigation({required this.controller});

  final TemplateController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          right: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(18, 26, 18, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: _Brand(),
          ),
          const SizedBox(height: 38),
          _NavTile(
            icon: Icons.grid_view_rounded,
            label: 'My home',
            selected: controller.pageIndex == 0,
            onTap: () => controller.setPage(0),
          ),
          _NavTile(
            icon: Icons.swap_vert_rounded,
            label: 'Activity',
            selected: controller.pageIndex == 1,
            onTap: () => controller.setPage(1),
          ),
          _NavTile(
            icon: Icons.settings_outlined,
            label: 'Settings',
            selected: controller.pageIndex == 2,
            onTap: () => controller.setPage(2),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                _PulseDot(connected: controller.connected),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    controller.connectionStatus,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.hub_rounded, color: AppTheme.green, size: 27),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            'IoTRoot',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _PulseDot extends StatelessWidget {
  const _PulseDot({required this.connected});
  final bool connected;

  @override
  Widget build(BuildContext context) => Container(
    width: 9,
    height: 9,
    decoration: BoxDecoration(
      color: connected ? const Color(0xFF28A474) : Colors.grey,
      shape: BoxShape.circle,
    ),
  );
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Material(
        color: selected ? const Color(0xFFE7F3ED) : Colors.transparent,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 21,
                  color: selected ? AppTheme.green : AppTheme.muted,
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: selected
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
