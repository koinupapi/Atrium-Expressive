import 'package:core_models/core_models.dart';
import 'package:core_router/core_router.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../activity/activity_providers.dart';
import '../dashboard_widget_card.dart';
import '../dashboard_widget_kind.dart';

/// A featured session and a short preview of the live list from Activity.
class DashboardStreamsWidget extends ConsumerWidget {
  const DashboardStreamsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ActivityStreamsState state = ref.watch(activityStreamsProvider);
    final List<ActivityStream> streams = state.streams;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    final Widget body;
    if (streams.isEmpty) {
      if (state.anyLoading) {
        body = const DashboardIdleRow(text: 'Checking streams…');
      } else if (state.errors.isNotEmpty) {
        body = DashboardErrorRow(onRetry: () => refreshActivity(ref));
      } else {
        body = const DashboardIdleRow(text: 'No active streams');
      }
    } else {
      body = DashboardDisclosure(
        // Show the lead stream; show a second compact row whenever present.
        previewCount: 2,
        itemCount: streams.length,
        itemBuilder: (BuildContext context, int index) {
          final ActivityStream stream = streams[index];
          final Key key = ValueKey<String>(stream.key);
          return index == 0
              ? _FeaturedStream(key: key, stream: stream)
              : _CompactStream(key: key, stream: stream);
        },
      );
    }

    return DashboardWidgetCard(
      kind: DashboardWidgetKind.streams,
      accent: scheme.onPrimaryContainer,
      trailing: streams.isEmpty
          ? null
          : DashboardPill(
              icon: Icons.play_arrow_rounded,
              label: '${streams.length} active',
              color: scheme.onPrimaryContainer,
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AnimatedSize(
            alignment: Alignment.topCenter,
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            child: body,
          ),
          if (streams.isNotEmpty && state.errors.isNotEmpty)
            const DashboardIdleRow(text: 'Some stream sources are unavailable'),
        ],
      ),
    );
  }
}

void _openStream(BuildContext context, ActivityStream stream) {
  final Widget Function(BuildContext)? builder = stream.onOpenBuilder;
  if (builder != null) {
    pushScreen<void>(context, builder(context));
  } else {
    context.go(AtriumRoutes.servicePath(
      stream.instance.kind.name,
      stream.instance.id,
    ));
  }
}

String _streamDetails(ActivityStream stream, {required bool includeSource}) =>
    <String>[
      if (includeSource) stream.sourceKind.displayName,
      if (stream.subtitle case final String subtitle) subtitle,
      if (stream.userName case final String userName) userName,
      if (stream.detailChip case final String detail) detail,
      if (stream.paused) 'Paused',
    ].join(' · ');

class _FeaturedStream extends StatelessWidget {
  const _FeaturedStream({required this.stream, super.key});

  final ActivityStream stream;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final double progress = stream.progress.clamp(0.0, 1.0);
    final String details = _streamDetails(stream, includeSource: false);
    return Material(
      color: scheme.inverseSurface,
      borderRadius: const BorderRadiusDirectional.only(
        topStart: Radius.circular(26),
        topEnd: Radius.circular(14),
        bottomStart: Radius.circular(14),
        bottomEnd: Radius.circular(26),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: <Widget>[
          if (stream.imageUrl case final String image)
            Positioned.fill(
              child: AtriumNetworkImage(
                imageUrl: image,
                fit: BoxFit.cover,
                memCacheWidth: 720,
                errorWidget: (_, __, ___) =>
                    ColoredBox(color: scheme.inverseSurface),
              ),
            ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[Color(0x50100C15), Color(0xF0100C15)],
                ),
              ),
            ),
          ),
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: () => _openStream(context, stream),
              child: Padding(
                padding: const EdgeInsets.all(Insets.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text(stream.sourceKind.displayName),
                      ),
                    ),
                    const SizedBox(height: Insets.lg),
                    Text(
                      stream.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (details.isNotEmpty)
                      Text(
                      details,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: Insets.sm),
                    LinearProgressIndicator(
                      value: progress,
                      borderRadius: BorderRadius.circular(8),
                      color: scheme.primaryContainer,
                      backgroundColor: Colors.white24,
                      semanticsLabel: 'Playback progress',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactStream extends StatelessWidget {
  const _CompactStream({required this.stream, super.key});

  final ActivityStream stream;

  @override
  Widget build(BuildContext context) => Material(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: Icon(stream.aspectRatio == 1.0
              ? Icons.graphic_eq_rounded
              : Icons.play_circle_outline),
          title: Text(stream.title, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text(_streamDetails(stream, includeSource: true)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _openStream(context, stream),
        ),
      );
}
