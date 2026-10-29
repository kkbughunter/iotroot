import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../templates/presentation/controllers/template_controller.dart';
import '../data/workspace_models.dart';

class WorkspaceForm extends StatefulWidget {
  const WorkspaceForm({
    super.key,
    required this.controller,
    this.device,
    this.rule,
    this.topic = false,
  });
  final TemplateController controller;
  final Device? device;
  final TopicRule? rule;
  final bool topic;
  @override
  State<WorkspaceForm> createState() => _WorkspaceFormState();
}

class _WorkspaceFormState extends State<WorkspaceForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: widget.topic ? widget.rule?.name : widget.device?.name,
  );
  late final _identity = TextEditingController(
    text: widget.topic
        ? widget.rule?.topic
            .replaceFirst(RegExp(r'^/iot/(?:store/)?[0-9]+/'), '')
        : widget.device?.username,
  );
  late final _mountpoint = TextEditingController(
    text: widget.device?.mountpoint ?? '',
  );
  final _password = TextEditingController();
  late String _type = widget.rule?.topicType ?? 'STANDARD';
  late String _permission = widget.rule?.permission ?? 'publish';
  bool _saving = false;
  String? _error;
  bool get _editing => widget.device != null || widget.rule != null;
  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Enter a value.' : null;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (widget.topic) {
        await widget.controller.saveTopic({
          'topicName': _name.text.trim(),
          'topic': _identity.text.trim(),
          'topicType': _type,
          'permission': _permission,
        }, rule: widget.rule);
      } else {
        await widget.controller.saveDevice({
          'displayName': _name.text.trim(),
          'username': _identity.text.trim(),
          'mountpoint': _mountpoint.text.trim(),
          if (_password.text.isNotEmpty) 'password': _password.text,
        }, device: widget.device);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is ApiException
              ? e.message
              : 'Could not save. Please try again.';
          _saving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    for (final field in [_name, _identity, _password, _mountpoint]) {
      field.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_saving,
        child: AlertDialog(
          title: Text(
            '${_editing ? 'Edit' : 'Add'} ${widget.topic ? 'topic' : 'device'}',
          ),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Form(
                key: _form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _name,
                      enabled: !_saving,
                      maxLength: 128,
                      decoration: InputDecoration(
                        labelText: widget.topic ? 'Topic name' : 'Device name',
                      ),
                      validator: _required,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _identity,
                      enabled: !_saving,
                      decoration: InputDecoration(
                        labelText:
                            widget.topic ? 'MQTT topic path' : 'MQTT username',
                        helperText: widget.topic
                            ? 'Enter a path such as sensors/temperature.\nThe server adds your account namespace.'
                            : 'Credentials used to connect to the broker.',
                      ),
                      validator: _required,
                    ),
                    const SizedBox(height: 16),
                    if (widget.topic) ...[
                      DropdownButtonFormField<String>(
                        initialValue: _type,
                        decoration:
                            const InputDecoration(labelText: 'Topic type'),
                        items: const [
                          DropdownMenuItem(
                            value: 'STANDARD',
                            child: Text('Standard'),
                          ),
                          DropdownMenuItem(
                            value: 'STORE',
                            child: Text('Store JSON data'),
                          ),
                        ],
                        onChanged:
                            _saving ? null : (v) => setState(() => _type = v!),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _permission,
                        decoration:
                            const InputDecoration(labelText: 'Permission'),
                        items: const [
                          DropdownMenuItem(
                            value: 'publish',
                            child: Text('Publish'),
                          ),
                          DropdownMenuItem(
                            value: 'subscribe',
                            child: Text('Subscribe'),
                          ),
                          DropdownMenuItem(
                            value: 'readwrite',
                            child: Text('Publish and subscribe'),
                          ),
                        ],
                        onChanged: _saving
                            ? null
                            : (v) => setState(() => _permission = v!),
                      ),
                    ] else ...[
                      TextFormField(
                        controller: _password,
                        enabled: !_saving,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText:
                              _editing ? 'New password (optional)' : 'Password',
                          helperText: _editing
                              ? 'Leave blank to keep the current password.'
                              : null,
                        ),
                        validator: (v) => !_editing && (v == null || v.isEmpty)
                            ? 'Enter a password.'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _mountpoint,
                        enabled: !_saving,
                        decoration: const InputDecoration(
                          labelText: 'Mount point (optional)',
                        ),
                      ),
                    ],
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    if (_saving) const LinearProgressIndicator(),
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
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Save'),
            ),
          ],
        ),
      );
}
