import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../app/app_state.dart';
import '../domain/lab_place.dart';
import '../widgets/report_problem_dialog.dart';
import 'map_screen.dart';

class PlaceDetailScreen extends StatefulWidget {
  final LabPlace place;
  final AppState state;

  const PlaceDetailScreen({
    super.key,
    required this.place,
    required this.state,
  });

  @override
  State<PlaceDetailScreen> createState() => _PlaceDetailScreenState();
}

class _PlaceDetailScreenState extends State<PlaceDetailScreen> {
  late LabPlace _place;
  bool _isQaMode = false;

  @override
  void initState() {
    super.initState();
    _place = widget.place;
    _loadFullDetails();
  }

  void _loadFullDetails() async {
    final repo = widget.state.repository;
    if (repo == null) return;

    final full = await repo.getPlaceById(widget.place.id);
    if (mounted && full != null) {
      setState(() {
        _place = full;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isInTrip = widget.state.tripSelection?.contains(_place.id) ?? false;
    final File? localImgFile = kIsWeb
        ? null
        : widget.state.repository?.resolveImage(_place.primaryImagePath);

    return Scaffold(
      appBar: AppBar(
        title: Text(_place.name),
        actions: [
          IconButton(
            icon: Icon(
              _isQaMode ? Icons.bug_report : Icons.bug_report_outlined,
              color: _isQaMode ? Colors.amberAccent : Colors.white,
            ),
            tooltip: 'Toggle QA Inspector Mode',
            onPressed: () {
              setState(() => _isQaMode = !_isQaMode);
            },
          ),
          IconButton(
            icon: const Icon(Icons.flag_outlined),
            tooltip: 'Report Problem',
            onPressed: () {
              ReportProblemDialog.show(
                context,
                place: _place,
                packVersion: widget.state.activePack?.version ?? 'v3',
                onSubmit: (issue) => widget.state.reportIssue(issue),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Header or Missing Image Placeholder
            SizedBox(
              height: 240,
              width: double.infinity,
              child: localImgFile != null
                  ? Image.file(
                      localImgFile,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, stack) => _buildPlaceholder(),
                    )
                  : (kIsWeb && _place.primaryImagePath != null && _place.primaryImagePath!.isNotEmpty
                      ? Image.asset(
                          'assets/city_packs/${_place.cityId}/${_place.primaryImagePath}',
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, err, stack) => _buildPlaceholder(),
                        )
                      : _buildPlaceholder()),
            ),

            // QA Mode Banner if active
            if (_isQaMode)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.amber.shade100,
                child: Row(
                  children: [
                    Icon(Icons.shield_outlined,
                        size: 18, color: Colors.amber.shade900),
                    const SizedBox(width: 8),
                    Text(
                      'QA DATA INSPECTION MODE (Raw DataFactory Fields)',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade900),
                    ),
                  ],
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tier & Category badges
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.amber.shade700),
                        ),
                        child: Text(
                          _place.tier.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _place.category.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey.shade900,
                          ),
                        ),
                      ),
                      if (_place.subcategory != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          '• ${_place.subcategory}',
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey.shade700),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Name & Hindi Name
                  Text(
                    _place.name,
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  if (_place.nameHi != null && _place.nameHi!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      _place.nameHi!,
                      style: TextStyle(
                          fontSize: 16,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey.shade700),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (isInTrip) {
                              widget.state.removePlaceFromTrip(_place.id);
                            } else {
                              widget.state.addPlaceToTrip(_place.id);
                            }
                            setState(() {});
                          },
                          icon: Icon(isInTrip ? Icons.check : Icons.add_location_alt),
                          label: Text(isInTrip ? 'In Test Trip' : 'Add to Trip'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                isInTrip ? Colors.teal.shade700 : Colors.indigo,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => MapScreen(
                                state: widget.state,
                                initialFocusPlace: _place,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.map_outlined),
                        label: const Text('Map'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () {
                          ReportProblemDialog.show(
                            context,
                            place: _place,
                            packVersion:
                                widget.state.activePack?.version ?? 'v3',
                            onSubmit: (issue) =>
                                widget.state.reportIssue(issue),
                          );
                        },
                        icon: const Icon(Icons.flag_outlined, color: Colors.red),
                        label: const Text('Report',
                            style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),

                  const Divider(height: 32),

                  // Normal Traveler Information
                  _buildSectionHeader('Place Overview'),
                  if (_place.address != null && _place.address!.isNotEmpty)
                    _infoRow(Icons.location_on, 'Address', _place.address!),
                  _infoRow(Icons.gps_fixed, 'Coordinates',
                      '${_place.latitude.toStringAsFixed(5)}, ${_place.longitude.toStringAsFixed(5)}'),
                  if (_place.openingHours != null &&
                      _place.openingHours!.isNotEmpty)
                    _infoRow(Icons.access_time, 'Opening Hours',
                        _place.openingHours!),
                  if (_place.recommendedVisitMinutes != null)
                    _infoRow(Icons.timer, 'Recommended Visit',
                        '${_place.recommendedVisitMinutes} minutes'),
                  if (_place.bestTime != null && _place.bestTime!.isNotEmpty)
                    _infoRow(Icons.wb_sunny_outlined, 'Best Time',
                        _place.bestTime!),
                  if (_place.website != null && _place.website!.isNotEmpty)
                    _infoRow(Icons.language, 'Website', _place.website!),
                  if (_place.phone != null && _place.phone!.isNotEmpty)
                    _infoRow(Icons.phone, 'Phone', _place.phone!),

                  if (_place.tags.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('Tags:',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _place.tags.map((t) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('#$t',
                              style: const TextStyle(fontSize: 11)),
                        );
                      }).toList(),
                    ),
                  ],

                  // QA Mode Detailed Data Inspection (Phase 14)
                  if (_isQaMode) ...[
                    const Divider(height: 40, thickness: 2),
                    _buildSectionHeader('QA Metadata & Schema Inspection'),
                    _qaRow('Canonical ID', _place.id),
                    _qaRow('City ID', _place.cityId),
                    _qaRow('Primary Entity Type', _place.primaryEntityType ?? 'null'),
                    _qaRow('Category / Subcategory', '${_place.category} / ${_place.subcategory ?? "null"}'),
                    _qaRow('Tier', _place.tier),
                    _qaRow('Travel Relevance Score', '${_place.travelRelevanceScore}'),
                    _qaRow('Prominence Score', '${_place.prominenceScore}'),
                    _qaRow('Tourism Priority', '${_place.tourismPriority ?? "null"}'),
                    _qaRow('Overall Quality Score', '${_place.qualityOverall ?? "null"}'),
                    _qaRow('Anomaly Score', '${_place.anomalyScore}'),
                    _qaRow('Family Friendly', '${_place.familyFriendly ?? "null"}'),
                    _qaRow('Generated At', _place.generatedAt ?? 'null'),
                    _qaRow('Pack Version', widget.state.activePack?.version ?? 'v3'),

                    const SizedBox(height: 16),
                    _buildSectionHeader('Upstream Entity IDs'),
                    _qaRow('Wikidata ID', _place.wikidataId ?? 'null'),
                    _qaRow('OpenStreetMap ID', _place.osmId ?? 'null'),
                    _qaRow('Overture Maps ID', _place.overtureId ?? 'null'),
                    _qaRow('Foursquare ID', _place.foursquareId ?? 'null'),
                    _qaRow('Wikivoyage Listing ID', _place.wikivoyageListingId ?? 'null'),

                    const SizedBox(height: 16),
                    _buildSectionHeader('Upstream Sources (${_place.sources.length})'),
                    if (_place.sources.isEmpty)
                      const Text('No source records attached.')
                    else
                      ..._place.sources.map((src) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              '• [${src.source.toUpperCase()}] ID: ${src.sourceId ?? "N/A"} (${src.retrievedAt ?? "N/A"})',
                              style: const TextStyle(
                                  fontFamily: 'monospace', fontSize: 11),
                            ),
                          )),

                    const SizedBox(height: 16),
                    _buildSectionHeader('Image License & Attribution'),
                    _qaRow('Primary Image Path', _place.primaryImagePath ?? 'null (Missing image)'),
                    _qaRow('Thumbnail Path', _place.thumbnailImagePath ?? 'null'),
                    if (_place.images.isNotEmpty) ...[
                      ..._place.images.map((img) => Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('File: ${img.originalFile}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12)),
                                Text('Author: ${img.author ?? "Unknown"}',
                                    style: const TextStyle(fontSize: 11)),
                                Text('License: ${img.license}',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600)),
                                if (img.licenseUrl != null)
                                  Text('License URL: ${img.licenseUrl}',
                                      style: const TextStyle(
                                          fontSize: 10, color: Colors.blue)),
                                Text(
                                    'Match Method: ${img.matchMethod} (Confidence: ${img.matchConfidence})',
                                    style: const TextStyle(fontSize: 11)),
                              ],
                            ),
                          )),
                    ] else
                      const Text('No image records in place_images table.'),
                  ],

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _qaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: Colors.blueGrey.shade800),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.blueGrey.shade50,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_not_supported_outlined,
              size: 48, color: Colors.blueGrey.shade300),
          const SizedBox(height: 8),
          Text(
            'No local image',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey.shade700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Place has no bundled image in City Pack release',
            style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade500),
          ),
        ],
      ),
    );
  }
}
