import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../app/app_state.dart';
import '../domain/lab_place.dart';
import '../domain/qa_session.dart';
import '../domain/qa_issue.dart';

class RandomReviewScreen extends StatefulWidget {
  final AppState state;

  const RandomReviewScreen({super.key, required this.state});

  @override
  State<RandomReviewScreen> createState() => _RandomReviewScreenState();
}

class _RandomReviewScreenState extends State<RandomReviewScreen> {
  // Sampler configuration
  int _sampleSize = 30;
  String _selectedTier = 'all';
  String _selectedCategory = 'all';
  int _seed = 42;

  bool _isReviewing = false;
  List<LabPlace> _sampleList = [];
  int _currentIndex = 0;
  final TextEditingController _noteController = TextEditingController();

  // Results tracking
  int _looksGoodCount = 0;
  final Map<String, int> _problemBreakdown = {};
  bool _isCompleted = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _startSampling() async {
    final repo = widget.state.repository;
    if (repo == null) return;

    setState(() {
      _isReviewing = true;
      _sampleList = [];
      _currentIndex = 0;
      _looksGoodCount = 0;
      _problemBreakdown.clear();
      _isCompleted = false;
    });

    final list = await repo.getRandomPlaces(
      count: _sampleSize,
      tier: _selectedTier == 'all' ? null : _selectedTier,
      category: _selectedCategory == 'all' ? null : _selectedCategory,
      seed: _seed,
    );

    if (mounted) {
      setState(() {
        _sampleList = list;
        if (list.isEmpty) {
          _isCompleted = true;
        }
      });
    }
  }

  void _recordDecision(String result) {
    if (_currentIndex >= _sampleList.length) return;

    final place = _sampleList[_currentIndex];
    final note = _noteController.text.trim();

    if (result == 'looks_good') {
      _looksGoodCount++;
    } else {
      _problemBreakdown[result] = (_problemBreakdown[result] ?? 0) + 1;

      // Also log as formal QA Issue if it's a problem
      final issue = QaIssue(
        id: 'random_rev_${place.id}_${DateTime.now().millisecondsSinceEpoch}',
        timestamp: DateTime.now().toIso8601String(),
        cityId: place.cityId,
        packVersion: widget.state.activePack?.version ?? 'v3',
        placeId: place.id,
        placeName: place.name,
        tier: place.tier,
        category: place.category,
        latitude: place.latitude,
        longitude: place.longitude,
        issueType: QaIssueType.fromCode(result),
        note: note.isNotEmpty ? note : 'Flagged during Random QA Review',
      );
      widget.state.reportIssue(issue);
    }

    final record = RandomReviewRecord(
      placeId: place.id,
      placeName: place.name,
      tier: place.tier,
      category: place.category,
      result: result,
      note: note.isNotEmpty ? note : null,
      timestamp: DateTime.now().toIso8601String(),
    );
    widget.state.addRandomReview(record);

    _noteController.clear();

    if (_currentIndex + 1 < _sampleList.length) {
      setState(() => _currentIndex++);
    } else {
      setState(() => _isCompleted = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Random Places (QA)'),
      ),
      body: !_isReviewing
          ? _buildConfigurationView()
          : _isCompleted
              ? _buildCompletedSummaryView()
              : _buildReviewCardView(),
    );
  }

  Widget _buildConfigurationView() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: ListView(
        children: [
          const Text(
            'Random Sample Review Mode',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Rapidly inspect randomly sampled records to uncover bad categories, wrong coordinates, corrupted names, or missing relevance.',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
          const Divider(height: 32),

          // Sample size
          const Text('Sample Size:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [20, 30, 50, 100].map((size) {
              return ChoiceChip(
                label: Text('$size places'),
                selected: _sampleSize == size,
                onSelected: (selected) {
                  if (selected) setState(() => _sampleSize = size);
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 20),

          // Tier filter
          const Text('Filter by Tier:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              'all',
              'core_destination',
              'recommended',
              'discovery',
              'support'
            ].map((tier) {
              return ChoiceChip(
                label: Text(tier.toUpperCase()),
                selected: _selectedTier == tier,
                onSelected: (selected) {
                  if (selected) setState(() => _selectedTier = tier);
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 20),

          // Category filter
          const Text('Filter by Category:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              'all',
              'heritage',
              'religious',
              'nature',
              'food',
              'cafe',
              'shopping',
              'viewpoint'
            ].map((cat) {
              return ChoiceChip(
                label: Text(cat.toUpperCase()),
                selected: _selectedCategory == cat,
                onSelected: (selected) {
                  if (selected) setState(() => _selectedCategory = cat);
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 20),

          // Seed selector
          Row(
            children: [
              const Text('Random Seed: ', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(
                width: 80,
                child: TextField(
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    border: OutlineInputBorder(),
                  ),
                  controller: TextEditingController(text: '$_seed'),
                  onChanged: (val) {
                    final n = int.tryParse(val);
                    if (n != null) _seed = n;
                  },
                ),
              ),
              const SizedBox(width: 8),
              Text('(Reproducible)', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ),

          const SizedBox(height: 32),

          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _startSampling,
              icon: const Icon(Icons.play_arrow),
              label: Text('Start Reviewing $_sampleSize Places'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCardView() {
    if (_sampleList.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final place = _sampleList[_currentIndex];
    final File? localImgFile = kIsWeb
        ? null
        : widget.state.repository?.resolveImage(place.primaryImagePath);

    return Column(
      children: [
        // Progress bar
        LinearProgressIndicator(
          value: (_currentIndex + 1) / _sampleList.length,
          backgroundColor: Colors.grey.shade200,
          color: Colors.indigo,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                'Review: ${_currentIndex + 1} / ${_sampleList.length}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const Spacer(),
              Text(
                'Good: $_looksGoodCount | Issues: ${_problemBreakdown.values.fold(0, (a, b) => a + b)}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ],
          ),
        ),

        // Place card to review
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              clipBehavior: Clip.antiAlias,
              elevation: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: localImgFile != null
                        ? Image.file(
                            localImgFile,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, stack) => _buildPlaceholder(),
                          )
                        : (kIsWeb && place.primaryImagePath != null && place.primaryImagePath!.isNotEmpty
                            ? Image.asset(
                                'assets/city_packs/${place.cityId}/${place.primaryImagePath}',
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, err, stack) => _buildPlaceholder(),
                              )
                            : _buildPlaceholder()),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                place.tier.toUpperCase(),
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber.shade900),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              place.category.toUpperCase(),
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade800),
                            ),
                            if (place.subcategory != null)
                              Text(' • ${place.subcategory}',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          place.name,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        if (place.nameHi != null && place.nameHi!.isNotEmpty)
                          Text(
                            place.nameHi!,
                            style: TextStyle(
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                                color: Colors.grey.shade600),
                          ),
                        if (place.address != null && place.address!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              place.address!,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade700),
                            ),
                          ),
                        const SizedBox(height: 6),
                        Text(
                          'Coords: ${place.latitude.toStringAsFixed(4)}, ${place.longitude.toStringAsFixed(4)} | Relevance: ${place.travelRelevanceScore}',
                          style: const TextStyle(
                              fontSize: 10, fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Optional Note Input
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextField(
            controller: _noteController,
            decoration: const InputDecoration(
              hintText: 'Optional QA note for this place...',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ),

        // Action Buttons
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            children: [
              // Primary "LOOKS GOOD"
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: () => _recordDecision('looks_good'),
                  icon: const Icon(Icons.check_circle),
                  label: const Text('LOOKS GOOD',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Rapid Problem Buttons Grid
              Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  _problemBtn('WRONG CATEGORY', 'wrong_category'),
                  _problemBtn('WRONG LOCATION', 'wrong_location'),
                  _problemBtn('BAD IMAGE', 'wrong_image'),
                  _problemBtn('WRONG NAME', 'wrong_name'),
                  _problemBtn('DUPLICATE', 'duplicate'),
                  _problemBtn('NOT TRAVEL RELEVANT', 'not_travel_relevant'),
                  _problemBtn('SHOULD NOT BE CORE', 'should_not_be_core'),
                  _problemBtn('STALE / CLOSED', 'possibly_closed_or_stale'),
                  _problemBtn('OTHER', 'other'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _problemBtn(String label, String code) {
    return OutlinedButton(
      onPressed: () => _recordDecision(code),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.red.shade800,
        side: BorderSide(color: Colors.red.shade300),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        visualDensity: VisualDensity.compact,
      ),
      child: Text(label, style: const TextStyle(fontSize: 10)),
    );
  }

  Widget _buildCompletedSummaryView() {
    final total = _sampleList.length;
    final problems = _problemBreakdown.values.fold(0, (a, b) => a + b);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, size: 36, color: Colors.green.shade700),
              const SizedBox(width: 12),
              const Text(
                'Review Completed',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _summaryRow('Reviewed Places', '$total'),
                  _summaryRow('Looks Good', '$_looksGoodCount (${total > 0 ? ((_looksGoodCount / total) * 100).toStringAsFixed(1) : 0}%)'),
                  _summaryRow('Problems Flagged', '$problems (${total > 0 ? ((problems / total) * 100).toStringAsFixed(1) : 0}%)'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_problemBreakdown.isNotEmpty) ...[
            const Text('Problem Breakdown:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ..._problemBreakdown.entries.map((e) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Text('• ${e.key}: ', style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('${e.value} places', style: TextStyle(color: Colors.red.shade800)),
                  ],
                ),
              );
            }),
          ],
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                setState(() => _isReviewing = false);
              },
              child: const Text('Start Another Review'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
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
              size: 36, color: Colors.blueGrey.shade300),
          const SizedBox(height: 6),
          Text(
            'No local image',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}
