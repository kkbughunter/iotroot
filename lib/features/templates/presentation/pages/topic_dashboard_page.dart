import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../workspace/data/workspace_models.dart';
import '../controllers/template_controller.dart';
import 'topic_details_page.dart';

class TopicDashboardPage extends StatefulWidget {
  const TopicDashboardPage({super.key, required this.controller});
  final TemplateController controller;

  @override
  State<TopicDashboardPage> createState() => _TopicDashboardPageState();
}

class _TopicDashboardPageState extends State<TopicDashboardPage> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => unawaited(widget.controller.refreshLatestStored()),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE0EFFA), Color(0xFFF0F6F4), Color(0xFFF8F7F2)],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = 8.0;
          final width = constraints.maxWidth - 24;
          final columns = width >= 1050
              ? 4
              : width >= 700
              ? 3
              : width >= 280
              ? 2
              : 1;
          final cardWidth = (width - gap * (columns - 1)) / columns;
          return SingleChildScrollView(
            key: const PageStorageKey<String>('topics'),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back,',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                // Text(
                //   controller.connected ? 'Connected' : 'Not connected',
                //   style: const TextStyle(fontSize: 12, color: AppTheme.muted),
                // ),
                const SizedBox(height: 12),
                if (controller.rules.isEmpty &&
                    !controller.loadingRules &&
                    !controller.busy)
                  const Text('No topics yet.'),
                Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final rule in controller.rules)
                      SizedBox(
                        width:
                            controller.controlTypeFor(rule) ==
                                    TopicControlType.fan &&
                                columns > 1
                            ? cardWidth * 2 + gap
                            : cardWidth,
                        height: 140,
                        child: _TopicCard(controller: controller, rule: rule),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// A compact summary card. Tapping it opens the topic details, where templates,
// controls and stored data are shown.
class _TopicCard extends StatelessWidget {
  const _TopicCard({required this.controller, required this.rule});
  final TemplateController controller;
  final TopicRule rule;

  String? get _latest {
    if (rule.isStored) {
      final row = controller.latestStoredFor(rule);
      return row == null ? null : jsonEncode(row['payload']);
    }
    return controller.latestFor(rule)?.payload;
  }

  @override
  Widget build(BuildContext context) {
    final latest = _latest;
    final power = controller.powerFor(rule);
    final type = controller.controlTypeFor(rule);
    final isFan = type == TopicControlType.fan;
    final range = controller.fanRangeFor(rule);
    final accent = rule.isStored
        ? const Color(0xFFDDF3E5)
        : const Color(0xFFFFE8CC);
    final accentStrong = rule.isStored
        ? const Color(0xFF287A4B)
        : const Color(0xFFAD5B00);
    return Card(
      key: ValueKey('topic-card:${rule.id}'),
      margin: EdgeInsets.zero,
      color: accent,
      child: InkWell(
        onTap: () {
          controller.openTopic(rule);
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => TopicDetailsPage(controller: controller),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    margin: const EdgeInsets.only(right: 7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .72),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      isFan
                          ? Icons.mode_fan_off_rounded
                          : Icons.lightbulb_outline_rounded,
                      size: 17,
                      color: accentStrong,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      rule.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),

              Text(
                rule.topic,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: AppTheme.muted),
              ),

              const Spacer(),
              if (isFan)
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        key: ValueKey('topic-range:${rule.id}'),
                        value: range.toDouble(),
                        min: 0,
                        max: 10,
                        divisions: 10,
                        label: '$range',
                        onChanged: controller.canSendTopic(rule)
                            ? (value) =>
                                  controller.setFanRange(rule, value.round())
                            : null,
                        onChangeEnd: controller.canSendTopic(rule)
                            ? (value) => controller.sendFanCommand(
                                rule,
                                power,
                                value.round(),
                              )
                            : null,
                      ),
                    ),
                    SizedBox(
                      width: 28,
                      child: Text(
                        '$range',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 4),
                    _PowerSwitch(
                      controller: controller,
                      rule: rule,
                      value: power,
                      range: range,
                      fan: true,
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        latest ?? 'No data',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: latest == null ? AppTheme.muted : AppTheme.ink,
                        ),
                      ),
                    ),
                    _PowerSwitch(
                      controller: controller,
                      rule: rule,
                      value: power,
                      range: range,
                      fan: false,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PowerSwitch extends StatelessWidget {
  const _PowerSwitch({
    required this.controller,
    required this.rule,
    required this.value,
    required this.range,
    required this.fan,
  });

  final TemplateController controller;
  final TopicRule rule;
  final bool value;
  final int range;
  final bool fan;

  @override
  Widget build(BuildContext context) => Transform.scale(
    scale: .78,
    child: Switch.adaptive(
      key: ValueKey('topic-power:${rule.id}'),
      value: value,
      onChanged: controller.canSendTopic(rule)
          ? (enabled) {
              if (fan) {
                controller.sendFanCommand(rule, enabled, range);
              } else {
                controller.setTopicPower(rule, enabled);
              }
            }
          : null,
    ),
  );
}
