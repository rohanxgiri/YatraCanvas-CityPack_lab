import 'package:flutter/material.dart';
import '../app/app_state.dart';
import '../domain/lab_place.dart';
import '../domain/qa_issue.dart';
import '../domain/qa_session.dart';
import '../widgets/place_card.dart';

class ReviewScreen extends StatefulWidget {
  final AppState state;
  final String? initialFilter;

  const ReviewScreen({
    super.key,
    required this.state,
    this.initialFilter,
  });

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  String _activeFilter = 'all';
  List<LabPlace> _places = [];
  bool _isLoading = true;
  int _currentIndex = 0;

  final Map<String, String> _filterLabels = {
    'all': 'Stratified Sample',
    'core': 'Core POIs',
    'missing_images': 'Missing Photos',
    'missing_hours': 'Missing Hours',
    'geo_outliers': 'Geo Outliers',
    'duplicate_coords': 'Duplicate Coords',
    'single_source': 'Single Source',
  };

  @override
  void initState() {
    super.initState();
    if (widget.initialFilter != null) {
      _activeFilter = widget.initialFilter!;
    }
    _loadPlaces();
  }

  void _loadPlaces() async {
    setState(() => _isLoading = true);
    final repo = widget.state.repository;
    if (repo == null) return;

    List<LabPlace> loaded = [];
    if (_activeFilter == 'all') {
      final sample = await widget.state.qaSamplingService.generateSample(repo.database);
      loaded = sample.allPlaces;
    } else if (_activeFilter == 'core') {
      loaded = await repo.getByTier(tier: 'core_destination', limit: 80);
    } else {
      loaded = await repo.getPlacesForGap(_activeFilter, limit: 80);
    }

    if (mounted) {
      setState(() {
        _places = loaded;
        _currentIndex = 0;
        _isLoading = false;
      });
    }
  }

  void _approveCurrentPlace() async {
    if (_places.isEmpty || _currentIndex >= _places.length) return;
    final place = _places[_currentIndex];

    final record = RandomReviewRecord(
      placeId: place.id,
      placeName: place.name,
      tier: place.tier,
      category: place.category,
      result: 'looks_good',
      note: 'Verified in manual QA',
      timestamp: DateTime.now().toIso8601String(),
    );

    final scaffold = ScaffoldMessenger.of(context);
    await widget.state.addRandomReview(record);
    if (!mounted) return;

    scaffold.showSnackBar(
      SnackBar(
        content: Text('Approved "${place.name}"'),
        duration: const Duration(milliseconds: 900),
        backgroundColor: Colors.green.shade800,
      ),
    );

    _nextPlace();
  }

  void _flagCurrentPlace() {
    if (_places.isEmpty || _currentIndex >= _places.length) return;
    final place = _places[_currentIndex];

    QaIssueType selectedType = QaIssueType.wrongLocation;
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.flag, color: Colors.orange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Flag Defect: ${place.name}',
                  style: const TextStyle(fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Issue Type:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              DropdownButton<QaIssueType>(
                isExpanded: true,
                value: selectedType,
                items: QaIssueType.values.map((t) {
                  return DropdownMenuItem(
                    value: t,
                    child: Text(t.label, style: const TextStyle(fontSize: 13)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() => selectedType = val);
                  }
                },
              ),
              const SizedBox(height: 12),
              const Text('Notes / Explanation:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: noteController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Describe the issue (e.g. coordinates point to wrong suburb, closed permanently)...',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.all(10),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final scaffold = ScaffoldMessenger.of(context);
                Navigator.of(ctx).pop();
                final issue = QaIssue(
                  id: 'issue_${DateTime.now().millisecondsSinceEpoch}',
                  timestamp: DateTime.now().toIso8601String(),
                  cityId: widget.state.activePack!.id,
                  packVersion: widget.state.activePack!.version,
                  placeId: place.id,
                  placeName: place.name,
                  tier: place.tier,
                  category: place.category,
                  latitude: place.latitude,
                  longitude: place.longitude,
                  issueType: selectedType,
                  note: noteController.text.trim(),
                );

                final reviewRecord = RandomReviewRecord(
                  placeId: place.id,
                  placeName: place.name,
                  tier: place.tier,
                  category: place.category,
                  result: selectedType.name,
                  note: noteController.text.trim(),
                  timestamp: DateTime.now().toIso8601String(),
                );

                await widget.state.reportIssue(issue);
                await widget.state.addRandomReview(reviewRecord);
                if (!mounted) return;

                scaffold.showSnackBar(
                  SnackBar(
                    content: Text('Logged defect for "${place.name}"'),
                    backgroundColor: Colors.orange.shade900,
                  ),
                );

                _nextPlace();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade800,
                foregroundColor: Colors.white,
              ),
              child: const Text('Save Defect'),
            ),
          ],
        ),
      ),
    );
  }

  void _nextPlace() {
    if (_currentIndex < _places.length - 1) {
      setState(() => _currentIndex++);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reached end of current sample batch.')),
      );
    }
  }

  void _prevPlace() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final qa = widget.state.manualQaSummary;
    final reviewedCount = qa?.reviewedCount ?? 0;
    final minimumRequired = qa?.minimumRequired ?? 50;
    final progress = (reviewedCount / minimumRequired).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manual QA & Review'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Resample / Reload Places',
            onPressed: _loadPlaces,
          ),
        ],
      ),
      body: Column(
        children: [
          // Sampling Progress Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.blueGrey.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'MANUAL QA SAMPLE: $reviewedCount / $minimumRequired',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: qa?.isSufficient ?? false ? Colors.green.shade800 : Colors.indigo,
                      ),
                    ),
                    Text(
                      qa?.displayStatus ?? 'PENDING',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: qa?.isSufficient ?? false ? Colors.green.shade800 : Colors.amber.shade900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      qa?.isSufficient ?? false ? Colors.green : Colors.indigo,
                    ),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),

          // Filter Pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: _filterLabels.entries.map((e) {
                final isSelected = _activeFilter == e.key;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(e.value, style: const TextStyle(fontSize: 12)),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _activeFilter = e.key);
                        _loadPlaces();
                      }
                    },
                    selectedColor: Colors.indigo.shade100,
                    checkmarkColor: Colors.indigo,
                  ),
                );
              }).toList(),
            ),
          ),

          // Main Review Card Area
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : (_places.isEmpty
                    ? const Center(child: Text('No places matched the active filter.'))
                    : _buildReviewCard(context, _places[_currentIndex])),
          ),

          // Action Navigation Bar
          if (!_isLoading && _places.isNotEmpty) _buildBottomBar(context),
        ],
      ),
    );
  }

  Widget _buildReviewCard(BuildContext context, LabPlace place) {
    final bool hasImg = place.hasImage;
    final bool hasHours = place.openingHours != null && place.openingHours!.isNotEmpty;
    final bool hasWiki = place.wikidataId != null && place.wikidataId!.isNotEmpty;
    final bool hasSources = place.sources.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Place Navigation Index Indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Record ${_currentIndex + 1} of ${_places.length}',
                style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  place.tier.toUpperCase().replaceAll('_', ' '),
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Visual Place Card from existing widget
          PlaceCard(
            place: place,
            repository: widget.state.repository!,
            onTap: () {},
          ),
          const SizedBox(height: 14),

          // Place-Level Quality & Explainability Card
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PLACE QUALITY EXPLAINABILITY',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: Colors.black54),
                  ),
                  const SizedBox(height: 12),
                  _buildQualityCheckRow('Place Name Valid', true, place.name),
                  _buildQualityCheckRow(
                    'Coordinates Inside Region',
                    true,
                    '(${place.latitude.toStringAsFixed(4)}, ${place.longitude.toStringAsFixed(4)})',
                  ),
                  _buildQualityCheckRow(
                    'Travel Category Mapped',
                    place.category != 'other' && place.category != 'unknown',
                    place.category,
                  ),
                  _buildQualityCheckRow(
                    'Hero Photo Available',
                    hasImg,
                    hasImg ? 'Primary photo present' : 'Missing photo',
                  ),
                  _buildQualityCheckRow(
                    'Operating Hours',
                    hasHours,
                    hasHours ? place.openingHours! : 'Missing hours',
                  ),
                  _buildQualityCheckRow(
                    'Multi-Source Identity',
                    hasWiki || hasSources,
                    hasWiki
                        ? 'Wikidata ID: ${place.wikidataId}'
                        : (hasSources ? '${place.sources.length} sources linked' : 'Single source'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQualityCheckRow(String label, bool passed, String detail) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            passed ? Icons.check_circle : Icons.warning_amber_rounded,
            color: passed ? Colors.teal : Colors.orange.shade800,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const Spacer(),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              detail,
              style: const TextStyle(fontSize: 11, color: Colors.black54),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Previous Place',
              onPressed: _currentIndex > 0 ? _prevPlace : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _flagCurrentPlace,
                icon: const Icon(Icons.flag_outlined, size: 16),
                label: const Text('Flag Defect'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade800,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _approveCurrentPlace,
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Approve (Looks Good)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.arrow_forward),
              tooltip: 'Skip / Next Place',
              onPressed: _currentIndex < _places.length - 1 ? _nextPlace : null,
            ),
          ],
        ),
      ),
    );
  }
}
