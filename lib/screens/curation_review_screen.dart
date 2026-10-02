import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_state.dart';
import '../domain/curation/curated_place.dart';
import '../domain/qa_issue.dart';
import '../widgets/curation/opening_hours_editor_dialog.dart';
import '../widgets/report_problem_dialog.dart';
import 'curated_place_detail_screen.dart';

class CurationReviewScreen extends StatefulWidget {
  final AppState state;

  const CurationReviewScreen({super.key, required this.state});

  @override
  State<CurationReviewScreen> createState() => _CurationReviewScreenState();
}

class _CurationReviewScreenState extends State<CurationReviewScreen> {
  List<CuratedPlace> _places = [];
  bool _isLoading = true;
  int _currentIndex = 0;
  bool _saving = false;
  bool _includeReviewed = false;

  @override
  void initState() {
    super.initState();
    _loadSample();
  }

  void _loadSample() async {
    setState(() => _isLoading = true);
    final repo = widget.state.repository;
    if (repo == null) return;

    // Generate stratified sample
    final sample = await widget.state.qaSamplingService.generateSample(
      repo.database,
    );

    // Filter out already reviewed places (Fixes BUG-03!)
    final reviewedPlaceIds = {
      ...widget.state.curationService.reviews.keys,
      ...(widget.state.currentSession?.randomReviews.map((r) => r.placeId) ??
          []),
    };

    final hydrated = await Future.wait(
      sample.allPlaces
          .where((p) => _includeReviewed || !reviewedPlaceIds.contains(p.id))
          .map((place) async => await repo.getPlaceById(place.id) ?? place),
    );
    final unreviewed = hydrated
        .map((p) => widget.state.curationService.resolve(p))
        .where((p) => !p.isExcluded)
        .toList();

    if (mounted) {
      setState(() {
        _places = unreviewed;
        _currentIndex = 0;
        _isLoading = false;
      });
    }
  }

  void _verifyCurrentPlace() async {
    if (_saving || _places.isEmpty || _currentIndex >= _places.length) return;
    _saving = true;
    final place = _places[_currentIndex];

    try {
      await widget.state.recordPlaceReview(
        placeId: place.id,
        placeName: place.name,
        tier: place.tier,
        category: place.category,
        verdict: 'looks_good',
        notes: 'Manually verified as accurate in Curation Studio',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Review could not be saved: $e')),
        );
      }
      return;
    } finally {
      _saving = false;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Verified "${place.name}"'),
        duration: const Duration(milliseconds: 900),
        backgroundColor: Colors.green.shade800,
      ),
    );

    _next();
  }

  void _flagCurrentPlace() {
    if (_places.isEmpty || _currentIndex >= _places.length) return;
    final place = _places[_currentIndex];

    ReportProblemDialog.show(
      context,
      place: place.toLabPlace(),
      packVersion: widget.state.activePack?.version ?? 'v3',
      initialType: QaIssueType.missingExpectedInformation,
      onSubmit: (issue) async {
        await widget.state.recordPlaceReview(
          placeId: place.id,
          placeName: place.name,
          tier: place.tier,
          category: place.category,
          verdict: issue.issueType.code,
          issueType: issue.issueType.code,
          notes: issue.note,
        );

        await widget.state.logCurationIssue(
          placeId: place.id,
          placeName: place.name,
          issueType: issue.issueType.code,
          note: issue.note,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Flagged defect for "${place.name}"'),
            backgroundColor: Colors.orange.shade900,
          ),
        );
        _next();
      },
    );
  }

  Future<void> _needsResearch() async {
    if (_saving || _places.isEmpty) return;
    _saving = true;
    final place = _places[_currentIndex];
    try {
      await widget.state.recordPlaceReview(
        placeId: place.id,
        placeName: place.name,
        tier: place.tier,
        category: place.category,
        verdict: 'uncertain',
        notes: 'Needs research after inspection',
      );
      if (mounted) _next();
    } finally {
      _saving = false;
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent ||
        _saving ||
        _places.isEmpty ||
        ModalRoute.of(context)?.isCurrent != true) {
      return KeyEventResult.ignored;
    }
    final focused = FocusManager.instance.primaryFocus?.context;
    if (focused?.widget is EditableText ||
        focused?.findAncestorWidgetOfExactType<EditableText>() != null) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyP) {
      _verifyCurrentPlace();
    } else if (event.logicalKey == LogicalKeyboardKey.keyI) {
      _flagCurrentPlace();
    } else if (event.logicalKey == LogicalKeyboardKey.keyJ ||
        event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _next();
    } else if (event.logicalKey == LogicalKeyboardKey.keyK ||
        event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (_currentIndex > 0) {
        setState(() => _currentIndex--);
      }
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  void _next() {
    if (_currentIndex < _places.length - 1) {
      setState(() => _currentIndex++);
    } else {
      _loadSample();
    }
  }

  @override
  Widget build(BuildContext context) {
    final qa = widget.state.manualQaSummary;
    final reviewedCount = qa?.reviewedCount ?? 0;
    final minRequired = qa?.minimumRequired ?? 50;

    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Verification Progress Bar Header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Manual Verification Sample: $reviewedCount of $minRequired completed',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                qa?.displayStatus ?? 'NOT STARTED',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  color: (qa?.isSufficient ?? false)
                                      ? Colors.green
                                      : Colors.amber.shade900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: (reviewedCount / minRequired).clamp(
                              0.0,
                              1.0,
                            ),
                            backgroundColor: Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation(
                              (qa?.isSufficient ?? false)
                                  ? Colors.green
                                  : Colors.indigo,
                            ),
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${qa?.approvedCount ?? 0} Passed · ${qa?.issueCount ?? 0} Issues · '
                            '${qa?.uncertainCount ?? 0} Needs Research · ${(minRequired - reviewedCount).clamp(0, minRequired)} remaining',
                          ),
                          Row(
                            children: [
                              TextButton(
                                onPressed: () {
                                  _includeReviewed = !_includeReviewed;
                                  _loadSample();
                                },
                                child: Text(
                                  _includeReviewed
                                      ? 'Show unreviewed'
                                      : 'Recheck reviewed places',
                                ),
                              ),
                              const Text(
                                'P = Pass · I = Issue · J/K or arrows = next/previous',
                              ),
                            ],
                          ),
                          const Text(
                            'Spot-check published places here. Use Inbox for DataFactory uncertainties.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Review Queue Card
                    Expanded(
                      child: _places.isEmpty
                          ? _buildCompleteState()
                          : _buildReviewCard(_places[_currentIndex]),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildReviewCard(CuratedPlace place) {
    final File? localImgFile = kIsWeb
        ? null
        : widget.state.repository?.resolveImage(place.primaryImagePath);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Media Header
          SizedBox(
            height: 160,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: localImgFile != null
                  ? Image.file(
                      localImgFile,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, stack) => _buildPlaceholder(),
                    )
                  : (kIsWeb &&
                            place.primaryImagePath != null &&
                            place.primaryImagePath!.isNotEmpty
                        ? Image.asset(
                            'assets/city_packs/${place.cityId}/${place.primaryImagePath}',
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, stack) =>
                                _buildPlaceholder(),
                          )
                        : _buildPlaceholder()),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category & Tier
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
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
                              fontSize: 10,
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
                    const SizedBox(height: 8),

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
                    const SizedBox(height: 12),

                    Text(
                      place.description?.trim().isNotEmpty == true
                          ? place.description!
                          : 'Description: not provided',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sources: ${place.rawPlace?.sources.map((s) => '${s.source}: ${s.sourceId ?? "unknown ID"}').join("; ") ?? "not provided"}',
                    ),
                    for (final image in place.rawPlace?.images ?? [])
                      Text(
                        'Image: ${image.localPath}\nAuthor: ${image.author ?? "missing"} · License: ${image.license}\n'
                        'Attribution: ${image.attribution ?? "missing"}',
                      ),

                    // Details Row
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: place.hasOpeningHours
                              ? Colors.green
                              : Colors.red,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          place.openingHours ?? 'Missing opening hours',
                          style: TextStyle(
                            fontSize: 12,
                            color: place.hasOpeningHours
                                ? Colors.black87
                                : Colors.red.shade700,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Icon(
                          Icons.location_on,
                          size: 14,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${place.latitude.toStringAsFixed(4)}, ${place.longitude.toStringAsFixed(4)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Prompt & Decision Buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(16),
              ),
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Column(
              children: [
                const Text(
                  'Does this information look correct and travel-ready?',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('PASS (P)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: _verifyCurrentPlace,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(
                          Icons.warning_amber_rounded,
                          size: 18,
                          color: Colors.orange,
                        ),
                        label: const Text(
                          'ISSUE (I)',
                          style: TextStyle(color: Colors.black87),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: _flagCurrentPlace,
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 12,
                  children: [
                    TextButton(
                      onPressed: _currentIndex > 0
                          ? () => setState(() => _currentIndex--)
                          : null,
                      child: const Text('Previous'),
                    ),
                    TextButton(onPressed: _next, child: const Text('Skip')),
                    TextButton(
                      onPressed: _needsResearch,
                      child: const Text('Needs Research'),
                    ),
                    TextButton(
                      onPressed: _showSomethingWrongSheet,
                      child: const Text('Fix Now'),
                    ),
                    TextButton(
                      onPressed: () async {
                        final place = _places[_currentIndex];
                        await Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => CuratedPlaceDetailScreen(
                              place: place,
                              state: widget.state,
                            ),
                          ),
                        );
                        final fresh = await widget.state.getCuratedPlaceById(
                          place.id,
                        );
                        if (mounted && fresh != null) {
                          setState(() => _places[_currentIndex] = fresh);
                        }
                      },
                      child: const Text('Open Place'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSomethingWrongSheet() {
    final place = _places[_currentIndex];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'What needs attention for "${place.name}"?',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.build, color: Colors.indigo),
              title: const Text('Edit opening hours'),
              subtitle: const Text(
                'Open dedicated editor and correct information instantly',
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                OpeningHoursEditorDialog.show(
                  context,
                  place: place,
                  onSave:
                      ({required openingHours, required evidenceSource}) async {
                        await widget.state.saveFieldOverride(
                          place: place.toLabPlace(),
                          openingHours: openingHours,
                          fieldName: 'opening_hours',
                          evidenceSource: evidenceSource,
                        );
                        final updated = await widget.state.getCuratedPlaceById(
                          place.id,
                        );
                        if (mounted && updated != null) {
                          setState(() => _places[_currentIndex] = updated);
                        }
                      },
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined, color: Colors.orange),
              title: const Text('Flag Defect for Review'),
              subtitle: const Text(
                'Report wrong image, wrong category or location for team to fix',
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                _flagCurrentPlace();
              },
            ),
            ListTile(
              leading: const Icon(Icons.skip_next, color: Colors.grey),
              title: const Text('Skip This Place'),
              onTap: () {
                Navigator.of(ctx).pop();
                _next();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompleteState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.celebration, size: 64, color: Colors.green),
          const SizedBox(height: 16),
          const Text(
            'All Queue Items Reviewed!',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'You have reviewed all places in the current stratified sample queue.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: _loadSample,
            child: const Text('Check for Remaining Unreviewed'),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.blueGrey.shade50,
      alignment: Alignment.center,
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            size: 40,
            color: Colors.blueGrey,
          ),
          SizedBox(height: 4),
          Text(
            'No photo available',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
