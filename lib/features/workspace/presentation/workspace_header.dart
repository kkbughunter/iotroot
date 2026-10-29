import 'package:flutter/material.dart';

import '../../templates/presentation/controllers/template_controller.dart';

class WorkspaceHeader extends StatelessWidget {
  const WorkspaceHeader({super.key, required this.controller});
  final TemplateController controller;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.home_outlined, color: Color(0xFF147D5A)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      controller.selectedDevice?.name ?? 'My home',
                      style: Theme.of(context).textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      controller.connecting
                          ? 'Connecting…'
                          : controller.connectionStatus,
                      style: TextStyle(
                        fontSize: 12,
                        color: controller.connected
                            ? Colors.green.shade700
                            : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Client settings',
                onPressed:
                    controller.busy ||
                        controller.loadingRules ||
                        controller.connecting ||
                        controller.devices.isEmpty
                    ? null
                    : () => showDialog<void>(
                        context: context,
                        builder: (_) =>
                            ConnectionDialog(controller: controller),
                      ),
                icon: const Icon(Icons.tune_rounded),
              ),
              IconButton(
                tooltip: 'Refresh devices and topics',
                onPressed: controller.busy || controller.connecting
                    ? null
                    : controller.loadWorkspace,
                icon: const Icon(Icons.refresh),
              ),
              IconButton(
                tooltip: 'Sign out',
                onPressed: controller.busy ? null : controller.logout,
                icon: const Icon(Icons.logout),
              ),
            ],
          ),
          if (controller.busy ||
              controller.loadingRules ||
              controller.connecting)
            const LinearProgressIndicator(),
          if (controller.error != null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    controller.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Dismiss error',
                  onPressed: controller.clearError,
                  icon: const Icon(Icons.close, size: 18),
                ),
              ],
            ),
        ],
      ),
    ),
  );
}

class ConnectionDialog extends StatefulWidget {
  const ConnectionDialog({super.key, required this.controller});
  final TemplateController controller;
  @override
  State<ConnectionDialog> createState() => _ConnectionDialogState();
}

class _ConnectionDialogState extends State<ConnectionDialog> {
  final _form = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _remember = true,
      _loading = true,
      _saving = false,
      _showPassword = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _loadCredentials();
  }

  Future<void> _loadCredentials() async {
    _username.text = widget.controller.clientUsername;
    _password.clear();
    try {
      final password = await widget.controller.savedPassword();
      if (mounted) _password.text = password ?? '';
    } catch (_) {
      _error = 'Saved password unavailable. Enter it again.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _connect() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final connected = await widget.controller.connect(
      _password.text,
      widget.controller.brokerSettings,
      remember: _remember,
      username: _username.text,
    );
    if (!mounted) return;
    if (connected) {
      Navigator.pop(context);
    } else {
      setState(() {
        _saving = false;
        _error = widget.controller.error ?? 'Connection failed. Try again.';
      });
    }
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: const Text('Client setup'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Choose your client and sign in once. You can change these details in Client settings.',
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<int>(
                  initialValue: widget.controller.selectedDevice?.id,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Device'),
                  items: widget.controller.devices
                      .map(
                        (d) => DropdownMenuItem(
                          value: d.id,
                          child: Text(
                            '${d.name} · ${d.clientId}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _loading || _saving
                      ? null
                      : (id) async {
                          if (id == null) return;
                          setState(() {
                            _loading = true;
                            _error = null;
                          });
                          await widget.controller.selectDevice(
                            widget.controller.devices.firstWhere(
                              (d) => d.id == id,
                            ),
                            autoConnect: false,
                          );
                          if (mounted) await _loadCredentials();
                        },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _username,
                  enabled: !_loading && !_saving,
                  decoration: const InputDecoration(labelText: 'Username'),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Enter the client username.'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _password,
                  enabled: !_loading && !_saving,
                  obscureText: !_showPassword,
                  decoration: InputDecoration(
                    labelText: 'Client password',
                    suffixIcon: IconButton(
                      tooltip: 'Show or hide client password',
                      onPressed: () =>
                          setState(() => _showPassword = !_showPassword),
                      icon: Icon(
                        _showPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ),
                  validator: (v) => v == null || v.isEmpty
                      ? 'Enter the client password.'
                      : null,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Use the MQTT password for this client.',
                  style: TextStyle(fontSize: 12),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Remember and connect automatically'),
                  subtitle: const Text(
                    'Credentials are stored securely on this device.',
                  ),
                  value: _remember,
                  onChanged: _saving
                      ? null
                      : (v) => setState(() => _remember = v ?? true),
                ),
                if (_loading || _saving) const LinearProgressIndicator(),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _loading || _saving ? null : _connect,
          child: Text(_saving ? 'Connecting…' : 'Connect'),
        ),
      ],
    ),
  );
}
