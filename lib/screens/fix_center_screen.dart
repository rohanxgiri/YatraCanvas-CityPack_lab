import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../domain/curation/curated_place.dart';
import '../widgets/curation/category_editor_dialog.dart';
import '../widgets/curation/coordinate_editor_dialog.dart';
import '../widgets/curation/image_curator_dialog.dart';
import '../widgets/curation/opening_hours_editor_dialog.dart';
import '../widgets/report_problem_dialog.dart';

class FixCenterScreen extends StatefulWidget {
  final AppState state;
  final String initialCategory;

  const FixCenterScreen({
    super.key,
    required this.state,
    this.initialCategory = 'missing_hours',
  });

  @override
  State<FixCenterScreen> createState() => _FixCenterScreenState();
}

class _FixCenterScreenState extends State<FixCenterScreen> {
  late String _activeCategory;
  List<CuratedPlace> _places = [];
  bool _isLoading = true;
  int _currentIndex = 0;

  final Map<String, String> _categories = {
    'missing_hours': 'Missing Opening Hours',
    'missing_photos': 'Missing Hero Photos',
    'location_issues': 'Location & Boundary Issues',
    'duplicate_coords': 'Duplicate Coordinates',
    'open_issues': 'Community Flagged Issues',
  };

  @override
  void initState() {
    super.initState();
    _activeCategory = widget.initialCategory;
    _loadPlaces();
  }

  void _loadPlaces() async {
    setState(() => _isLoading = true);
    final repo = widget.state.repository;
    if (repo == null) return;

    List<CuratedPlace> list = [];

    switch (_activeCategory) {
      case 'missing_hours':
        final rawCore = await repo.getPlacesForGap(
          'core_missing_hours',
          limit: 50,
        );
        final rawAll = await repo.getPlacesForGap('missing_hours', limit: 50);
        final seen = <String>{};
        final combined = [
          ...rawCore,
          ...rawAll,
        ].where((p) => seen.add(p.id)).toList();
        list = combined
            .map((p) => widget.state.curationService.resolve(p))
            .where((p) => !p.hasOpeningHours && !p.isExcluded)
            .toList();
        break;
      case 'missing_photos':
        final rawCore = await repo.getPlacesForGap(
          'core_missing_images',
          limit: 50,
        );
        final rawAll = await repo.getPlacesForGap('missing_images', limit: 50);
        final seen = <String>{};
        final combined = [
          ...rawCore,
          ...rawAll,
        ].where((p) => seen.add(p.id)).toList();
        list = combined
            .map((p) => widget.state.curationService.resolve(p))
            .where((p) => !p.hasImage && !p.isExcluded)
            .toList();
        break;
      case 'location_issues':
        final rawOutliers = await repo.getPlacesForGap(
          'geo_outliers',
          limit: 50,
        );
        list = rawOutliers
            .map((p) => widget.state.curationService.resolve(p))
            .where((p) => !p.isExcluded)
            .toList();
        break;
      case 'duplicate_coords':
        final rawDups = await repo.getPlacesForGap(
          'duplicate_coords',
          limit: 50,
        );
        list = rawDups
            .map((p) => widget.state.curationService.resolve(p))
            .where((p) => !p.isExcluded)
            .toList();
        break;
      case 'open_issues':
        final issues = widget.state.curationService.issues.values
            .where((i) => i.isOpen)
            .toList();
        for (final isItem in issues) {
          final p = await widget.state.getCuratedPlaceById(isItem.placeId);
          if (p != null) list.add(p);
        }
        break;
    }

    if (mounted) {
      setState(() {
        _places = list;
        _currentIndex = 0;
        _isLoading = false;
      });
    }
  }

  void _next() {
    if (_currentIndex < _places.length - 1) {
      setState(() => _currentIndex++);
    } else {
      _loadPlaces(); // Reload to refresh list
    }
  }

  void _showFeedback(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.green.shade800,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final packName = widget.state.activePack?.name ?? 'City';

    return Scaffold(
      body: Column(
        children: [
          // Filter Chips Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _categories.entries.map((e) {
                  final selected = _activeCategory == e.key;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: selected,
                      label: Text(
                        e.value,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: selected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      selectedColor: Colors.indigo.shade100,
                      onSelected: (_) {
                        setState(() => _activeCategory = e.key);
                        _loadPlaces();
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Main Task Body
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _places.isEmpty
                ? _buildEmptyState()
                : _buildTaskRunner(packName),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskRunner(String packName) {
    final place = _places[_currentIndex];

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Fixing $packName — Issue ${_currentIndex + 1} of ${_places.length}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.indigo,
                ),
              ),
              Text(
                '${_places.length - _currentIndex} remaining in queue',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (_currentIndex + 1) / _places.length,
            backgroundColor: Colors.grey.shade200,
            valueColor: const AlwaysStoppedAnimation(Colors.indigo),
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
          const SizedBox(height: 20),

          // Actionable Place Card
          Expanded(
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: place.isCore
                                ? Colors.amber.shade100
                                : Colors.indigo.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            place.tier.replaceAll('_', ' ').toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: place.isCore
                                  ? Colors.amber.shade900
                                  : Colors.indigo.shade900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          place.category.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Text(
                      place.name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (place.address != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        place.address!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Issue Specific Highlight Box
                    _buildIssuePrompt(place),
                    const Spacer(),

                    // Action Controls
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.build, size: 18),
                            label: Text(_getActionLabel()),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            onPressed: () => _openFixDialog(place),
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.flag_outlined, size: 16),
                          label: const Text('Flag for later'),
                          onPressed: () {
                            ReportProblemDialog.show(
                              context,
                              place: place.toLabPlace(),
                              packVersion:
                                  widget.state.activePack?.version ?? 'v3',
                              onSubmit: (issue) async {
                                await widget.state.logCurationIssue(
                                  placeId: place.id,
                                  placeName: place.name,
                                  issueType: issue.issueType.code,
                                  note: issue.note,
                                );
                                _showFeedback(
                                  'Issue flagged for "${place.name}"',
                                );
                                _next();
                              },
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: _next,
                          child: const Text('Skip →'),
                        ),
                      ],
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

  Widget _buildIssuePrompt(CuratedPlace place) {
    IconData icon;
    Color color;
    String title;
    String description;

    switch (_activeCategory) {
      case 'missing_hours':
        icon = Icons.access_time;
        color = Colors.orange;
        title = 'Operating schedule is missing';
        description = 'Add daily opening hours so YatraCanvas can schedule this place into multi-day itineraries.';
        break;
      case 'missing_photos':
        icon = Icons.photo_camera_back;
        color = Colors.teal;
        title = 'Hero photo is missing';
        description = 'Attach an open-licensed photo from Wikimedia Commons or official tourism source.';
        break;
      case 'location_issues':
        icon = Icons.pin_drop;
        color = Colors.deepOrange;
        title = 'Coordinates outside expected region';
        description =
            'Current coordinates (${place.latitude.toStringAsFixed(4)}, ${place.longitude.toStringAsFixed(4)}) appear misplaced.';
        break;
      case 'duplicate_coords':
        icon = Icons.copy;
        color = Colors.purple;
        title = 'Identical coordinates cluster';
        description = 'Multiple POIs are pinned at the exact same latitude and longitude. Adjust pin location or exclude duplicate.';
        break;
      default:
        icon = Icons.warning_amber_rounded;
        color = Colors.red;
        title = 'Action required';
        description =
            'Review place details and resolve open community defect flags.';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: color.withAlpha(255),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getActionLabel() {
    switch (_activeCategory) {
      case 'missing_hours':
        return 'Enter Opening Hours';
      case 'missing_photos':
        return 'Attach Photo';
      case 'location_issues':
      case 'duplicate_coords':
        return 'Adjust Coordinates';
      default:
        return 'Fix Issue Now';
    }
  }

  void _openFixDialog(CuratedPlace place) {
    switch (_activeCategory) {
      case 'missing_hours':
        OpeningHoursEditorDialog.show(
          context,
          place: place,
          onSave: ({required openingHours, required evidenceSource}) async {
            await widget.state.saveFieldOverride(
              place: place.toLabPlace(),
              openingHours: openingHours,
              fieldName: 'opening_hours',
              evidenceSource: evidenceSource,
              previousValue: place.rawPlace?.openingHours,
            );
            _showFeedback('Opening hours saved for "${place.name}"');
            _next();
          },
        );
        break;
      case 'missing_photos':
        ImageCuratorDialog.show(
          context,
          place: place,
          onImport: (selection) async {
            await widget.state.importPlaceImage(
              place: place.toLabPlace(),
              sourceBytes: selection.bytes,
              originalFilename: selection.filename,
              source: selection.source,
              sourcePage: selection.sourcePage,
              license: selection.license,
              licenseUrl: selection.licenseUrl,
            );
            _showFeedback('Photo imported for "${place.name}"');
            _next();
          },
          onSave: ({required primaryImagePath, required evidenceSource}) async {
            await widget.state.saveFieldOverride(
              place: place.toLabPlace(),
              primaryImagePath: primaryImagePath,
              fieldName: 'primary_image_path',
              evidenceSource: evidenceSource,
              previousValue: place.rawPlace?.primaryImagePath,
            );
            _showFeedback('Photo attached for "${place.name}"');
            _next();
          },
          onFlag: (type, note) async {
            await widget.state.logCurationIssue(
              placeId: place.id,
              placeName: place.name,
              issueType: type,
              note: note,
            );
            _next();
          },
        );
        break;
      case 'location_issues':
      case 'duplicate_coords':
        CoordinateEditorDialog.show(
          context,
          place: place,
          bbox: widget.state.qualityStats?['bbox'] as Map<String, dynamic>?,
          onSave:
              ({
                required latitude,
                required longitude,
                required evidenceSource,
              }) async {
                await widget.state.saveFieldOverride(
                  place: place.toLabPlace(),
                  latitude: latitude,
                  longitude: longitude,
                  fieldName: 'coordinates',
                  evidenceSource: evidenceSource,
                  previousValue: '${place.latitude}, ${place.longitude}',
                );
                _showFeedback('Coordinates updated for "${place.name}"');
                _next();
              },
        );
        break;
      default:
        CategoryEditorDialog.show(
          context,
          place: place,
          onSave:
              ({
                required category,
                subcategory,
                required evidenceSource,
              }) async {
                await widget.state.saveFieldOverride(
                  place: place.toLabPlace(),
                  category: category,
                  subcategory: subcategory,
                  fieldName: 'category',
                  evidenceSource: evidenceSource,
                );
                _showFeedback('Category updated for "${place.name}"');
                _next();
              },
        );
        break;
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
          const SizedBox(height: 16),
          Text(
            'No ${_categories[_activeCategory]} Issues!',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'All places in this category currently satisfy quality standards.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: _loadPlaces,
            child: const Text('Refresh Category'),
          ),
        ],
      ),
    );
  }
}
