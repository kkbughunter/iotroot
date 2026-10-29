import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../../core/api_client.dart';
import '../../../workspace/data/broker_service.dart';
import '../../../workspace/data/workspace_models.dart';
import '../../data/template_repository.dart';
import '../../domain/entities/iot_template.dart';

class TemplateController extends ChangeNotifier {
  TemplateController(
    TemplateRepository repository, {
    ApiClient? api,
    BrokerConnection? broker,
  }) : api = api ?? ApiClient(),
       broker = broker ?? MqttBrokerConnection() {
    templates = repository.getAll();
    selectedTemplate = templates.first;
    _resetControls();
    this.api.onSessionExpired = () {
      _resetWorkspace();
      error = 'Session expired. Please sign in again.';
      _notify();
    };
    this.broker.onStatus = (status) {
      connectionStatus = status;
      _notify();
    };
    this.broker.onMessage = _receive;
  }

  final ApiClient api;
  final BrokerConnection broker;
  late final List<IotTemplate> templates;
  late IotTemplate selectedTemplate;
  bool initializing = true,
      busy = false,
      loadingRules = false,
      connecting = false,
      sending = false;
  bool loadingHistory = false;
  bool needsClientSetup = false;
  int _deviceSelection = 0, _connection = 0;
  final Map<String, Map<String, Object>> _topicControls = {};
  String? error, historyError;
  String connectionStatus = 'Disconnected';
  int pageIndex = 0;
  bool deviceDetailsOpen = false;
  TemplateCategory? categoryFilter;
  List<Device> devices = [];
  List<TopicRule> rules = [];
  Map<int, Map<String, dynamic>> statuses = {};
  Device? selectedDevice;
  TopicRule? selectedRule;
  String publishTopic = '';
  final Map<String, Object> controlValues = {};
  final Map<String, List<TelemetryPoint>> metricHistory = {};
  final List<TemplateEvent> events = [];
  final Map<int, List<BrokerMessage>> _readings = {};
  Map<String, dynamic> _preferences = {};
  List<Map<String, dynamic>> storedMessages = [];
  int storedTotal = 0, _storedPage = 0, _storedPages = 0;
  DateTime? _historyTo;
  int _selection = 0, _workspace = 0;
  bool _disposed = false;
  Future<void> _preferenceWrite = Future.value();

  bool get authenticated => api.authenticated;
  bool get connected =>
      connectionStatus == 'Connected' ||
      connectionStatus.startsWith('Subscription rejected:');
  bool get canSend =>
      connected &&
      !sending &&
      !connecting &&
      selectedRule?.canPublish == true &&
      matchesTopic(selectedRule!.topic, publishTopic);
  bool get hasMoreHistory => _storedPage < _storedPages;
  String get topic => selectedRule?.topic ?? 'Select a topic';
  BrokerMessage? get latestMessage =>
      (_readings[selectedRule?.id] ?? []).lastOrNull;
  List<IotTemplate> get filteredTemplates => categoryFilter == null
      ? templates
      : templates.where((t) => t.category == categoryFilter).toList();
  String get _settingsKey => 'iotroot.preferences.${api.accountKey}';
  String get _ruleKey => '${selectedDevice?.id}:${selectedRule?.id}';
  String get _passwordKey =>
      'iotroot.mqtt.${api.accountKey}.${selectedDevice?.id}';

  Future<void> initialize() async {
    try {
      if (await api.restore()) await loadWorkspace();
    } catch (e) {
      error = _message(e);
    } finally {
      initializing = false;
      _notify();
    }
  }

  Future<void> login(String url, String email, String password) async {
    busy = true;
    error = null;
    _notify();
    try {
      await api.login(url, email, password);
      await loadWorkspace();
    } catch (e) {
      error = _message(e);
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> logout() async {
    _resetWorkspace();
    error = null;
    busy = true;
    _notify();
    try {
      await api.logout();
    } catch (e) {
      error = _message(e);
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> loadWorkspace() async {
    final generation = ++_workspace;
    busy = true;
    error = null;
    _notify();
    try {
      final data = await api.request('/api/devices');
      if (generation != _workspace || _disposed) return;
      devices = (data as List)
          .map((d) => Device.fromJson(Map<String, dynamic>.from(d as Map)))
          .toList();
      final saved = await api.store.read(_settingsKey);
      if (generation != _workspace || _disposed) return;
      _preferences = saved == null
          ? {}
          : Map<String, dynamic>.from(jsonDecode(saved) as Map);
      try {
        final data =
            await api.request('/api/devices/connection-status') as List;
        if (generation != _workspace || _disposed) return;
        statuses = {
          for (final item in data)
            (item['deviceId'] as num).toInt(): Map<String, dynamic>.from(
              item as Map,
            ),
        };
      } on ApiException catch (e) {
        if (!authenticated) rethrow;
        error =
            'Devices loaded, but broker details are unavailable: ${e.message}';
      }
      if (generation != _workspace || _disposed) return;
      final device =
          devices
              .where(
                (d) =>
                    d.id ==
                    (selectedDevice?.id ?? _preferences['selectedDevice']),
              )
              .firstOrNull ??
          devices.firstOrNull;
      if (device != null) {
        await selectDevice(device);
      } else {
        disconnect();
        selectedDevice = null;
        selectedRule = null;
        rules = [];
      }
    } catch (e) {
      if (generation == _workspace) error = _message(e);
    } finally {
      if (generation == _workspace) {
        busy = false;
        _notify();
      }
    }
  }

  Future<void> selectDevice(Device device, {bool autoConnect = true}) async {
    disconnect();
    final selection = ++_deviceSelection;
    _selection++;
    needsClientSetup = false;
    selectedDevice = device;
    loadingHistory = false;
    storedTotal = 0;
    _storedPage = 0;
    _storedPages = 0;
    selectedRule = null;
    sending = false;
    rules = [];
    _readings.clear();
    metricHistory.clear();
    storedMessages = [];
    historyError = null;
    loadingRules = true;
    _notify();
    try {
      final data = await api.request('/api/devices/${device.id}/rules') as List;
      if (selection != _deviceSelection || _disposed) return;
      rules = data
          .map((r) => TopicRule.fromJson(Map<String, dynamic>.from(r as Map)))
          .toList();
      if (rules.isNotEmpty) selectRule(rules.first);
      _preferences['selectedDevice'] = device.id;
      await _savePreferences();
      if (selection != _deviceSelection || _disposed) return;
      final password = await savedPassword();
      if (selection != _deviceSelection || _disposed) return;
      needsClientSetup = password == null;
      loadingRules = false;
      if (autoConnect && password != null) {
        await connect(password, brokerSettings);
      }
    } catch (e) {
      if (selection == _deviceSelection) error = _message(e);
    } finally {
      if (selection == _deviceSelection) {
        loadingRules = false;
        _notify();
      }
    }
  }

  void selectRule(TopicRule rule) {
    _selection++;
    loadingRules = false;
    selectedRule = rule;
    final pref = _rulePreferences;
    selectedTemplate = templateFor(rule);
    publishTopic =
        pref['publishTopic'] as String? ?? (rule.wildcard ? '' : rule.topic);
    _restoreControls();
    _rebuildMetrics();
    storedMessages = [];
    storedTotal = 0;
    _storedPage = 0;
    _storedPages = 0;
    loadingHistory = false;
    historyError = null;
    _notify();
    if (rule.isStored) unawaited(loadHistory());
  }

  Map<String, dynamic> get _rulePreferences =>
      Map<String, dynamic>.from((_preferences[_ruleKey] as Map?) ?? {});
  String metricKey(TemplateMetric metric) =>
      (_rulePreferences['metrics'] as Map?)?[metric.id] as String? ?? metric.id;
  Future<void> _saveRule(Map<String, dynamic> values) async {
    if (selectedRule == null) return;
    _preferences[_ruleKey] = {..._rulePreferences, ...values};
    await _savePreferences();
  }

  Future<void> _savePreferences() async {
    final key = _settingsKey;
    final value = jsonEncode(_preferences);
    _preferenceWrite = _preferenceWrite
        .then((_) => api.store.write(key, value))
        .catchError((Object e) {
          error = 'Could not save settings on this device.';
          _notify();
        });
    await _preferenceWrite;
  }

  void setMetricKey(TemplateMetric metric, String key) {
    unawaited(
      _saveRule({
        'metrics': {
          ...?_rulePreferences['metrics'] as Map?,
          metric.id: key.trim(),
        },
      }),
    );
    _rebuildMetrics();
    _notify();
  }

  void setPublishTopic(String value) {
    publishTopic = value.trim();
    unawaited(_saveRule({'publishTopic': publishTopic}));
    _notify();
  }

  Future<void> openDevice(Device device) async {
    deviceDetailsOpen = true;
    pageIndex = 0;
    if (selectedDevice?.id != device.id) {
      await selectDevice(device);
    }
    _notify();
  }

  void showDevices() {
    deviceDetailsOpen = false;
    pageIndex = 0;
    _notify();
  }

  Future<void> saveDevice(
    Map<String, dynamic> payload, {
    Device? device,
  }) async {
    final generation = _workspace;
    final data = await api.request(
      device == null ? '/api/devices' : '/api/devices/${device.id}',
      method: device == null ? 'POST' : 'PUT',
      body: payload,
    );
    if (generation != _workspace || _disposed) return;
    final saved = Device.fromJson(Map<String, dynamic>.from(data as Map));
    devices = [...devices.where((d) => d.id != saved.id), saved];
    if (selectedDevice?.id == saved.id) selectedDevice = saved;
    if (device != null &&
        (device.username != saved.username ||
            payload.containsKey('password'))) {
      _preferences['client:${saved.id}'] = {'username': saved.username};
      if (selectedDevice?.id == saved.id) {
        disconnect();
        needsClientSetup = true;
      }
      if (payload.containsKey('password')) {
        await api.store.delete('iotroot.mqtt.${api.accountKey}.${saved.id}');
      }
      await _savePreferences();
    }
    _notify();
  }

  Future<void> saveTopic(
    Map<String, dynamic> payload, {
    TopicRule? rule,
  }) async {
    final device = selectedDevice;
    if (device == null) throw StateError('Choose a device first.');
    final selection = _deviceSelection;
    final data = await api.request(
      '/api/devices/${device.id}/rules${rule == null ? '' : '/${rule.id}'}',
      method: rule == null ? 'POST' : 'PUT',
      body: payload,
    );
    if (selection != _deviceSelection || _disposed) return;
    final saved = TopicRule.fromJson(Map<String, dynamic>.from(data as Map));
    rules = [...rules.where((r) => r.id != saved.id), saved];
    if (selectedRule?.id == saved.id || selectedRule == null) selectRule(saved);
    // Reconnect with the new subscriptions when credentials are available.
    final password = await savedPassword();
    if (selection != _deviceSelection || _disposed) return;
    if (connected &&
        (rule == null ||
            rule.topic != saved.topic ||
            rule.permission != saved.permission)) {
      disconnect();
      if (password != null) await connect(password, brokerSettings);
    }
    _notify();
  }

  void setPage(int value) {
    pageIndex = value;
    _notify();
  }

  void setCategory(TemplateCategory? value) {
    categoryFilter = value;
    _notify();
  }

  void selectTemplate(IotTemplate template, {bool notify = true}) {
    selectedTemplate = template;
    _topicControls.remove(_ruleKey);
    _resetControls();
    _rebuildMetrics();
    pageIndex = 1;
    unawaited(_saveRule({'template': template.id}));
    if (notify) _notify();
  }

  void updateControl(TemplateControl control, Object value) {
    controlValues[control.id] = value;
    _topicControls[_ruleKey] = Map.of(controlValues);
    _notify();
  }

  Map<String, Object> get commandPayload => {
    for (final control in selectedTemplate.controls)
      control.jsonKey: _serialize(control, controlValues[control.id]!),
  };
  Object _serialize(TemplateControl control, Object value) {
    if (control.type == ControlType.toggle &&
        ['command', 'status'].contains(control.jsonKey)) {
      return (value as bool) ? 'on' : 'off';
    }
    if (control.type == ControlType.range) return (value as double).round();
    if (control.jsonKey == 'interval_sec') {
      return int.parse((value as String).split(' ').first);
    }
    return value;
  }

  Map<String, dynamic> preferencesFor(TopicRule rule) =>
      Map<String, dynamic>.from(
        (_preferences['${selectedDevice?.id}:${rule.id}'] as Map?) ?? {},
      );

  bool hasTemplate(TopicRule rule) => preferencesFor(rule)['template'] != null;
  IotTemplate templateFor(TopicRule rule) =>
      templates
          .where((t) => t.id == preferencesFor(rule)['template'])
          .firstOrNull ??
      templates.first;
  BrokerMessage? latestFor(TopicRule rule) => _readings[rule.id]?.lastOrNull;
  Map<String, Object> controlsFor(TopicRule rule) => _topicControls.putIfAbsent(
    '${selectedDevice?.id}:${rule.id}',
    () => {for (final c in templateFor(rule).controls) c.id: c.defaultValue},
  );
  void updateTopicControl(
    TopicRule rule,
    TemplateControl control,
    Object value,
  ) {
    controlsFor(rule)[control.id] = value;
    if (selectedRule?.id == rule.id) controlValues[control.id] = value;
    _notify();
  }

  String destinationFor(TopicRule rule) =>
      preferencesFor(rule)['publishTopic'] as String? ??
      (rule.wildcard ? '' : rule.topic);
  bool canSendTopic(TopicRule rule) =>
      connected &&
      !sending &&
      !connecting &&
      rules.contains(rule) &&
      rule.canPublish &&
      matchesTopic(rule.topic, destinationFor(rule));
  void openTopic(TopicRule rule) {
    deviceDetailsOpen = true;
    selectRule(rule);
    pageIndex = 1;
    _notify();
  }

  void _restoreControls() {
    controlValues
      ..clear()
      ..addAll(controlsFor(selectedRule!));
  }

  BrokerSettings get brokerSettings {
    final status = statuses[selectedDevice?.id];
    return BrokerSettings(
      host: status?['brokerHost'] as String? ?? Uri.parse(api.baseUrl).host,
      port: (status?['brokerPort'] as num?)?.toInt() ?? 1883,
      tls: status?['brokerPort'] == 8883,
    );
  }

  String get clientUsername =>
      (_preferences['client:${selectedDevice?.id}'] as Map?)?['username']
          as String? ??
      selectedDevice?.username ??
      '';
  Future<String?> savedPassword() => api.store.read(_passwordKey);

  Future<bool> connect(
    String password,
    BrokerSettings settings, {
    bool remember = true,
    String? username,
  }) async {
    final device = selectedDevice;
    if (device == null || connecting) return false;
    final generation = _workspace;
    final connection = ++_connection;
    connecting = true;
    error = null;
    _notify();
    final passwordKey = _passwordKey;
    final mqttUsername = username?.trim() ?? clientUsername;
    try {
      await broker.connect(
        Device(
          id: device.id,
          clientId: device.clientId,
          username: mqttUsername,
          mountpoint: device.mountpoint,
        ),
        password,
        settings,
        rules,
      );
      if (connection != _connection || generation != _workspace || _disposed) {
        return false;
      }
      if (remember) {
        await api.store.write(passwordKey, password);
      } else {
        await api.store.delete(passwordKey);
      }
      if (connection != _connection || generation != _workspace || _disposed) {
        return false;
      }
      _preferences['client:${device.id}'] = {'username': mqttUsername};
      _preferences['selectedDevice'] = device.id;
      needsClientSetup = false;
      await _savePreferences();
      return true;
    } catch (e) {
      if (connection == _connection && generation == _workspace) {
        error = _message(e);
      }
      return false;
    } finally {
      if (connection == _connection && generation == _workspace) {
        connecting = false;
        _notify();
      }
    }
  }

  void disconnect() {
    _connection++;
    broker.disconnect();
    connectionStatus = 'Disconnected';
    connecting = false;
    _notify();
  }

  Future<bool> sendCommand({String? rawPayload}) async {
    final rule = selectedRule;
    if (rule == null) return false;
    return sendTopicCommand(rule, rawPayload: rawPayload);
  }

  Future<bool> sendTopicCommand(TopicRule rule, {String? rawPayload}) async {
    if (!canSendTopic(rule)) {
      error = 'Connect and choose an allowed publish topic first.';
      _notify();
      return false;
    }
    final generation = _workspace;
    final deviceSelection = _deviceSelection;
    final destination = destinationFor(rule);
    final template = templateFor(rule);
    final templateName = template.name;
    final payload =
        rawPayload ??
        jsonEncode({
          for (final control in template.controls)
            control.jsonKey: _serialize(
              control,
              controlsFor(rule)[control.id]!,
            ),
        });
    sending = true;
    error = null;
    _notify();
    try {
      await broker.publish(destination, payload);
      if (generation != _workspace ||
          deviceSelection != _deviceSelection ||
          _disposed) {
        return false;
      }
      _addEvent(
        TemplateEvent(
          direction: EventDirection.sent,
          templateName: templateName,
          topic: destination,
          payload: _decode(payload),
          time: DateTime.now(),
        ),
      );
      return true;
    } catch (e) {
      if (generation == _workspace && deviceSelection == _deviceSelection) {
        error = _message(e);
      }
      return false;
    } finally {
      if (generation == _workspace && deviceSelection == _deviceSelection) {
        sending = false;
        _notify();
      }
    }
  }

  void _receive(BrokerMessage message) {
    final matching = rules
        .where((r) => r.canSubscribe && matchesTopic(r.topic, message.topic))
        .toList();
    if (matching.isEmpty) return;
    for (final rule in matching) {
      final readings = _readings.putIfAbsent(rule.id, () => []);
      readings.add(message);
      if (readings.length > 200) readings.removeAt(0);
    }
    _addEvent(
      TemplateEvent(
        direction: EventDirection.received,
        templateName: selectedDevice?.username ?? 'Device',
        topic: message.topic,
        payload: _decode(message.payload),
        time: message.time,
      ),
    );
    _rebuildMetrics();
    _notify();
  }

  Object? _decode(String payload) {
    try {
      return jsonDecode(payload);
    } on FormatException {
      return payload;
    }
  }

  void _addEvent(TemplateEvent event) {
    events.insert(0, event);
    if (events.length > 300) events.removeLast();
  }

  void _resetControls() {
    controlValues
      ..clear()
      ..addEntries(
        selectedTemplate.controls.map((c) => MapEntry(c.id, c.defaultValue)),
      );
  }

  void _rebuildMetrics() {
    metricHistory.clear();
    for (final metric in selectedTemplate.metrics) {
      final points = <TelemetryPoint>[];
      for (final reading in _readings[selectedRule?.id] ?? <BrokerMessage>[]) {
        dynamic value = _decode(reading.payload);
        final key = metricKey(metric);
        if (key.isNotEmpty) {
          for (final part in key.split('.')) {
            value = value is Map ? value[part] : null;
          }
        }
        final number = value is num
            ? value.toDouble()
            : value is String
            ? double.tryParse(value)
            : null;
        if (number != null && number.isFinite) {
          points.add(TelemetryPoint(reading.time, number));
        }
      }
      metricHistory[metric.id] = points;
    }
  }

  double? latestMetricValue(TemplateMetric metric) =>
      metricHistory[metric.id]?.lastOrNull?.value;
  void clearEvents() {
    events.clear();
    _notify();
  }

  void clearError() {
    error = null;
    _notify();
  }

  Future<void> loadHistory({bool more = false}) async {
    final rule = selectedRule;
    if (selectedDevice == null ||
        rule == null ||
        !rule.isStored ||
        loadingHistory) {
      return;
    }
    final selection = _selection;
    final generation = _workspace;
    loadingHistory = true;
    historyError = null;
    if (!more) {
      _storedPage = 0;
      _historyTo = DateTime.now().toUtc();
    }
    _notify();
    try {
      final data = await api.request(
        '/api/store/messages',
        query: {
          'deviceId': '${selectedDevice!.id}',
          if (!rule.wildcard) 'topic': rule.topic,
          if (rule.wildcard)
            'topicPrefix': rule.topic.split(RegExp(r'[+#]')).first,
          'page': '$_storedPage',
          'size': '200',
          'from': _historyTo!
              .subtract(const Duration(hours: 1))
              .toIso8601String(),
          'to': _historyTo!.toIso8601String(),
        },
      ) as Map;
      if (selection != _selection || generation != _workspace || _disposed) {
        return;
      }
      final rows = (data['content'] as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .where((r) => matchesTopic(rule.topic, r['topic'] as String? ?? ''))
          .toList();
      storedMessages = more ? [...storedMessages, ...rows] : rows;
      storedTotal = (data['totalElements'] as num).toInt();
      _storedPages = (data['totalPages'] as num).toInt();
      _storedPage++;
    } catch (e) {
      if (selection == _selection && generation == _workspace) {
        historyError = _message(e);
      }
    } finally {
      if (selection == _selection && generation == _workspace) {
        loadingHistory = false;
        _notify();
      }
    }
  }

  void _resetWorkspace() {
    _workspace++;
    _selection++;
    _deviceSelection++;
    _connection++;
    broker.disconnect();
    connectionStatus = 'Disconnected';
    devices = [];
    rules = [];
    statuses = {};
    selectedDevice = null;
    selectedRule = null;
    _readings.clear();
    metricHistory.clear();
    events.clear();
    _preferences = {};
    _topicControls.clear();
    needsClientSetup = false;
    storedMessages = [];
    pageIndex = 0;
    deviceDetailsOpen = false;
    busy = false;
    connecting = false;
    sending = false;
    loadingRules = false;
    loadingHistory = false;
  }

  String _message(Object error) => error is ApiException
      ? error.message
      : error is StateError
      ? error.message
      : 'Something went wrong. Please try again.';
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _workspace++;
    _selection++;
    _deviceSelection++;
    _connection++;
    broker.disconnect();
    api.dispose();
    super.dispose();
  }
}
