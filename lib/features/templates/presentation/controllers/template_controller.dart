import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;

import '../../../../core/api_client.dart';
import '../../../workspace/data/broker_service.dart';
import '../../../workspace/data/workspace_models.dart';
import '../../data/template_repository.dart';
import '../../domain/entities/iot_template.dart';

enum TopicControlType { switchControl, fan, thermometer }

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
      loadingHistory = false;
  bool storedDeviceOnly = false;
  bool needsClientSetup = false;
  int _deviceSelection = 0, _connection = 0;
  final Map<String, Map<String, Object>> _topicControls = {};
  String? error, historyError;
  String connectionStatus = 'Disconnected';
  int pageIndex = 0;
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
  final Map<int, bool> _topicPower = {};
  final Map<int, int> _topicRanges = {};
  final Set<int> _sendingTopicIds = {};
  // Newest stored message per stored topic, shown on the home cards.
  final Map<int, Map<String, dynamic>> _latestStored = {};
  Map<String, dynamic> _preferences = {};
  List<Map<String, dynamic>> storedMessages = [];
  int storedTotal = 0, _storedPage = 0, _storedPages = 0;
  DateTime? _historyTo;
  int _selection = 0, _workspace = 0;
  bool _disposed = false;
  Future<void> _preferenceWrite = Future.value();

  bool get authenticated => api.authenticated;
  ThemeMode get themeMode =>
      _preferences['darkMode'] == true ? ThemeMode.dark : ThemeMode.light;
  bool get connected =>
      connectionStatus == 'Connected' ||
      connectionStatus.startsWith('Subscription rejected:');
  bool get reconnecting => connectionStatus == 'Reconnecting';
  bool get sending => _sendingTopicIds.isNotEmpty;
  bool get canSend {
    final rule = selectedRule;
    return rule != null && canSendTopic(rule);
  }

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
      final all = (data as List)
          .map((d) => Device.fromJson(Map<String, dynamic>.from(d as Map)))
          .toList();
      final saved = await api.store.read(_settingsKey);
      if (generation != _workspace || _disposed) return;
      _preferences = saved == null
          ? {}
          : Map<String, dynamic>.from(jsonDecode(saved) as Map);
      devices = all;
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
      final savedDeviceId = _preferences['selectedDevice'];
      final accountEmail = api.email.trim().toLowerCase();
      final device =
          devices.where((device) => device.id == savedDeviceId).firstOrNull ??
          devices
              .where(
                (device) =>
                    device.username.trim().toLowerCase() == accountEmail,
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
    _sendingTopicIds.clear();
    rules = [];
    _readings.clear();
    _topicPower.clear();
    _topicRanges.clear();
    _latestStored.clear();
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
      unawaited(refreshLatestStored());
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
    storedDeviceOnly = false;
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

  void setPage(int value) {
    pageIndex = value;
    _notify();
  }

  void setDarkMode(bool enabled) {
    _preferences['darkMode'] = enabled;
    unawaited(_savePreferences());
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
  bool powerFor(TopicRule rule) {
    if (_topicPower.containsKey(rule.id)) return _topicPower[rule.id]!;
    final live = latestFor(rule);
    final stored = latestStoredFor(rule);
    for (final payload in [
      if (live != null) _decode(live.payload),
      if (stored != null) stored['payload'],
    ]) {
      if (payload is Map && payload['power'] is bool) {
        return payload['power'] as bool;
      }
      if (payload is Map && payload['status'] != null) {
        final status = payload['status'].toString().toLowerCase();
        if (status == 'on' || status == 'true') return true;
        if (status == 'off' || status == 'false') return false;
      }
    }
    return _topicPower[rule.id] ?? false;
  }

  Future<bool> setTopicPower(TopicRule rule, bool value) async {
    final sent = await sendTopicCommand(
      rule,
      rawPayload: jsonEncode({'status': value ? 'on' : 'off'}),
    );
    if (sent) {
      _topicPower[rule.id] = value;
      _notify();
    }
    return sent;
  }

  TopicControlType controlTypeFor(TopicRule rule) =>
      switch (preferencesFor(rule)['controlType']) {
        'fan' => TopicControlType.fan,
        'thermometer' => TopicControlType.thermometer,
        _ => TopicControlType.switchControl,
      };

  double thermometerValueFor(TopicRule rule, String key) {
    final live = latestFor(rule);
    final stored = latestStoredFor(rule);
    final payload = live != null ? _decode(live.payload) : stored?['payload'];
    if (payload is! Map) return 0;
    final value = payload[key];
    final number = value is num
        ? value.toDouble()
        : value is String
        ? double.tryParse(value)
        : null;
    return number?.isFinite == true ? number! : 0;
  }

  int fanRangeFor(TopicRule rule) {
    return _topicRanges[rule.id] ?? 5;
  }

  Future<void> setTopicControlType(
    TopicRule rule,
    TopicControlType type,
  ) async {
    if (selectedRule?.id != rule.id) selectRule(rule);
    await _saveRule({
      'controlType': switch (type) {
        TopicControlType.fan => 'fan',
        TopicControlType.thermometer => 'thermometer',
        TopicControlType.switchControl => 'switch',
      },
    });
    _notify();
  }

  void setFanRange(TopicRule rule, int value) {
    final range = value.clamp(0, 10);
    _topicRanges[rule.id] = range;
    _notify();
  }

  Future<bool> sendFanCommand(TopicRule rule, bool enabled, int range) async {
    final sent = await sendTopicCommand(
      rule,
      rawPayload: jsonEncode({
        'status': enabled ? 'on' : 'off',
        'range': range.clamp(0, 10),
      }),
    );
    if (sent) {
      _topicPower[rule.id] = enabled;
      setFanRange(rule, range);
    }
    return sent;
  }

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
      !isSendingTopic(rule) &&
      !connecting &&
      rules.contains(rule) &&
      rule.canPublish &&
      matchesTopic(rule.topic, destinationFor(rule));
  bool isSendingTopic(TopicRule rule) => _sendingTopicIds.contains(rule.id);
  void openTopic(TopicRule rule) {
    selectRule(rule);
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
    _sendingTopicIds.add(rule.id);
    error = null;
    _notify();
    try {
      await broker.publish(destination, payload, retain: true);
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
        _sendingTopicIds.remove(rule.id);
        _notify();
      }
    }
  }

  void _receive(BrokerMessage message) {
    final matching = rules
        .where((r) => r.canSubscribe && matchesTopic(r.topic, message.topic))
        .toList();
    if (matching.isEmpty) return;
    final payload = _decode(message.payload);
    for (final rule in matching) {
      final readings = _readings.putIfAbsent(rule.id, () => []);
      readings.add(message);
      if (readings.length > 200) readings.removeAt(0);
      if (payload is Map && payload['power'] is bool) {
        _topicPower[rule.id] = payload['power'] as bool;
      }
      if (payload is Map && payload['status'] != null) {
        _topicPower[rule.id] = [
          'on',
          'true',
        ].contains(payload['status'].toString().toLowerCase());
      }
      if (payload is Map && payload['range'] is num) {
        _topicRanges[rule.id] = (payload['range'] as num).round().clamp(0, 10);
      }
    }
    _addEvent(
      TemplateEvent(
        direction: EventDirection.received,
        templateName: selectedDevice?.username ?? 'Device',
        topic: message.topic,
        payload: payload,
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

  // Only the topic (or wildcard prefix) being shown is requested. Exact topics
  // need one row; wildcards need a window because the prefix can match others.
  Map<String, String> _topicQuery(TopicRule rule) => rule.wildcard
      ? {'topicPrefix': rule.topic.split(RegExp(r'[+#]')).first}
      : {'topic': rule.topic};

  static const _storedHistoryWindow = Duration(minutes: 30);

  void setStoredDeviceOnly(bool value) {
    if (storedDeviceOnly == value) return;
    storedDeviceOnly = value;
    storedMessages = [];
    storedTotal = 0;
    _storedPage = 0;
    _storedPages = 0;
    _notify();
    unawaited(loadHistory());
  }

  Map<String, dynamic> _storedRow(Object? value) {
    final row = Map<String, dynamic>.from(value as Map);
    final payload = row['payload'];
    if (payload is String) row['payload'] = _decode(payload);
    return row;
  }

  Future<void> refreshLatestStored() async {
    final device = selectedDevice;
    if (device == null) return;
    final selection = _deviceSelection;
    final generation = _workspace;
    await Future.wait([
      for (final rule in rules.where((r) => r.isStored))
        _loadLatestStored(device, rule, selection, generation),
    ]);
    _notify();
  }

  Future<void> _loadLatestStored(
    Device device,
    TopicRule rule,
    int selection,
    int generation,
  ) async {
    try {
      final data = await api.request(
        '/api/store/messages',
        query: {
          'deviceId': '${device.id}',
          ..._topicQuery(rule),
          'size': rule.wildcard ? '50' : '1',
          'from': DateTime.now()
              .toUtc()
              .subtract(_storedHistoryWindow)
              .toIso8601String(),
        },
      ) as Map;
      if (selection != _deviceSelection || generation != _workspace) return;
      final newest = (data['content'] as List)
          .map(_storedRow)
          .where((r) => matchesTopic(rule.topic, r['topic'] as String? ?? ''))
          .firstOrNull;
      if (newest == null) {
        _latestStored.remove(rule.id);
      } else {
        _latestStored[rule.id] = newest;
        final payload = newest['payload'];
        if (payload is Map && payload['power'] is bool) {
          _topicPower[rule.id] = payload['power'] as bool;
        }
        if (payload is Map && payload['status'] != null) {
          _topicPower[rule.id] = [
            'on',
            'true',
          ].contains(payload['status'].toString().toLowerCase());
        }
        if (payload is Map && payload['range'] is num) {
          _topicRanges[rule.id] = (payload['range'] as num).round().clamp(
            0,
            10,
          );
        }
      }
    } catch (_) {
      // Keep the last value on the card when a refresh fails.
    }
  }

  Map<String, dynamic>? latestStoredFor(TopicRule rule) =>
      _latestStored[rule.id];

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
          if (storedDeviceOnly) 'deviceId': '${selectedDevice!.id}',
          ..._topicQuery(rule),
          'page': '$_storedPage',
          'size': '200',
          'from': _historyTo!.subtract(_storedHistoryWindow).toIso8601String(),
          'to': _historyTo!.toIso8601String(),
        },
      ) as Map;
      if (selection != _selection || generation != _workspace || _disposed) {
        return;
      }
      final rows = (data['content'] as List)
          .map(_storedRow)
          .where((r) => matchesTopic(rule.topic, r['topic'] as String? ?? ''))
          .toList();
      storedMessages = more ? [...storedMessages, ...rows] : rows;
      storedTotal = (data['totalElements'] as num?)?.toInt() ?? rows.length;
      _storedPages = (data['totalPages'] as num?)?.toInt() ?? 1;
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
    _topicPower.clear();
    _topicRanges.clear();
    _latestStored.clear();
    metricHistory.clear();
    events.clear();
    _preferences = {};
    _topicControls.clear();
    needsClientSetup = false;
    storedMessages = [];
    pageIndex = 0;
    busy = false;
    connecting = false;
    _sendingTopicIds.clear();
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
