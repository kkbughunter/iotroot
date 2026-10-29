import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../controllers/template_controller.dart';
import 'activity_page.dart';
import '../../../workspace/presentation/workspace_header.dart';
import 'live_template_page.dart';
import 'topic_dashboard_page.dart';
import 'device_list_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.controller});

  final TemplateController controller;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  TemplateController get controller => widget.controller;
  bool _prompted = false;
  bool _dialogOpen = false;

  void _promptSetup() {
    final id = controller.selectedDevice?.id;
    if (!controller.needsClientSetup ||
        controller.busy ||
        controller.loadingRules ||
        id == null ||
        _prompted ||
        _dialogOpen) {
      return;
    }
    _prompted = true;
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
      icon: Icon(Icons.monitor_heart_outlined),
      label: 'Topic details',
    ),
    NavigationDestination(
      icon: Icon(Icons.swap_vert_rounded),
      label: 'Activity',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        _promptSetup();
        return LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            final pages = <Widget>[
              controller.deviceDetailsOpen
                  ? TopicDashboardPage(controller: controller)
                  : DeviceListPage(controller: controller),
              LiveTemplatePage(controller: controller),
              ActivityPage(controller: controller),
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

class _SideNavigation extends StatelessWidget {
  const _SideNavigation({required this.controller});

  final TemplateController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: AppTheme.line)),
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
            icon: Icons.monitor_heart_outlined,
            label: 'Topic details',
            selected: controller.pageIndex == 1,
            onTap: () => controller.setPage(1),
          ),
          _NavTile(
            icon: Icons.swap_vert_rounded,
            label: 'Activity',
            selected: controller.pageIndex == 2,
            onTap: () => controller.setPage(2),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.canvas,
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
                      color: AppTheme.ink,
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
    return const Row(
      children: [
        Icon(Icons.hub_rounded, color: AppTheme.green, size: 27),
        SizedBox(width: 10),
        Flexible(
          child: Text(
            'IoTRoot',
            style: TextStyle(
              color: AppTheme.ink,
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
                      color: selected ? AppTheme.ink : AppTheme.muted,
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
