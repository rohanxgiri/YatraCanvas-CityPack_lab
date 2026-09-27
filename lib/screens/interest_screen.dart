import 'package:flutter/material.dart';
import '../app/app_state.dart';
import 'discover_screen.dart';

class InterestScreen extends StatefulWidget {
  final AppState state;

  const InterestScreen({super.key, required this.state});

  @override
  State<InterestScreen> createState() => _InterestScreenState();
}

class _InterestScreenState extends State<InterestScreen> {
  final Set<String> _selected = {};
  Map<String, int> _categories = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  void _loadCategories() async {
    if (widget.state.repository == null) return;
    final cats = await widget.state.repository!.getCategories(onlyTravelRelevant: false);
    if (mounted) {
      setState(() {
        _categories = cats;
        _isLoading = false;
      });
    }
  }

  void _proceed([bool skip = false]) {
    if (!skip) {
      widget.state.setUserInterests(_selected);
    } else {
      widget.state.setUserInterests({});
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => DiscoverScreen(state: widget.state),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pack = widget.state.activePack;

    return Scaffold(
      appBar: AppBar(
        title: Text('Interests: ${pack?.name ?? "City"}'),
        actions: [
          TextButton(
            onPressed: () => _proceed(true),
            child: const Text('Skip', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'What would you like to explore?',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Select travel themes to test how ${pack?.name}\'s dataset organizes recommended places.',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _categories.entries.map((entry) {
                          final cat = entry.key;
                          final count = entry.value;
                          final isSelected = _selected.contains(cat);

                          return FilterChip(
                            selected: isSelected,
                            label: Text(
                              '${cat.toUpperCase()} ($count)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            selectedColor: Colors.indigo.shade100,
                            checkmarkColor: Colors.indigo,
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selected.add(cat);
                                } else {
                                  _selected.remove(cat);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => _proceed(false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        _selected.isEmpty
                            ? 'Continue to Discover'
                            : 'Explore ${_selected.length} Interests',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
