import 'package:flutter/material.dart';
import '../app/app_state.dart';
import '../domain/qa_session.dart';

class ScenarioTestingScreen extends StatefulWidget {
  final AppState state;

  const ScenarioTestingScreen({super.key, required this.state});

  @override
  State<ScenarioTestingScreen> createState() => _ScenarioTestingScreenState();
}

class _ScenarioTestingScreenState extends State<ScenarioTestingScreen> {
  final TextEditingController _scenarioNameController =
      TextEditingController(text: '3-Day First-Timer Leisure Trip');
  final TextEditingController _notesController = TextEditingController();

  int _days = 3;
  final Set<String> _selectedInterests = {'nature', 'heritage', 'food'};
  String _trustRating = 'mostly'; // 'yes', 'mostly', 'no'

  final List<String> _steps = [
    '1. Inspect top recommendations on Discover feed',
    '2. Browse selected interest sections (Nature, Heritage, Food)',
    '3. Search natural queries (e.g. waterfall, cafe, viewpoint)',
    '4. Select 8–12 realistic places into Test Trip',
    '5. Review geographical spread on Trip Map',
    '6. Check for POI anomalies, far-away outliers, duplicate names',
    '7. Answer the final trust judgment question below',
  ];

  @override
  void dispose() {
    _scenarioNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _saveScenarioResult() {
    final pack = widget.state.activePack;
    if (pack == null) return;

    final tripPlacesCount = widget.state.tripSelection?.placeDays.length ?? 0;

    final record = ScenarioResultRecord(
      scenarioName: _scenarioNameController.text.trim(),
      days: _days,
      interests: _selectedInterests.toList(),
      selectedPlacesCount: tripPlacesCount,
      trusted: _trustRating,
      notes: _notesController.text.trim(),
      timestamp: DateTime.now().toIso8601String(),
    );

    widget.state.addScenarioResult(record);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Scenario "${record.scenarioName}" saved to QA Session.'),
        backgroundColor: Colors.green.shade700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pack = widget.state.activePack;
    final pastScenarios = widget.state.currentSession?.scenarioResults ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scenario QA Testing'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Realistic Persona Scenario: ${pack?.name ?? "City"}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Walk through a realistic traveller workflow to evaluate whether the dataset is trustworthy.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
            const Divider(height: 24),

            // Scenario Name
            TextField(
              controller: _scenarioNameController,
              decoration: const InputDecoration(
                labelText: 'Scenario Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // Trip Length
            Row(
              children: [
                const Text('Planned Days: ',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                DropdownButton<int>(
                  value: _days,
                  items: [1, 2, 3, 4, 5, 6, 7].map((d) {
                    return DropdownMenuItem(value: d, child: Text('$d Days'));
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _days = v);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Workflow Guide
            const Text(
              'Recommended QA Evaluation Steps:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _steps.map((step) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Text(step, style: const TextStyle(fontSize: 12)),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 24),

            // The Ultimate QA Question (Phase 22)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.indigo.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Would you trust this City Pack for a real trip?',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _trustOption('YES', 'yes', Colors.green),
                      const SizedBox(width: 8),
                      _trustOption('MOSTLY', 'mostly', Colors.amber.shade800),
                      const SizedBox(width: 8),
                      _trustOption('NO', 'no', Colors.red),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Tester Reasoning & Notes',
                      hintText:
                          'Explain why: e.g. Core places are solid, but several cafes have wrong coordinates...',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saveScenarioResult,
                      icon: const Icon(Icons.save),
                      label: const Text('Save Scenario QA Result'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 36),

            // Past Scenarios
            Text(
              'Completed Scenarios (${pastScenarios.length})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (pastScenarios.isEmpty)
              const Text('No scenario reviews logged yet.')
            else
              ...pastScenarios.map((s) {
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    title: Text(s.scenarioName,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      'Days: ${s.days} • Selected: ${s.selectedPlacesCount} places\nNotes: ${s.notes}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: s.trusted == 'yes'
                            ? Colors.green.shade100
                            : s.trusted == 'mostly'
                                ? Colors.amber.shade100
                                : Colors.red.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'TRUST: ${s.trusted.toUpperCase()}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: s.trusted == 'yes'
                              ? Colors.green.shade900
                              : s.trusted == 'mostly'
                                  ? Colors.amber.shade900
                                  : Colors.red.shade900,
                        ),
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _trustOption(String label, String value, Color color) {
    final isSelected = _trustRating == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _trustRating = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color, width: 1.5),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : color,
            ),
          ),
        ),
      ),
    );
  }
}
