import 'dart:async';

import 'package:core_models/core_models.dart';
import 'package:core_profile/core_profile.dart';
import 'package:core_router/core_router.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';
import 'package:service_adguard_home/service_adguard_home.dart';
import 'package:service_dashdot/service_dashdot.dart';
import 'package:service_glances/service_glances.dart';
import 'package:service_deluge/service_deluge.dart';
import 'package:service_nzbget/service_nzbget.dart';
import 'package:service_ombi/service_ombi.dart';
import 'package:service_qbittorrent/service_qbittorrent.dart';
import 'package:service_radarr/service_radarr.dart';
import 'package:service_sabnzbd/service_sabnzbd.dart';
import 'package:service_seerr/service_seerr.dart';
import 'package:service_sonarr/service_sonarr.dart';
import 'package:service_speedtest_tracker/service_speedtest_tracker.dart';
import 'package:service_tracearr/service_tracearr.dart';
import 'package:service_rtorrent/service_rtorrent.dart';
import 'package:service_transmission/service_transmission.dart';
import 'package:service_gluetun/service_gluetun.dart';
import 'package:service_myspeed/service_myspeed.dart';
import 'package:service_aria2/service_aria2.dart';
import 'package:service_cleanuparr/service_cleanuparr.dart';
import 'package:service_slskd/service_slskd.dart';

import '../activity/activity_providers.dart';
import '../health_providers.dart';
import '../screens/calendar_screen.dart';
import 'dashboard_layout.dart';
import 'dashboard_widget_card.dart';
import 'dashboard_widget_kind.dart';
import 'widgets/adguard_home_widget.dart';
import 'widgets/cleanuparr_widget.dart';
import 'widgets/dashdot_widget.dart';
import 'widgets/downloads_widget.dart';
import 'widgets/gluetun_status_widget.dart';
import 'widgets/myspeed_widget.dart';
import 'widgets/recently_added_widget.dart';
import 'widgets/recently_downloaded_widget.dart';
import 'widgets/requests_widget.dart';
import 'widgets/server_info_widget.dart';
import 'widgets/speedtest_results_widget.dart';
import 'widgets/wake_on_lan_widget.dart';
import 'widgets/streams_widget.dart';
import 'widgets/upcoming_widget.dart';

/// Whether the board is in inline edit (reorder / hide) mode. Toggled from
/// the dashboard app bar; ephemeral by design (resets on app restart).
final StateProvider<bool> dashboardEditModeProvider =
    StateProvider<bool>((Ref ref) => false);

/// The dashboard widget board: at-a-glance cards in the user's saved order,
/// with an inline edit mode for reordering and hiding.
class DashboardBoard extends ConsumerStatefulWidget {
  const DashboardBoard({super.key});

  @override
  ConsumerState<DashboardBoard> createState() => _DashboardBoardState();
}

class _DashboardBoardState extends ConsumerState<DashboardBoard> {
  static const List<DashboardWidgetKind> _summaryKinds = <DashboardWidgetKind>[
    DashboardWidgetKind.streams,
    DashboardWidgetKind.downloads,
    DashboardWidgetKind.upcoming,
  ];

  final Map<DashboardWidgetKind, GlobalKey> _sectionKeys =
      <DashboardWidgetKind, GlobalKey>{
    for (final DashboardWidgetKind kind in _summaryKinds) kind: GlobalKey(),
  };

  @override
  Widget build(BuildContext context) {
    final List<Instance> instances = ref.watch(activeInstancesProvider);
    final List<DashboardWidgetConfig> layout =
        ref.watch(dashboardLayoutProvider);
    final bool editing = ref.watch(dashboardEditModeProvider);
    final int wolCount =
        ref.watch(activeProfileProvider)?.wolDevices.length ?? 0;

    if (editing) {
      return _EditBoard(layout: layout, instances: instances);
    }

    final List<DashboardWidgetConfig> visible = <DashboardWidgetConfig>[
      for (final DashboardWidgetConfig c in layout)
        if (c.enabled && _configured(c.kind, instances, wolDeviceCount: wolCount))
          c,
    ];

    if (visible.isEmpty) {
      return const EmptyView(
        icon: Icons.dashboard_customize_outlined,
        title: 'No widgets to show',
        message: 'Use the customize button (top right) to add widgets.',
      );
    }

    final Set<DashboardWidgetKind> visibleKinds = <DashboardWidgetKind>{
      for (final DashboardWidgetConfig config in visible) config.kind,
    };
    final List<DashboardWidgetKind> summary = _summaryKinds
        .where(visibleKinds.contains)
        .toList();
    final int offset = summary.isEmpty ? 0 : 1;

    return EasyRefresh(
      header: const ClassicHeader(
        dragText: 'Pull to refresh',
        armedText: 'Release ready',
        readyText: 'Refreshing...',
        processingText: 'Refreshing...',
        processedText: 'Succeeded',
        failedText: 'Failed',
        messageText: 'Last updated at %T',
      ),
      onRefresh: () async => _refreshAll(ref, instances),
      child: ListView.separated(
        padding: Insets.page,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: visible.length + offset,
        separatorBuilder: (_, __) => const SizedBox(height: Insets.md),
        itemBuilder: (BuildContext context, int index) {
          if (offset == 1 && index == 0) {
            return _DashboardSummary(kinds: summary, onTap: _focusSection);
          }
          final DashboardWidgetKind kind = visible[index - offset].kind;
          return _KeepAliveWrapper(
            key: _sectionKeys[kind] ?? ValueKey<DashboardWidgetKind>(kind),
            child: _buildWidget(kind, instances),
          );
        },
      ),
    );
  }

  void _focusSection(DashboardWidgetKind kind) {
    final BuildContext? target = _sectionKeys[kind]?.currentContext;
    if (target != null) {
      unawaited(Scrollable.ensureVisible(
        target,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      ));
    } else {
      // A far-off section may not be mounted by the lazy list yet.
      context.goNamed(kind == DashboardWidgetKind.upcoming
          ? AtriumRoutes.calendarName
          : AtriumRoutes.activityName);
    }
  }

  /// Whether a widget has anything behind it to show.
  ///
  /// Almost every widget is answered by a service, so having one configured is
  /// the test. Wake-on-LAN is not: it points at machines rather than servers,
  /// so it is set up once a device exists on the profile, and the usual test
  /// would call it unconfigured forever.
  static bool _configured(
    DashboardWidgetKind kind,
    List<Instance> instances, {
    int wolDeviceCount = 0,
  }) {
    if (kind.isDeviceBacked) {
      return wolDeviceCount > 0;
    }
    return instances.any((Instance i) => kind.serviceKinds.contains(i.kind));
  }

  static List<Instance> _byKind(List<Instance> instances, ServiceKind kind) {
    final Set<String> seenIds = <String>{};
    final Set<String> seenEndpoints = <String>{};
    final List<Instance> out = <Instance>[];
    for (final Instance i in instances) {
      if (i.kind != kind) continue;
      if (!seenIds.add(i.id)) continue;
      final String endpoint =
          i.localUrl.isNotEmpty ? i.localUrl : i.externalUrl;
      if (endpoint.isNotEmpty && !seenEndpoints.add(endpoint)) continue;
      out.add(i);
    }
    return out;
  }

  Widget _buildWidget(DashboardWidgetKind kind, List<Instance> instances) {
    switch (kind) {
      case DashboardWidgetKind.downloads:
        return DashboardDownloadsWidget(
          qbitInstances: _byKind(instances, ServiceKind.qbittorrent),
          sabInstances: _byKind(instances, ServiceKind.sabnzbd),
          nzbgetInstances: _byKind(instances, ServiceKind.nzbget),
          delugeInstances: _byKind(instances, ServiceKind.deluge),
          transmissionInstances: _byKind(instances, ServiceKind.transmission),
          rtorrentInstances: _byKind(instances, ServiceKind.rtorrent),
          aria2Instances: _byKind(instances, ServiceKind.aria2),
          slskdInstances: _byKind(instances, ServiceKind.slskd),
        );
      case DashboardWidgetKind.streams:
        return const DashboardStreamsWidget();
      case DashboardWidgetKind.upcoming:
        return const DashboardUpcomingWidget();
      case DashboardWidgetKind.recentlyAdded:
        return DashboardRecentlyAddedWidget(
          sonarrInstances: _byKind(instances, ServiceKind.sonarr),
          radarrInstances: _byKind(instances, ServiceKind.radarr),
        );
      case DashboardWidgetKind.recentlyDownloaded:
        return DashboardRecentlyDownloadedWidget(
          sonarrInstances: _byKind(instances, ServiceKind.sonarr),
          radarrInstances: _byKind(instances, ServiceKind.radarr),
        );
      case DashboardWidgetKind.requests:
        return DashboardRequestsWidget(
          instances: <Instance>[
            ..._byKind(instances, ServiceKind.seerr),
            ..._byKind(instances, ServiceKind.ombi),
          ],
        );
      case DashboardWidgetKind.serverInfo:
        return DashboardServerInfoWidget(
          instances: _byKind(instances, ServiceKind.glances),
        );
      case DashboardWidgetKind.dashdot:
        return DashboardDashdotWidget(
          instances: _byKind(instances, ServiceKind.dashdot),
        );
      case DashboardWidgetKind.speedtestResults:
        return DashboardSpeedtestResultsWidget(
          instances: _byKind(instances, ServiceKind.speedtestTracker),
        );
      case DashboardWidgetKind.gluetunStatus:
        return DashboardGluetunStatusWidget(
          instances: _byKind(instances, ServiceKind.gluetun),
        );
      case DashboardWidgetKind.myspeed:
        return DashboardMySpeedWidget(
          instances: _byKind(instances, ServiceKind.myspeed),
        );
      case DashboardWidgetKind.adguardHome:
        return DashboardAdguardHomeWidget(
          instances: _byKind(instances, ServiceKind.adguardHome),
        );
      case DashboardWidgetKind.cleanuparr:
        return DashboardCleanuparrWidget(
          instances: _byKind(instances, ServiceKind.cleanuparr),
        );
      case DashboardWidgetKind.wakeOnLan:
        return const DashboardWakeOnLanWidget();
    }
  }

  void _refreshAll(WidgetRef ref, List<Instance> instances) {
    ref.read(lastHealthRefreshProvider.notifier).markRefreshed();
    refreshActivity(ref, streamsOnly: true);
    for (final Instance i in instances) {
      ref.invalidate(instanceHealthProvider(i.id));
      switch (i.kind) {
        case ServiceKind.sonarr:
          ref.invalidate(sonarrSeriesProvider(i));
          ref.invalidate(sonarrHistoryProvider(i));
        case ServiceKind.radarr:
          ref.invalidate(radarrMoviesProvider(i));
          ref.invalidate(radarrHistoryProvider(i));
        case ServiceKind.qbittorrent:
          ref.invalidate(qbitRawTorrentsProvider(i));
          ref.invalidate(qbitTransferProvider(i));
        case ServiceKind.sabnzbd:
          ref.invalidate(sabQueueProvider(i));
        case ServiceKind.nzbget:
          ref.invalidate(nzbgetQueueProvider(i));
          ref.invalidate(nzbgetStatusProvider(i));
        case ServiceKind.deluge:
          ref.invalidate(delugeRawTorrentsProvider(i));
          ref.invalidate(delugeSessionStatusProvider(i));
        case ServiceKind.transmission:
          ref.invalidate(transmissionRawTorrentsProvider(i));
          ref.invalidate(transmissionSessionStatsProvider(i));
        case ServiceKind.rtorrent:
          ref.invalidate(rtorrentRawTorrentsProvider(i));
          ref.invalidate(rtorrentGlobalProvider(i));
        case ServiceKind.aria2:
          ref.invalidate(aria2SnapshotProvider(i));
        case ServiceKind.seerr:
          ref.invalidate(seerrRequestCountsProvider(i));
          ref.invalidate(seerrRequestsProvider(i));
        case ServiceKind.ombi:
          ref.invalidate(ombiCountsProvider(i));
          ref.invalidate(ombiRecentRequestsProvider(i));
        case ServiceKind.glances:
          ref.invalidate(glancesStatsProvider(i));
        case ServiceKind.dashdot:
          ref.invalidate(dashdotInfoProvider(i));
          ref.invalidate(dashdotCpuHistoryProvider(i));
          ref.invalidate(dashdotRamHistoryProvider(i));
          ref.invalidate(dashdotStorageHistoryProvider(i));
          ref.invalidate(dashdotNetworkHistoryProvider(i));
        case ServiceKind.speedtestTracker:
          ref.invalidate(speedtestOverviewProvider(i));
        case ServiceKind.tracearr:
          ref.invalidate(tracearrStreamsProvider(i));
        case ServiceKind.gluetun:
          ref.invalidate(gluetunVpnStatusProvider(i));
          ref.invalidate(gluetunPublicIpProvider(i));
        case ServiceKind.myspeed:
          ref.invalidate(myspeedStatusProvider(i));
          ref.invalidate(myspeedRecentTestsProvider(i));
        case ServiceKind.adguardHome:
          // After a refused sign-in these send nothing: the instance's
          // session answers them itself until Try again is tapped.
          ref.invalidate(adguardHomeStatusProvider(i));
          ref.invalidate(adguardHomeStatsProvider(i));
          ref.invalidate(adguardHomeFilteringProvider(i));
        case ServiceKind.cleanuparr:
          ref.invalidate(cleanuparrStatusProvider(i));
          ref.invalidate(cleanuparrStatsProvider(i));
          ref.invalidate(cleanuparrStrikesProvider(i));
          ref.invalidate(cleanuparrStrikesCountProvider(i));
          ref.invalidate(cleanuparrJobsProvider(i));
        case ServiceKind.slskd:
          ref.invalidate(slskdDownloadsProvider(i));
          ref.invalidate(slskdUploadsProvider(i));
        default:
          break;
      }
    }
    for (final DateTime m in upcomingWindowMonths(DateTime.now())) {
      ref.invalidate(globalCalendarProvider((m, false)));
    }
  }
}

class _DashboardSummary extends StatelessWidget {
  const _DashboardSummary({required this.kinds, required this.onTap});

  final List<DashboardWidgetKind> kinds;
  final ValueChanged<DashboardWidgetKind> onTap;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final (int index, DashboardWidgetKind kind) in kinds.indexed) ...<Widget>[
            if (index > 0) const SizedBox(width: Insets.sm),
            Expanded(child: _SummaryTile(kind: kind, onTap: () => onTap(kind))),
          ],
        ],
      );
}

class _SummaryTile extends ConsumerWidget {
  const _SummaryTile({required this.kind, required this.onTap});

  final DashboardWidgetKind kind;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final (String label, int? count) = switch (kind) {
      DashboardWidgetKind.streams => (
          'Streams',
          ref.watch(activityStreamsProvider.select(
            (ActivityStreamsState state) =>
                state.streams.isEmpty && (state.anyLoading || state.errors.isNotEmpty)
                    ? null
                    : state.streams.length,
          )),
        ),
      DashboardWidgetKind.downloads => ('Downloads', ref.watch(activeDownloadCountProvider)),
      DashboardWidgetKind.upcoming => (
          'Today',
          ref.watch(dashboardUpcomingProvider.select(
            (DashboardUpcomingState state) =>
                state.todayCount == 0 && (state.loading || state.failed)
                    ? null
                    : state.todayCount,
          )),
        ),
      _ => throw StateError('No summary for ${kind.name}'),
    };
    final (Color surface, Color ink) = dashboardSectionColors(theme.colorScheme, kind);
    return Material(
      color: surface,
      borderRadius: const BorderRadiusDirectional.only(
        topStart: Radius.circular(26),
        topEnd: Radius.circular(18),
        bottomStart: Radius.circular(18),
        bottomEnd: Radius.circular(28),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Insets.sm),
          child: Column(
            children: <Widget>[
              Icon(kind.icon, color: ink, size: 19),
              const SizedBox(height: Insets.xs),
              Text(
                count?.toString() ?? '—',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelMedium?.copyWith(color: ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Edit mode: enabled widgets as a reorderable list of header tiles, hidden
/// widgets greyed out below with a re-add button.
class _EditBoard extends ConsumerWidget {
  const _EditBoard({required this.layout, required this.instances});

  final List<DashboardWidgetConfig> layout;
  final List<Instance> instances;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int wolCount =
        ref.watch(activeProfileProvider)?.wolDevices.length ?? 0;
    final List<DashboardWidgetConfig> enabled = <DashboardWidgetConfig>[
      for (final DashboardWidgetConfig c in layout)
        if (c.enabled) c,
    ];
    final List<DashboardWidgetConfig> hidden = <DashboardWidgetConfig>[
      for (final DashboardWidgetConfig c in layout)
        if (!c.enabled) c,
    ];

    return ReorderableListView(
      padding: Insets.page,
      buildDefaultDragHandles: false,
      onReorder: (int oldIndex, int newIndex) => ref
          .read(dashboardLayoutProvider.notifier)
          .moveEnabled(oldIndex, newIndex),
      footer: hidden.isEmpty
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Insets.md),
                  child: Text(
                    'Hidden',
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                for (final DashboardWidgetConfig c in hidden)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Insets.sm),
                    child: Opacity(
                      opacity: 0.6,
                      child: _EditTile(
                        config: c,
                        instances: instances,
                        wolDeviceCount: wolCount,
                        // Showing a widget nothing feeds puts it back on a
                        // board that filters it straight out again, which
                        // reads as the button having failed. The tile says
                        // which service it wants instead.
                        trailing: IconButton(
                          tooltip: _DashboardBoardState._configured(
                            c.kind,
                            instances,
                            wolDeviceCount: wolCount,
                          )
                              ? 'Show widget'
                              : 'Needs something that can fill it',
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed:
                              _DashboardBoardState._configured(
                            c.kind,
                            instances,
                            wolDeviceCount: wolCount,
                          )
                                  ? () => ref
                                      .read(dashboardLayoutProvider.notifier)
                                      .setEnabled(c.kind, true)
                                  : null,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
      children: <Widget>[
        for (int index = 0; index < enabled.length; index++)
          Padding(
            key: ValueKey<DashboardWidgetKind>(enabled[index].kind),
            padding: const EdgeInsets.only(bottom: Insets.sm),
            child: _EditTile(
              config: enabled[index],
              instances: instances,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  IconButton(
                    tooltip: 'Hide widget',
                    icon: const Icon(Icons.visibility_off_outlined),
                    onPressed: () => ref
                        .read(dashboardLayoutProvider.notifier)
                        .setEnabled(enabled[index].kind, false),
                  ),
                  ReorderableDragStartListener(
                    index: index,
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.drag_indicator),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Which services would make a widget work, as `Needs Sonarr or Radarr`.
///
/// A bare "Not configured" leaves someone to guess what is missing, which is
/// the whole reason a widget that can never fill looked broken rather than
/// unavailable.
String _needsLabel(DashboardWidgetKind kind) {
  if (kind.isDeviceBacked) {
    return 'Needs a device';
  }
  final List<String> names = <String>[
    for (final ServiceKind k in kind.serviceKinds) k.displayName,
  ];
  if (names.isEmpty) return 'Not configured';
  if (names.length == 1) return 'Needs ${names.single}';
  return 'Needs ${names.sublist(0, names.length - 1).join(', ')} '
      'or ${names.last}';
}

class _EditTile extends StatelessWidget {
  const _EditTile({
    required this.config,
    required this.instances,
    required this.trailing,
    this.wolDeviceCount = 0,
  });

  final DashboardWidgetConfig config;
  final List<Instance> instances;
  final Widget trailing;

  /// Wake-on-LAN is set up by adding devices, not a service, so its tile needs
  /// the device count to know whether it is configured.
  final int wolDeviceCount;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final bool configured = _DashboardBoardState._configured(
      config.kind,
      instances,
      wolDeviceCount: wolDeviceCount,
    );
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.md,
        vertical: Insets.sm,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(config.kind.icon, size: 20, color: cs.primary),
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  config.kind.label,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (!configured)
                  Text(
                    _needsLabel(config.kind),
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _KeepAliveWrapper extends StatefulWidget {
  final Widget child;

  const _KeepAliveWrapper({required this.child, super.key});

  @override
  State<_KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<_KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }

  @override
  bool get wantKeepAlive => true;
}
