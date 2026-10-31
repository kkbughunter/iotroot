import 'package:flutter/material.dart';

import '../../templates/presentation/controllers/template_controller.dart';
import '../../workspace/data/workspace_models.dart';
import '../../workspace/presentation/workspace_header.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.controller});
  final TemplateController controller;

  Future<void> _selectClient(Device? device) async {
    if (device == null || device.id == controller.selectedDevice?.id) return;
    await controller.selectDevice(device);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      key: const PageStorageKey<String>('settings'),
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
      children: [
        Text('Settings', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 6),
        Text(
          'Manage clients, appearance, and your account.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        _SettingsCard(
          title: 'Client',
          icon: Icons.devices_other_rounded,
          children: [
            DropdownButtonFormField<Device>(
              key: ValueKey('client-${controller.selectedDevice?.id}'),
              initialValue: controller.selectedDevice,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Active client',
                border: OutlineInputBorder(),
              ),
              items: controller.devices
                  .map(
                    (device) => DropdownMenuItem(
                      value: device,
                      child: Text(
                        '${device.name}  •  ${device.clientId}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: controller.busy || controller.loadingRules
                  ? null
                  : _selectClient,
            ),
            const SizedBox(height: 12),
            if (controller.selectedDevice != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  controller.connected
                      ? Icons.cloud_done_outlined
                      : Icons.cloud_off_outlined,
                ),
                title: Text(controller.clientUsername),
                subtitle: Text(
                  controller.connected
                      ? 'Connected to ${controller.brokerSettings.host}'
                      : controller.connectionStatus,
                ),
                trailing: FilledButton.tonalIcon(
                  onPressed: controller.connecting
                      ? null
                      : () => showDialog<void>(
                          context: context,
                          builder: (_) =>
                              ConnectionDialog(controller: controller),
                        ),
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('Configure'),
                ),
              ),
          ],
        ),
        // const SizedBox(height: 16),
        // _SettingsCard(
        //   title: 'Appearance',
        //   icon: Icons.palette_outlined,
        //   children: [
        //     SwitchListTile(
        //       contentPadding: EdgeInsets.zero,
        //       title: const Text('Dark theme'),
        //       subtitle: const Text(
        //         'Use a darker color scheme throughout the app.',
        //       ),
        //       value: controller.themeMode == ThemeMode.dark,
        //       onChanged: controller.setDarkMode,
        //     ),
        //   ],
        // ),
        const SizedBox(height: 16),
        _SettingsCard(
          title: 'Account',
          icon: Icons.account_circle_outlined,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.alternate_email_rounded),
              title: Text(controller.api.email),
              subtitle: Text(controller.api.baseUrl),
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              textColor: theme.colorScheme.error,
              iconColor: theme.colorScheme.error,
              leading: const Icon(Icons.logout_rounded),
              title: const Text('Log out'),
              subtitle: const Text('Sign out of this account on this device.'),
              onTap: controller.busy ? null : controller.logout,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SettingsCard(
          title: 'Home screen widget',
          icon: Icons.widgets_outlined,
          children: [
            Text(
              'Create one card with a name and power buttons for multiple topics.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed:
                    controller.connected &&
                        controller.homeWidgetRules.isNotEmpty &&
                        !controller.addingHomeWidget
                    ? controller.addHomeWidget
                    : null,
                icon: controller.addingHomeWidget
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_to_home_screen_rounded),
                label: Text(
                  controller.addingHomeWidget
                      ? 'Opening widget picker…'
                      : 'Add widget',
                ),
              ),
            ),
            if (!controller.connected) ...[
              const SizedBox(height: 10),
              Text(
                'Connect this client and remember its MQTT password first.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.title,
    required this.icon,
    required this.children,
  });
  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    ),
  );
}
