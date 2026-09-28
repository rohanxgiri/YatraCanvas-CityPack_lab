import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../app/lab_theme.dart';
import '../domain/city_pack.dart';
import 'city_lab_home_screen.dart';
import 'diagnostics_screen.dart';

class CityPackScreen extends StatelessWidget {
  final AppState state;

  const CityPackScreen({super.key, required this.state});

  Future<void> _openPack(BuildContext context, CityPack pack) async {
    if (!pack.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('This pack cannot open: ${pack.invalidReason}')),
      );
      return;
    }
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _OpeningPackDialog(),
    );
    try {
      await state.openPack(pack);
      if (!context.mounted) return;
      Navigator.of(context).pop();
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CityLabHomeScreen(state: state),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('The pack could not be opened: $error')),
      );
    }
  }

  void _showPackMetadata(BuildContext context, CityPack pack) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.66,
        minChildSize: 0.42,
        maxChildSize: 0.92,
        expand: false,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(
            LabSpacing.lg,
            0,
            LabSpacing.lg,
            LabSpacing.xl,
          ),
          children: [
            Text(
              '${pack.name} pack details',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: LabSpacing.sm),
            const Text(
              'Technical pack metadata is kept here so the main contributor journey stays focused.',
            ),
            const SizedBox(height: LabSpacing.lg),
            _MetadataRow(label: 'City ID', value: pack.id),
            _MetadataRow(
              label: 'State and country',
              value: '${pack.state}, ${pack.country}',
            ),
            _MetadataRow(label: 'Pack version', value: pack.version),
            _MetadataRow(
              label: 'Integrity',
              value: pack.integrityStatus.name.toUpperCase(),
            ),
            _MetadataRow(label: 'Places', value: '${pack.placeCount}'),
            _MetadataRow(label: 'Local images', value: '${pack.imageCount}'),
            _MetadataRow(label: 'Database size', value: '${pack.dbSizeMb} MB'),
            _MetadataRow(
              label: 'Centre',
              value:
                  '${pack.centerLat.toStringAsFixed(5)}, ${pack.centerLon.toStringAsFixed(5)}',
            ),
            _MetadataRow(
              label: 'Bounding box',
              value:
                  '${pack.minLon.toStringAsFixed(3)}, ${pack.minLat.toStringAsFixed(3)}, ${pack.maxLon.toStringAsFixed(3)}, ${pack.maxLat.toStringAsFixed(3)}',
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.route_outlined),
            SizedBox(width: LabSpacing.sm),
            Text('YatraCanvas CityPack Lab'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            tooltip: 'Open diagnostics',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => DiagnosticsScreen(state: state),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload packs',
            onPressed: state.loadPacks,
          ),
          const SizedBox(width: LabSpacing.xs),
        ],
      ),
      body: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          if (state.isLoadingPacks) return const _PackLoadingState();
          if (state.packLoadError != null) {
            return _PackErrorState(
              message: state.packLoadError!,
              onRetry: state.loadPacks,
            );
          }
          if (state.availablePacks.isEmpty) {
            return _EmptyPackState(onRetry: state.loadPacks);
          }

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: ColoredBox(
                  color: LabPalette.inkStrong,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1180),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: LabSpacing.lg,
                          vertical: LabSpacing.xxl,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: LabSpacing.sm,
                                vertical: LabSpacing.xs,
                              ),
                              decoration: BoxDecoration(
                                color: LabPalette.teal,
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Text(
                                kIsWeb
                                    ? 'BROWSER REVIEW MODE'
                                    : 'DESKTOP CURATION MODE',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            const SizedBox(height: LabSpacing.md),
                            Text(
                              'Choose a city.\nMake it ready to travel.',
                              style: Theme.of(context).textTheme.displaySmall
                                  ?.copyWith(color: Colors.white),
                            ),
                            const SizedBox(height: LabSpacing.sm),
                            Text(
                              'Inspect the DataFactory pack, fix editorial gaps outside the source database, complete the 50 place review, and certify the release.',
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: Padding(
                      padding: const EdgeInsets.all(LabSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _OperatingModeNotice(isWeb: kIsWeb),
                          const SizedBox(height: LabSpacing.lg),
                          Text(
                            'Available city packs',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: LabSpacing.xs),
                          Text(
                            '${state.availablePacks.length} local packs are ready for inspection.',
                          ),
                          const SizedBox(height: LabSpacing.md),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final columns = constraints.maxWidth >= 900
                                  ? 3
                                  : constraints.maxWidth >= 580
                                  ? 2
                                  : 1;
                              const gap = LabSpacing.md;
                              final width =
                                  (constraints.maxWidth - (columns - 1) * gap) /
                                  columns;
                              return Wrap(
                                spacing: gap,
                                runSpacing: gap,
                                children: state.availablePacks
                                    .map(
                                      (pack) => SizedBox(
                                        width: width,
                                        child: _PackCard(
                                          pack: pack,
                                          onOpen: () =>
                                              _openPack(context, pack),
                                          onDetails: () =>
                                              _showPackMetadata(context, pack),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PackCard extends StatelessWidget {
  final CityPack pack;
  final VoidCallback onOpen;
  final VoidCallback onDetails;

  const _PackCard({
    required this.pack,
    required this.onOpen,
    required this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    final valid = pack.isValid;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(LabSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pack.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: LabSpacing.xxs),
                      Text('${pack.state}, ${pack.country}'),
                    ],
                  ),
                ),
                _IntegrityBadge(valid: valid),
              ],
            ),
            const SizedBox(height: LabSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: _PackStat(
                    icon: Icons.place_outlined,
                    value: '${pack.placeCount}',
                    label: 'places',
                  ),
                ),
                Expanded(
                  child: _PackStat(
                    icon: Icons.photo_outlined,
                    value: '${pack.imageCount}',
                    label: 'images',
                  ),
                ),
                Expanded(
                  child: _PackStat(
                    icon: Icons.tag,
                    value: pack.version,
                    label: 'version',
                  ),
                ),
              ],
            ),
            const SizedBox(height: LabSpacing.lg),
            Row(
              children: [
                IconButton(
                  onPressed: onDetails,
                  tooltip: 'View pack details',
                  icon: const Icon(Icons.info_outline),
                ),
                const SizedBox(width: LabSpacing.xs),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: valid ? onOpen : null,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Open workbench'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PackStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _PackStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: LabPalette.teal),
        const SizedBox(height: LabSpacing.xxs),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _IntegrityBadge extends StatelessWidget {
  final bool valid;

  const _IntegrityBadge({required this.valid});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: LabSpacing.xs,
        vertical: LabSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: valid ? LabPalette.successSoft : LabPalette.dangerSoft,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            valid ? Icons.check_circle_outline : Icons.error_outline,
            size: 16,
            color: valid ? LabPalette.success : LabPalette.danger,
          ),
          const SizedBox(width: LabSpacing.xxs),
          Text(
            valid ? 'PASS' : 'INVALID',
            style: TextStyle(
              color: valid ? LabPalette.success : LabPalette.danger,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _OperatingModeNotice extends StatelessWidget {
  final bool isWeb;

  const _OperatingModeNotice({required this.isWeb});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(LabSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: isWeb
                  ? LabPalette.saffronSoft
                  : LabPalette.tealSoft,
              foregroundColor: LabPalette.ink,
              child: Icon(
                isWeb ? Icons.visibility_outlined : Icons.edit_note_outlined,
              ),
            ),
            const SizedBox(width: LabSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isWeb ? 'Review in the browser' : 'Curate on this desktop',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: LabSpacing.xxs),
                  Text(
                    isWeb
                        ? 'SQLite inspection and QA work here. Importing photos and writing Git tracked curation files requires the desktop app.'
                        : 'The original SQLite pack stays immutable. Your fixes are written as reviewable curation files beside it.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetadataRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetadataRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: LabSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 148, child: Text(label)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _OpeningPackDialog extends StatelessWidget {
  const _OpeningPackDialog();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(LabSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: LabSpacing.md),
              Text('Opening the read only city pack…'),
            ],
          ),
        ),
      ),
    );
  }
}

class _PackLoadingState extends StatelessWidget {
  const _PackLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: LabSpacing.md),
          Text('Finding local city packs…'),
        ],
      ),
    );
  }
}

class _PackErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _PackErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return _StateMessage(
      icon: Icons.error_outline,
      title: 'City packs could not load',
      message: message,
      actionLabel: 'Try again',
      onAction: onRetry,
    );
  }
}

class _EmptyPackState extends StatelessWidget {
  final VoidCallback onRetry;

  const _EmptyPackState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return _StateMessage(
      icon: Icons.inventory_2_outlined,
      title: 'No city packs found',
      message: 'Sync a production pack from YatraCanvas DataFactory, then check again.',
      actionLabel: 'Check again',
      onAction: onRetry,
    );
  }
}

class _StateMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const _StateMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(LabSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 52, color: LabPalette.teal),
              const SizedBox(height: LabSpacing.md),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: LabSpacing.xs),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: LabSpacing.lg),
              ElevatedButton(onPressed: onAction, child: Text(actionLabel)),
            ],
          ),
        ),
      ),
    );
  }
}
