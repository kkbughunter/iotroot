class Device {
  const Device({
    required this.id,
    required this.clientId,
    required this.username,
    this.displayName,
    this.mountpoint = '',
  });
  factory Device.fromJson(Map<String, dynamic> json) => Device(
    id: (json['id'] as num).toInt(),
    clientId: json['clientId'] as String,
    username: json['username'] as String,
    displayName: json['displayName'] as String?,
    mountpoint: json['mountpoint'] as String? ?? '',
  );
  final int id;
  final String clientId, username, mountpoint;
  final String? displayName;
  String get name =>
      displayName?.trim().isNotEmpty == true ? displayName! : username;
}

class TopicRule {
  const TopicRule({
    required this.id,
    required this.topic,
    required this.permission,
    this.topicName,
    this.topicType = 'STANDARD',
  });
  factory TopicRule.fromJson(Map<String, dynamic> json) => TopicRule(
    id: (json['id'] as num).toInt(),
    topic: json['topic'] as String,
    permission: (json['permission'] as String).toLowerCase(),
    topicName: json['topicName'] as String?,
    topicType: json['topicType'] as String? ?? 'STANDARD',
  );
  final int id;
  final String topic, permission, topicType;
  final String? topicName;
  String get name => topicName?.trim().isNotEmpty == true ? topicName! : topic;
  bool get isStored => topicType == 'STORE';
  bool get canPublish => permission == 'publish' || permission == 'readwrite';
  bool get canSubscribe =>
      permission == 'subscribe' || permission == 'readwrite';
  bool get wildcard => topic.contains('#') || topic.contains('+');
}

bool matchesTopic(String filter, String topic) {
  if (topic.isEmpty || topic.contains(RegExp(r'[+#\x00]'))) return false;
  if (topic.startsWith(r'$') && !filter.startsWith(r'$')) return false;
  final filters = filter.split('/');
  final levels = topic.split('/');
  for (var i = 0; i < filters.length; i++) {
    if (filters[i] == '#') return i == filters.length - 1;
    if (i >= levels.length || (filters[i] != '+' && filters[i] != levels[i])) {
      return false;
    }
  }
  return filters.length == levels.length;
}

class BrokerSettings {
  const BrokerSettings({
    required this.host,
    required this.port,
    this.tls = false,
  });
  final String host;
  final int port;
  final bool tls;
}

class BrokerMessage {
  const BrokerMessage(this.topic, this.payload, this.time);
  final String topic, payload;
  final DateTime time;
}
