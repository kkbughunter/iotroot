import 'package:flutter/material.dart';

import '../../../workspace/presentation/workspace_forms.dart';
import '../controllers/template_controller.dart';

class DeviceListPage extends StatelessWidget {
  const DeviceListPage({super.key, required this.controller});
  final TemplateController controller;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              'My devices',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          IconButton(
            tooltip: 'Add device',
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => WorkspaceForm(controller: controller),
            ),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      const Text('Open a device to view its topics, controls and stored data.'),
      const SizedBox(height: 16),
      if (controller.devices.isEmpty && !controller.busy)
        const Text('No devices yet. Add your first device to get started.'),
      for (final device in controller.devices)
        Card(
          key: ValueKey('device-card:${device.id}'),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: const Icon(Icons.router_outlined),
            title: Text(device.name),
            subtitle: Text(device.clientId),
            trailing: const Icon(Icons.chevron_right),
            onTap: controller.loadingRules || controller.busy
                ? null
                : () => controller.openDevice(device),
          ),
        ),
    ],
  );
}
