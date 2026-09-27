import 'package:flutter/material.dart';
import '../app/app_state.dart';
import '../domain/lab_place.dart';
import '../domain/qa_session.dart';

class ExpectedPlacesScreen extends StatefulWidget {
  final AppState state;

  const ExpectedPlacesScreen({super.key, required this.state});

  @override
  State<ExpectedPlacesScreen> createState() => _ExpectedPlacesScreenState();
}

class _ExpectedPlacesScreenState extends State<ExpectedPlacesScreen> {
  final TextEditingController _queryController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  List<LabPlace> _searchResults = [];
  bool _isSearching = false;
  LabPlace? _matchedPlace;

  @override
  void dispose() {
    _queryController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _searchExpected() async {
    final term = _queryController.text.trim();
    if (term.isEmpty) return;

    final repo = widget.state.repository;
    if (repo == null) return;

    setState(() {
      _isSearching = true;
      _searchResults = [];
      _matchedPlace = null;
    });

    final results = await repo.search(query: term, limit: 10);
    if (mounted) {
      setState(() {
        _searchResults = results;
        if (results.isNotEmpty) {
          _matchedPlace = results.first;
        }
        _isSearching = false;
      });
    }
  }

  void _recordCheck(String status) {
    final query = _queryController.text.trim();
    if (query.isEmpty) return;

    final record = ExpectedPlaceCheckRecord(
      query: query,
      placeId: _matchedPlace?.id,
      placeName: _matchedPlace?.name,
      status: status,
      note: _noteController.text.trim().isNotEmpty
          ? _noteController.text.trim()
          : null,
      timestamp: DateTime.now().toIso8601String(),
    );

    widget.state.addExpectedPlaceCheck(record);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Marked "$query" as ${status.toUpperCase()}'),
        duration: const Duration(seconds: 2),
      ),
    );

    setState(() {
      _queryController.clear();
      _noteController.clear();
      _searchResults = [];
      _matchedPlace = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.state.currentSession;
    final pastChecks = session?.expectedPlaceChecks ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expected Places Check'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Verify Landmark Recall & Accuracy',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Type a known landmark (e.g. "Hadimba Temple", "Solang Valley", "Basilica of Bom Jesus"). The Lab searches only this City Pack.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 16),

            // Search box
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _queryController,
                    decoration: const InputDecoration(
                      labelText: 'Expected Place Name',
                      hintText: 'e.g. Hadimba Temple',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _searchExpected(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _searchExpected,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                  ),
                  child: const Text('Search'),
                ),
              ],
            ),

            const SizedBox(height: 16),

            if (_isSearching)
              const Center(child: CircularProgressIndicator())
            else if (_searchResults.isNotEmpty) ...[
              const Text('Top Match in Dataset:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _matchedPlace!.name,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'ID: ${_matchedPlace!.id} • Tier: ${_matchedPlace!.tier.toUpperCase()}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        'Category: ${_matchedPlace!.category} • Coords: ${_matchedPlace!.latitude.toStringAsFixed(4)}, ${_matchedPlace!.longitude.toStringAsFixed(4)}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      if (_matchedPlace!.address != null)
                        Text('Address: ${_matchedPlace!.address!}',
                            style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Note input
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Tester Observation / Note',
                hintText: 'e.g. Exists but classified under wrong tier',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            // 3 Decision Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _recordCheck('found'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('FOUND'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _recordCheck('found_but_wrong'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade800,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('DATA WRONG'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _recordCheck('not_found'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('NOT FOUND'),
                  ),
                ),
              ],
            ),

            const Divider(height: 40),

            // History of Checks
            Text(
              'Expected Places Checked (${pastChecks.length})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (pastChecks.isEmpty)
              const Text('No expected place checks recorded yet in this session.')
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: pastChecks.length,
                itemBuilder: (context, index) {
                  final check = pastChecks[pastChecks.length - 1 - index];
                  Color statusColor = Colors.green;
                  if (check.status == 'found_but_wrong') {
                    statusColor = Colors.orange;
                  } else if (check.status == 'not_found') {
                    statusColor = Colors.red;
                  }

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      title: Text(check.query,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        'Matched: ${check.placeName ?? "None"}\n${check.note ?? ""}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withAlpha(30),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: statusColor),
                        ),
                        child: Text(
                          check.status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
