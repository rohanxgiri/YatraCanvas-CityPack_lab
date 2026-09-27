import 'package:flutter/material.dart';
import '../app/app_state.dart';
import '../domain/lab_place.dart';
import '../domain/qa_session.dart';
import '../widgets/place_card.dart';
import '../widgets/report_problem_dialog.dart';
import 'place_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  final AppState state;

  const SearchScreen({super.key, required this.state});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<LabPlace> _results = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  int _searchLatencyMs = 0;

  // Search Result Review Mode (Phase 19)
  bool _isReviewMode = false;
  final Map<String, String> _reviewRatings = {}; // placeId -> rating

  // Preset queries mentioned in requirements
  final List<String> _presets = [
    'cafe',
    'coffee',
    'temple',
    'waterfall',
    'viewpoint',
    'heritage',
    'palace',
    'fort',
    'market',
    'shopping',
    'nature',
    'museum',
    'rafting',
    'yoga',
    'local food',
    'church',
    'ashram',
    'railway station',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _executeSearch(String query) async {
    final repo = widget.state.repository;
    if (repo == null) return;

    final term = query.trim();
    if (term.isEmpty) {
      setState(() {
        _results = [];
        _hasSearched = false;
      });
      return;
    }

    setState(() => _isLoading = true);
    final sw = Stopwatch()..start();

    final places = await repo.search(query: term, limit: 100);

    sw.stop();
    widget.state.recordQueryLatency(sw.elapsedMilliseconds);

    if (mounted) {
      setState(() {
        _results = places;
        _isLoading = false;
        _hasSearched = true;
        _searchLatencyMs = sw.elapsedMilliseconds;
      });
    }
  }

  void _rateResult(LabPlace place, int rank, String rating) {
    setState(() {
      _reviewRatings[place.id] = rating;
    });

    final record = SearchResultReviewRecord(
      query: _searchController.text.trim(),
      rank: rank,
      placeId: place.id,
      placeName: place.name,
      rating: rating,
      timestamp: DateTime.now().toIso8601String(),
    );

    widget.state.addSearchResultReview(record);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Natural Search (Local)'),
        actions: [
          // Toggle Review Mode
          Row(
            children: [
              const Text('Review Mode', style: TextStyle(fontSize: 12)),
              Switch(
                value: _isReviewMode,
                activeTrackColor: Colors.amber.shade300,
                activeThumbColor: Colors.amber.shade800,
                onChanged: (val) {
                  setState(() => _isReviewMode = val);
                },
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Search input bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              autofocus: false,
              decoration: InputDecoration(
                hintText: 'Search places, categories, tags...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _executeSearch('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onSubmitted: _executeSearch,
              textInputAction: TextInputAction.search,
            ),
          ),

          // Presets row
          SizedBox(
            height: 36,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _presets.length,
              itemBuilder: (context, index) {
                final preset = _presets[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ActionChip(
                    label: Text(preset, style: const TextStyle(fontSize: 12)),
                    backgroundColor: Colors.grey.shade100,
                    onPressed: () {
                      _searchController.text = preset;
                      _executeSearch(preset);
                    },
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // Search latency & count indicator
          if (_hasSearched)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: Colors.grey.shade50,
              child: Row(
                children: [
                  Text(
                    'Found ${_results.length} results',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const Spacer(),
                  Text(
                    'SQLite latency: $_searchLatencyMs ms',
                    style: TextStyle(
                        fontSize: 11, color: Colors.blueGrey.shade700),
                  ),
                ],
              ),
            ),

          // Review mode banner if active
          if (_isReviewMode && _hasSearched)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.amber.shade50,
              child: Row(
                children: [
                  Icon(Icons.rate_review_outlined,
                      size: 16, color: Colors.amber.shade900),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Search Result Review Mode: Rate each result to measure pack precision.',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.amber.shade900),
                    ),
                  ),
                ],
              ),
            ),

          // Results list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : !_hasSearched
                    ? Center(
                        child: Text(
                          'Enter a query or tap a quick chip above to search.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                    : _results.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'No matching POIs found in this City Pack.\n(Preserved zero-padding rule: no artificial places shown)',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.only(top: 8, bottom: 24),
                            itemCount: _results.length,
                            itemBuilder: (context, index) {
                              final place = _results[index];
                              final isInTrip = widget.state.tripSelection
                                      ?.contains(place.id) ??
                                  false;
                              final currentRating = _reviewRatings[place.id];

                              return Column(
                                children: [
                                  PlaceCard(
                                    place: place,
                                    repository: widget.state.repository!,
                                    isInTrip: isInTrip,
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => PlaceDetailScreen(
                                            place: place,
                                            state: widget.state,
                                          ),
                                        ),
                                      );
                                    },
                                    onToggleTrip: () {
                                      if (isInTrip) {
                                        widget.state
                                            .removePlaceFromTrip(place.id);
                                      } else {
                                        widget.state
                                            .addPlaceToTrip(place.id);
                                      }
                                      setState(() {});
                                    },
                                    onReport: () {
                                      ReportProblemDialog.show(
                                        context,
                                        place: place,
                                        packVersion: widget.state.activePack
                                                ?.version ??
                                            'v3',
                                        onSubmit: (issue) =>
                                            widget.state.reportIssue(issue),
                                      );
                                    },
                                  ),

                                  // Review mode ratings buttons
                                  if (_isReviewMode)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 4),
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          border: Border.all(
                                              color: Colors.amber.shade200),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: [
                                            Text(
                                              '#${index + 1} Relevance:',
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                            const Spacer(),
                                            _ratingButton(
                                                place,
                                                index + 1,
                                                'Relevant',
                                                Colors.green,
                                                currentRating == 'Relevant'),
                                            const SizedBox(width: 4),
                                            _ratingButton(
                                                place,
                                                index + 1,
                                                'Partial',
                                                Colors.orange,
                                                currentRating == 'Partial'),
                                            const SizedBox(width: 4),
                                            _ratingButton(
                                                place,
                                                index + 1,
                                                'Irrelevant',
                                                Colors.red,
                                                currentRating == 'Irrelevant'),
                                            const SizedBox(width: 4),
                                            _ratingButton(
                                                place,
                                                index + 1,
                                                'Unsure',
                                                Colors.grey,
                                                currentRating == 'Unsure'),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _ratingButton(LabPlace place, int rank, String label,
      MaterialColor color, bool isSelected) {
    return InkWell(
      onTap: () => _rateResult(place, rank, label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? color.shade100 : Colors.grey.shade50,
          border: Border.all(
              color: isSelected ? color.shade700 : Colors.grey.shade300,
              width: isSelected ? 1.5 : 1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? color.shade900 : Colors.grey.shade800,
          ),
        ),
      ),
    );
  }
}
