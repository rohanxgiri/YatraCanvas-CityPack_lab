import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../app/app_state.dart';
import '../domain/curation/curated_place.dart';
import '../widgets/curation/category_editor_dialog.dart';
import '../widgets/curation/coordinate_editor_dialog.dart';
import '../widgets/curation/exclude_place_dialog.dart';
import '../widgets/curation/image_curator_dialog.dart';
import '../widgets/curation/opening_hours_editor_dialog.dart';
import '../widgets/curation/place_editor_dialog.dart';
import '../widgets/report_problem_dialog.dart';

class CuratedPlaceDetailScreen extends StatefulWidget {
  final CuratedPlace place;
  final AppState state;

  const CuratedPlaceDetailScreen({
    super.key,
    required this.place,
    required this.state,
  });

  @override
  State<CuratedPlaceDetailScreen> createState() => _CuratedPlaceDetailScreenState();
}

class _CuratedPlaceDetailScreenState extends State<CuratedPlaceDetailScreen> {
  late CuratedPlace _place;
  bool _showAdvanced = false;

  @override
  void initState() {
    super.initState();
    _place = widget.place;
    _refresh();
  }

  void _refresh() async {
    final updated = await widget.state.getCuratedPlaceById(widget.place.id);
    if (mounted && updated != null) {
      setState(() => _place = updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final File? localImgFile = kIsWeb
        ? null
        : widget.state.repository?.resolveImage(_place.primaryImagePath);

    return Scaffold(
      appBar: AppBar(
        title: Text(_place.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.flag_outlined),
            tooltip: 'Flag Problem',
            onPressed: () {
              ReportProblemDialog.show(
                context,
                place: _place.toLabPlace(),
                packVersion: widget.state.activePack?.version ?? 'v3',
                onSubmit: (issue) async {
                  await widget.state.logCurationIssue(
                    placeId: _place.id,
                    placeName: _place.name,
                    issueType: issue.issueType.code,
                    note: issue.note,
                  );
                },
              );
            },
          ),
          IconButton(
            icon: Icon(_showAdvanced ? Icons.terminal : Icons.terminal_outlined),
            tooltip: 'Toggle Advanced Provider IDs',
            onPressed: () => setState(() => _showAdvanced = !_showAdvanced),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Image Header
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

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badges Row
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _place.isCore ? Colors.amber.shade100 : Colors.indigo.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: _place.isCore ? Colors.amber.shade400 : Colors.indigo.shade200),
                        ),
                        child: Text(
                          _place.tier.replaceAll('_', ' ').toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _place.isCore ? Colors.amber.shade900 : Colors.indigo.shade900,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _place.category.toUpperCase(),
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade900),
                        ),
                      ),
                      if (_place.isManuallyEdited)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.edit, size: 12, color: Colors.green),
                              SizedBox(width: 4),
                              Text('MANUALLY CURATED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)),
                            ],
                          ),
                        ),
                      if (_place.isManuallyAdded)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add, size: 12, color: Colors.purple),
                              SizedBox(width: 4),
                              Text('MANUAL ADDITION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.purple)),
                            ],
                          ),
                        ),
                      if (_place.isExcluded)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.block, size: 12, color: Colors.red),
                              SizedBox(width: 4),
                              Text('EXCLUDED FROM RELEASE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red)),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Title & Subtitle
                  Text(
                    _place.name,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  if (_place.nameHi != null && _place.nameHi!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      _place.nameHi!,
                      style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Curation Action Toolbar
                  _buildCurationToolbar(),
                  const SizedBox(height: 20),

                  // Primary Information Section
                  _buildSectionHeader('Place Information'),
                  _infoCard([
                    _infoRow(Icons.location_on_outlined, 'Coordinates', '${_place.latitude.toStringAsFixed(6)}, ${_place.longitude.toStringAsFixed(6)}'),
                    if (_place.address != null) _infoRow(Icons.home_outlined, 'Address', _place.address!),
                    _infoRow(
                      Icons.access_time_outlined,
                      'Opening Hours',
                      _place.openingHours ?? 'Not configured',
                      isWarning: _place.openingHours == null,
                    ),
                    if (_place.website != null) _infoRow(Icons.language_outlined, 'Website', _place.website!),
                    if (_place.phone != null) _infoRow(Icons.phone_outlined, 'Phone', _place.phone!),
                    if (_place.description != null) _infoRow(Icons.description_outlined, 'Description', _place.description!),
                  ]),
                  const SizedBox(height: 24),

                  // Field-Level Provenance & Audit Card
                  _buildSectionHeader('Field Provenance & Traceability'),
                  _provenanceCard(),
                  const SizedBox(height: 24),

                  // Advanced Details (Collapsible)
                  if (_showAdvanced) ...[
                    _buildSectionHeader('Technical Provider Identifiers & Pipeline Metrics'),
                    _advancedCard(),
                    const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurationToolbar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.indigo.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Curation Quick Actions:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.indigo)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.access_time, size: 15),
                label: const Text('Fix Hours'),
                onPressed: () {
                  OpeningHoursEditorDialog.show(
                    context,
                    place: _place,
                    onSave: ({required openingHours, required evidenceSource}) async {
                      await widget.state.saveFieldOverride(
                        place: _place.toLabPlace(),
                        openingHours: openingHours,
                        fieldName: 'opening_hours',
                        evidenceSource: evidenceSource,
                        previousValue: _place.rawPlace?.openingHours,
                      );
                      _refresh();
                    },
                  );
                },
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.pin_drop, size: 15),
                label: const Text('Fix Location'),
                onPressed: () {
                  CoordinateEditorDialog.show(
                    context,
                    place: _place,
                    bbox: widget.state.qualityStats?['bbox'] as Map<String, dynamic>?,
                    onSave: ({required latitude, required longitude, required evidenceSource}) async {
                      await widget.state.saveFieldOverride(
                        place: _place.toLabPlace(),
                        latitude: latitude,
                        longitude: longitude,
                        fieldName: 'coordinates',
                        evidenceSource: evidenceSource,
                        previousValue: '${_place.rawPlace?.latitude}, ${_place.rawPlace?.longitude}',
                      );
                      _refresh();
                    },
                  );
                },
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.photo_camera, size: 15),
                label: const Text('Curate Photo'),
                onPressed: () {
                  ImageCuratorDialog.show(
                    context,
                    place: _place,
                    onSave: ({required primaryImagePath, required evidenceSource}) async {
                      await widget.state.saveFieldOverride(
                        place: _place.toLabPlace(),
                        primaryImagePath: primaryImagePath,
                        fieldName: 'primary_image_path',
                        evidenceSource: evidenceSource,
                        previousValue: _place.rawPlace?.primaryImagePath,
                      );
                      _refresh();
                    },
                    onFlag: (issueType, note) async {
                      await widget.state.logCurationIssue(
                        placeId: _place.id,
                        placeName: _place.name,
                        issueType: issueType,
                        note: note,
                      );
                      _refresh();
                    },
                  );
                },
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.category, size: 15),
                label: const Text('Change Category'),
                onPressed: () {
                  CategoryEditorDialog.show(
                    context,
                    place: _place,
                    onSave: ({required category, subcategory, required evidenceSource}) async {
                      await widget.state.saveFieldOverride(
                        place: _place.toLabPlace(),
                        category: category,
                        subcategory: subcategory,
                        fieldName: 'category',
                        evidenceSource: evidenceSource,
                        previousValue: _place.rawPlace?.category,
                      );
                      _refresh();
                    },
                  );
                },
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.edit, size: 15),
                label: const Text('Edit Details'),
                onPressed: () {
                  PlaceEditorDialog.show(
                    context,
                    place: _place,
                    onSave: ({required name, nameHi, description, website, phone, tier, required evidenceSource}) async {
                      await widget.state.saveFieldOverride(
                        place: _place.toLabPlace(),
                        name: name,
                        category: _place.category,
                        description: description,
                        website: website,
                        phone: phone,
                        tier: tier,
                        isCore: tier == 'core_destination',
                        fieldName: 'name',
                        evidenceSource: evidenceSource,
                        previousValue: _place.rawPlace?.name,
                      );
                      _refresh();
                    },
                  );
                },
              ),
              if (!_place.isExcluded)
                OutlinedButton.icon(
                  icon: const Icon(Icons.block, size: 15, color: Colors.red),
                  label: const Text('Exclude Place', style: TextStyle(color: Colors.red)),
                  onPressed: () {
                    ExcludePlaceDialog.show(
                      context,
                      place: _place,
                      onConfirm: ({required reason, notes}) async {
                        await widget.state.excludePlace(
                          placeId: _place.id,
                          placeName: _place.name,
                          reason: reason,
                          notes: notes,
                        );
                        _refresh();
                      },
                    );
                  },
                )
              else
                OutlinedButton.icon(
                  icon: const Icon(Icons.restore, size: 15, color: Colors.green),
                  label: const Text('Restore Place', style: TextStyle(color: Colors.green)),
                  onPressed: () async {
                    await widget.state.unexcludePlace(_place.id);
                    _refresh();
                  },
                ),
              if (_place.isManuallyEdited)
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.orange.shade900),
                  onPressed: () async {
                    await widget.state.revertOverride(_place.id);
                    _refresh();
                  },
                  child: const Text('Revert Overrides'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _provenanceCard() {
    final fields = ['name', 'opening_hours', 'latitude', 'category', 'primary_image_path'];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: fields.map((f) {
            final prov = _place.getProvenance(f);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 130,
                    child: Text(
                      f.replaceAll('_', ' ').toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          prov.sourceLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: prov.isManuallyVerified ? Colors.green.shade800 : Colors.indigo.shade800,
                          ),
                        ),
                        if (prov.previousValue != null)
                          Text(
                            'Previous: ${prov.previousValue}',
                            style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                          ),
                      ],
                    ),
                  ),
                  if (prov.isManuallyVerified)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(4)),
                      child: const Text('VERIFIED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.green)),
                    ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _advancedCard() {
    final raw = _place.rawPlace;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _advRow('Canonical Place ID', _place.id),
            _advRow('City ID', _place.cityId),
            _advRow('Wikidata ID', raw?.wikidataId ?? 'null'),
            _advRow('OpenStreetMap ID', raw?.osmId ?? 'null'),
            _advRow('Overture Maps ID', raw?.overtureId ?? 'null'),
            _advRow('Foursquare ID', raw?.foursquareId ?? 'null'),
            _advRow('Wikivoyage ID', raw?.wikivoyageListingId ?? 'null'),
            _advRow('Travel Relevance', '${raw?.travelRelevanceScore ?? "N/A"}'),
            _advRow('Prominence Score', '${raw?.prominenceScore ?? "N/A"}'),
            _advRow('Tourism Priority', '${raw?.tourismPriority ?? "N/A"}'),
            _advRow('Anomaly Score', '${raw?.anomalyScore ?? 0.0}'),
            _advRow('Generated At', raw?.generatedAt ?? 'Manual Addition'),
          ],
        ),
      ),
    );
  }

  Widget _infoCard(List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: children),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, {bool isWarning = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: isWarning ? Colors.red : Colors.grey.shade600),
          const SizedBox(width: 8),
          SizedBox(
            width: 110,
            child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isWarning ? Colors.red.shade800 : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _advRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Text(label, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.black54)),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.blueGrey.shade50,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_not_supported_outlined, size: 48, color: Colors.blueGrey.shade300),
          const SizedBox(height: 8),
          const Text('No local photo available', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Use "Curate Photo" above to attach an image', style: TextStyle(fontSize: 11, color: Colors.black54)),
        ],
      ),
    );
  }
}
