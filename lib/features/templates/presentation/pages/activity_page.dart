import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/iot_template.dart';
import '../controllers/template_controller.dart';
import '../widgets/page_header.dart';

class ActivityPage extends StatelessWidget {
  const ActivityPage({super.key, required this.controller});

  final TemplateController controller;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      key: const PageStorageKey<String>('activity'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 34, 24, 20),
          sliver: SliverToBoxAdapter(
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: controller.events.isEmpty
                    ? null
                    : controller.clearEvents,
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Clear'),
              ),
            ),
          ),
        ),
        if (controller.events.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyActivity(),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 40),
            sliver: SliverList.separated(
              itemCount: controller.events.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final event = controller.events[index];
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: _EventCard(event: event),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event});
  final TemplateEvent event;

  @override
  Widget build(BuildContext context) {
    final sent = event.direction == EventDirection.sent;
    final color = sent ? const Color(0xFF3C75C6) : AppTheme.green;
    return Card(
      child: ExpansionTile(
        key: PageStorageKey<String>(
          'activity:${event.direction.name}:${event.topic}:${event.time.microsecondsSinceEpoch}',
        ),
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
        childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(
            sent ? Icons.north_east_rounded : Icons.south_west_rounded,
            color: color,
            size: 19,
          ),
        ),
        title: Row(
          children: [
            Text(
              sent ? 'SENT' : 'RECEIVED',
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: .7,
              ),
            ),
            const SizedBox(width: 9),
            Flexible(
              child: Text(
                event.templateName,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            '${event.topic}  •  ${_time(event.time)}',
            overflow: TextOverflow.ellipsis,
          ),
        ),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF18251F),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              event.payload?.toString() ?? 'null',
              style: const TextStyle(
                color: Color(0xFFB9EBD7),
                fontFamily: 'monospace',
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _time(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final second = time.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second ${time.hour >= 12 ? 'PM' : 'AM'}';
  }
}

class _EmptyActivity extends StatelessWidget {
  const _EmptyActivity();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: const BoxDecoration(
                color: Color(0xFFE5F3EC),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.inbox_outlined,
                size: 31,
                color: AppTheme.green,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No activity yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 7),
            const Text(
              'Connect a device to receive data or send your first command.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
