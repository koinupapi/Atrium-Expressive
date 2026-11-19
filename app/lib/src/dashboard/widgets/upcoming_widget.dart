import 'package:core_router/core_router.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../screens/calendar_screen.dart';
import '../dashboard_widget_card.dart';
import '../dashboard_widget_kind.dart';

/// First-of-month keys for every month the [now, now+7d] window touches.
List<DateTime> upcomingWindowMonths(DateTime now) {
  final DateTime start = DateTime(now.year, now.month, 1);
  final DateTime end =
      DateTime(now.year, now.month, now.day + 8);
  final DateTime endMonth = DateTime(end.year, end.month, 1);
  return <DateTime>[start, if (endMonth != start) endMonth];
}

typedef DashboardUpcomingState = ({
  List<CalendarEvent> events,
  bool loading,
  bool failed,
  int todayCount,
});

final dashboardUpcomingProvider = Provider.autoDispose<DashboardUpcomingState>(
  (Ref ref) {
    final DateTime now = DateTime.now();
    final DateTime windowStart = DateTime(now.year, now.month, now.day);
    final DateTime windowEnd = DateTime(now.year, now.month, now.day + 8);
    final List<DateTime> months = upcomingWindowMonths(now);

    final List<CalendarEvent> events = <CalendarEvent>[];
    final Set<CalendarEvent> seen = <CalendarEvent>{};
    bool anyLoading = false;
    bool anyError = false;
    for (final DateTime month in months) {
      final AsyncValue<List<CalendarEvent>> value =
          ref.watch(globalCalendarProvider((month, false)));
      anyLoading |= value.isLoading && !value.hasValue;
      anyError |= value.hasError;
      for (final CalendarEvent e in value.value ?? const <CalendarEvent>[]) {
        if (seen.add(e)) {
          events.add(e);
        }
      }
    }

    final List<CalendarEvent> upcoming = events.where((CalendarEvent e) {
      final DateTime d = e.date.toLocal();
      return !d.isBefore(windowStart) && d.isBefore(windowEnd);
    }).toList()
      ..sort((CalendarEvent a, CalendarEvent b) => a.date.compareTo(b.date));
    return (
      events: upcoming,
      loading: anyLoading,
      failed: anyError,
      todayCount: upcoming.where((CalendarEvent event) {
        final DateTime local = event.date.toLocal();
        return DateUtils.isSameDay(local, now);
      }).length,
    );
  },
);

class DashboardUpcomingWidget extends ConsumerWidget {
  const DashboardUpcomingWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final DashboardUpcomingState state = ref.watch(dashboardUpcomingProvider);
    final List<CalendarEvent> upcoming = state.events;
    final DateTime now = DateTime.now();
    final DateTime windowStart = DateTime(now.year, now.month, now.day);
    final List<CalendarEvent> top = upcoming.take(3).toList();


    Widget body;
    if (upcoming.isEmpty && state.loading) {
      body = const Center(
        child: Padding(
          padding: EdgeInsets.all(Insets.sm),
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    } else if (upcoming.isEmpty && state.failed) {
      body = DashboardErrorRow(
        onRetry: () {
          for (final DateTime m in upcomingWindowMonths(now)) {
            ref.invalidate(globalCalendarProvider((m, false)));
          }
        },
      );
    } else if (upcoming.isEmpty) {
      body = const DashboardIdleRow(text: 'Nothing airing in the next 7 days');
    } else {
      final List<Widget> rows = <Widget>[];
      DateTime? lastDay;
      for (final CalendarEvent e in top) {
        final DateTime d = e.date.toLocal();
        final DateTime day = DateTime(d.year, d.month, d.day);
        if (lastDay == null || day != lastDay) {
          lastDay = day;
          final bool isToday = day == windowStart;
          rows.add(Padding(
            padding: EdgeInsets.only(
              top: rows.isEmpty ? 2 : Insets.md,
              bottom: Insets.sm,
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isToday ? cs.onTertiaryContainer : cs.outline,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: Insets.sm),
                Text(
                  _dayLabel(day, windowStart),
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isToday ? cs.onTertiaryContainer : cs.onSurface,
                  ),
                ),
                const SizedBox(width: Insets.md),
                Expanded(child: Container(height: 1, color: cs.outlineVariant)),
              ],
            ),
          ));
        } else {
          rows.add(const SizedBox(height: Insets.sm));
        }
        rows.add(_ReleaseRow(event: e));
      }
      rows.add(
        TextButton.icon(
          onPressed: () => context.goNamed(AtriumRoutes.calendarName),
          icon: const Icon(Icons.calendar_today_outlined),
          label: const Text('Open calendar'),
        ),
      );
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows,
      );
    }

    return DashboardWidgetCard(
      kind: DashboardWidgetKind.upcoming,
      accent: cs.onTertiaryContainer,
      trailing: upcoming.isNotEmpty
          ? DashboardPill(
              icon: Icons.calendar_today_outlined,
              label:
                  '${upcoming.length} release${upcoming.length == 1 ? '' : 's'}',
              color: cs.onTertiaryContainer,
            )
          : null,
      child: body,
    );
  }

  static String _dayLabel(DateTime day, DateTime today) {
    if (day == today) {
      return 'Today';
    }
    if (day == DateTime(today.year, today.month, today.day + 1)) {
      return 'Tomorrow';
    }
    return DateFormat('EEE, MMM d').format(day);
  }
}

/// Text sits on a quiet surface; a service label identifies its source.
class _ReleaseRow extends StatelessWidget {
  const _ReleaseRow({required this.event});

  final CalendarEvent event;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final bool episode = event is SonarrCalendarEvent;
    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Icon(episode ? Icons.tv_rounded : Icons.movie_outlined),
        title: Text(event.primaryTitle, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          <String>[
            event.subtitle,
            if (episode) DateFormat.jm().format(event.date.toLocal()),
            if (event.hasFile) 'Downloaded',
          ].join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          episode ? 'Sonarr' : 'Radarr',
          style: theme.textTheme.labelMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        onTap: () => context.goNamed(AtriumRoutes.calendarName),
      ),
    );
  }
}
