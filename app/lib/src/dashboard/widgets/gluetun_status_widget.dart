import 'package:core_models/core_models.dart';
import 'package:core_router/core_router.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:service_gluetun/service_gluetun.dart';

import '../dashboard_widget_card.dart';

class DashboardGluetunStatusWidget extends StatelessWidget {
  const DashboardGluetunStatusWidget({
    required this.instances,
    super.key,
  });

  final List<Instance> instances;

  @override
  Widget build(BuildContext context) => Column(
        children: <Widget>[
          for (final Instance instance in instances)
            Padding(
              padding: const EdgeInsets.only(bottom: Insets.xs),
              child: _GluetunRow(
                key: ValueKey<String>(instance.id),
                instance: instance,
                showName: instances.length > 1,
              ),
            ),
        ],
      );
}

class _GluetunRow extends ConsumerWidget {
  const _GluetunRow({required this.instance, required this.showName, super.key});

  final Instance instance;
  final bool showName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<GluetunVpnStatus> status =
        ref.watch(gluetunVpnStatusProvider(instance));
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final bool running = status.value?.isRunning ?? false;
    final (String label, IconData icon, Color ink) = switch (status) {
      _ when status.hasValue && running => (
          'Running',
          Icons.check_circle_outline,
          theme.brightness == Brightness.dark
              ? const Color(0xFF91DBA7)
              : const Color(0xFF166437),
        ),
      _ when status.hasValue => (
          status.value?.status ?? 'Unknown',
          Icons.error_outline,
          colors.error,
        ),
      _ when status.hasError => (
          'Unavailable',
          Icons.error_outline,
          colors.error,
        ),
      _ => ('Checking…', Icons.schedule, colors.onSurfaceVariant),
    };
    return Material(
      borderRadius: BorderRadius.circular(24),
      color: colors.surfaceContainerHigh,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: const Icon(Icons.shield_outlined),
        title: const Text('Gluetun VPN'),
        subtitle: showName ? Text(instance.name) : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            DashboardPill(icon: icon, label: label, color: ink),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () => context.go(
          AtriumRoutes.servicePath(instance.kind.name, instance.id),
        ),
      ),
    );
  }
}
