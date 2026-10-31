import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../workspace/data/workspace_models.dart';
import '../controllers/template_controller.dart';

class ControlTypeSelectionPage extends StatefulWidget {
  const ControlTypeSelectionPage({
    super.key,
    required this.controller,
    required this.rule,
  });

  final TemplateController controller;
  final TopicRule rule;

  @override
  State<ControlTypeSelectionPage> createState() =>
      _ControlTypeSelectionPageState();
}

class _ControlTypeSelectionPageState extends State<ControlTypeSelectionPage> {
  static const _types = <TopicControlType>[
    TopicControlType.switchControl,
    TopicControlType.fan,
  ];

  TopicControlType? _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final current = widget.controller.controlTypeFor(widget.rule);
    _selected = _types.contains(current) ? current : null;
  }

  Future<void> _select(TopicControlType type) async {
    if (_saving) return;
    setState(() {
      _selected = type;
      _saving = true;
    });
    await widget.controller.setTopicControlType(widget.rule, type);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Control type'),
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 720;
            final cards = [
              for (final type in _types)
                _ControlPreviewCard(
                  controller: widget.controller,
                  rule: widget.rule,
                  type: type,
                  selected: _selected == type,
                  saving: _saving && _selected == type,
                  enabled: !_saving,
                  onTap: () => _select(type),
                ),
            ];
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 820),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SelectionHeader(rule: widget.rule),
                        const SizedBox(height: 22),
                        Text(
                          'Select a layout',
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Tap a card to apply it to this topic.',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 14),
                        if (wide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: cards[0]),
                              const SizedBox(width: 16),
                              Expanded(child: cards[1]),
                            ],
                          )
                        else
                          Column(
                            children: [
                              cards[0],
                              const SizedBox(height: 14),
                              cards[1],
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SelectionHeader extends StatelessWidget {
  const _SelectionHeader({required this.rule});

  final TopicRule rule;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              Icons.dashboard_customize_rounded,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How should this topic look?',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 5),
                Text(
                  rule.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (rule.name != rule.topic) ...[
                  const SizedBox(height: 2),
                  Text(
                    rule.topic,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlPreviewCard extends StatelessWidget {
  const _ControlPreviewCard({
    required this.controller,
    required this.rule,
    required this.type,
    required this.selected,
    required this.saving,
    required this.enabled,
    required this.onTap,
  });

  final TemplateController controller;
  final TopicRule rule;
  final TopicControlType type;
  final bool selected;
  final bool saving;
  final bool enabled;
  final VoidCallback onTap;

  bool get _isFan => type == TopicControlType.fan;
  String get _label => _isFan ? 'Fan' : 'Light';
  String get _description => _isFan
      ? 'Power control with a 0–10 speed slider.'
      : 'Simple power control for lights, plugs, and switches.';
  IconData get _icon =>
      _isFan ? Icons.mode_fan_off_rounded : Icons.lightbulb_outline_rounded;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(22);
    return Semantics(
      selected: selected,
      button: true,
      label: '$_label control type',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: radius,
          border: Border.all(
            color: selected ? colors.primary : colors.outlineVariant,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: .12),
                    blurRadius: 18,
                    offset: const Offset(0, 7),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: ValueKey('control-preview:${type.name}'),
            onTap: enabled ? onTap : null,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: _isFan
                              ? const Color(0xFFE2F1EC)
                              : const Color(0xFFFFE9C8),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          _icon,
                          color: _isFan
                              ? AppTheme.green
                              : const Color(0xFFA85A00),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _label,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _description,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (saving)
                        const SizedBox.square(
                          dimension: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      else
                        Icon(
                          selected
                              ? Icons.check_circle_rounded
                              : Icons.circle_outlined,
                          color: selected ? colors.primary : colors.outline,
                          size: 26,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _HomeCardPreview(
                    controller: controller,
                    rule: rule,
                    isFan: _isFan,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeCardPreview extends StatelessWidget {
  const _HomeCardPreview({
    required this.controller,
    required this.rule,
    required this.isFan,
  });

  final TemplateController controller;
  final TopicRule rule;
  final bool isFan;

  @override
  Widget build(BuildContext context) {
    final power = controller.powerFor(rule);
    final range = controller.fanRangeFor(rule);
    final accent = isFan ? const Color(0xFFE7F3ED) : const Color(0xFFFFF1DC);
    final accentStrong = isFan ? AppTheme.green : const Color(0xFFA85A00);

    return Container(
      height: 140,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                margin: const EdgeInsets.only(right: 9),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .78),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  isFan
                      ? Icons.mode_fan_off_rounded
                      : Icons.lightbulb_outline_rounded,
                  size: 19,
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
          const Spacer(),
          if (isFan)
            Row(
              children: [
                Expanded(
                  child: IgnorePointer(
                    child: Slider(
                      value: range.toDouble(),
                      min: 0,
                      max: 10,
                      divisions: 10,
                      onChanged: (_) {},
                    ),
                  ),
                ),
                Text(
                  '$range',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(width: 5),
                _PreviewSwitch(value: power),
              ],
            )
          else
            Row(
              children: [
                Icon(
                  power
                      ? Icons.lightbulb_rounded
                      : Icons.lightbulb_outline_rounded,
                  color: accentStrong,
                  size: 28,
                ),
                const SizedBox(width: 8),
                Text(
                  power ? 'Light is on' : 'Light is off',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                _PreviewSwitch(value: power),
              ],
            ),
        ],
      ),
    );
  }
}

class _PreviewSwitch extends StatelessWidget {
  const _PreviewSwitch({required this.value});
  final bool value;

  @override
  Widget build(BuildContext context) => Transform.scale(
    scale: .78,
    child: IgnorePointer(
      child: Switch.adaptive(value: value, onChanged: (_) {}),
    ),
  );
}
