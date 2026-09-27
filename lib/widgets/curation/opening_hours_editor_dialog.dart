import 'package:flutter/material.dart';
import '../../domain/curation/curated_place.dart';

class OpeningHoursEditorDialog extends StatefulWidget {
  final CuratedPlace place;
  final Function({required String openingHours, required String evidenceSource}) onSave;

  const OpeningHoursEditorDialog({
    super.key,
    required this.place,
    required this.onSave,
  });

  static Future<void> show(
    BuildContext context, {
    required CuratedPlace place,
    required Function({required String openingHours, required String evidenceSource}) onSave,
  }) {
    return showDialog(
      context: context,
      builder: (_) => OpeningHoursEditorDialog(place: place, onSave: onSave),
    );
  }

  @override
  State<OpeningHoursEditorDialog> createState() => _OpeningHoursEditorDialogState();
}

class _OpeningHoursEditorDialogState extends State<OpeningHoursEditorDialog> {
  late final TextEditingController _customController;
  late final TextEditingController _sourceController;
  String _selectedPreset = 'custom';

  final List<String> _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final Map<String, String> _dayHours = {
    'Mon': '09:00-17:00',
    'Tue': '09:00-17:00',
    'Wed': '09:00-17:00',
    'Thu': '09:00-17:00',
    'Fri': '09:00-17:00',
    'Sat': '09:00-17:00',
    'Sun': '09:00-17:00',
  };

  @override
  void initState() {
    super.initState();
    _customController = TextEditingController(text: widget.place.openingHours ?? '09:00-17:00');
    _sourceController = TextEditingController(text: 'Official website / On-site notice board');
  }

  @override
  void dispose() {
    _customController.dispose();
    _sourceController.dispose();
    super.dispose();
  }

  void _applyPreset(String preset) {
    setState(() {
      _selectedPreset = preset;
      switch (preset) {
        case 'standard':
          _customController.text = '09:00-18:00';
          break;
        case 'museum':
          _customController.text = 'Mon-Sat: 09:30-17:00; Sun: Closed';
          break;
        case 'restaurant':
          _customController.text = '11:00-23:00';
          break;
        case '24hours':
          _customController.text = 'Open 24 Hours';
          break;
        case 'closed':
          _customController.text = 'Closed';
          break;
      }
    });
  }

  void _copyToAll(String hours) {
    setState(() {
      for (final d in _days) {
        _dayHours[d] = hours;
      }
      _customController.text = 'Daily: $hours';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.access_time_filled, color: Colors.indigo),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Edit Opening Hours', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(
                  widget.place.name,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 480,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Current value pill
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.history, size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.place.openingHours != null
                            ? 'Current value: ${widget.place.openingHours}'
                            : 'Currently missing opening hours',
                        style: TextStyle(
                          fontSize: 12,
                          color: widget.place.openingHours != null ? Colors.black87 : Colors.red.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Quick Presets
              const Text('Quick Presets:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _presetChip('standard', '9 AM - 6 PM'),
                  _presetChip('museum', 'Museum (Mon-Sat)'),
                  _presetChip('restaurant', 'Dining (11 AM - 11 PM)'),
                  _presetChip('24hours', 'Open 24/7'),
                  _presetChip('closed', 'Closed'),
                ],
              ),
              const SizedBox(height: 16),

              // Formatted Value Input
              const Text('Opening Hours Value:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: _customController,
                decoration: InputDecoration(
                  hintText: 'e.g. 09:00-18:00 or Mon-Sun: 09:30-17:30',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 12),

              // Evidence / Source field
              const Text('Source / Verification Evidence:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: _sourceController,
                decoration: InputDecoration(
                  hintText: 'e.g. Official website link, Google Maps listing, On-site signboard',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 12),

              // Day-by-Day Quick Setter helper
              ExpansionTile(
                title: const Text('Day-by-Day Helper', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                tilePadding: EdgeInsets.zero,
                children: [
                  ..._days.map((day) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            SizedBox(width: 45, child: Text(day, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                            Expanded(
                              child: Text(_dayHours[day] ?? 'Closed', style: const TextStyle(fontSize: 12)),
                            ),
                            TextButton(
                              onPressed: () => _copyToAll(_dayHours[day] ?? '09:00-17:00'),
                              child: const Text('Apply to all', style: TextStyle(fontSize: 11)),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.check, size: 16),
          label: const Text('Save Correction'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            final text = _customController.text.trim();
            final source = _sourceController.text.trim();
            if (text.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter opening hours')),
              );
              return;
            }
            widget.onSave(
              openingHours: text,
              evidenceSource: source.isNotEmpty ? source : 'Manual Contributor Entry',
            );
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }

  Widget _presetChip(String id, String label) {
    final selected = _selectedPreset == id;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 11, color: selected ? Colors.white : Colors.black87)),
      selected: selected,
      selectedColor: Colors.indigo,
      onSelected: (_) => _applyPreset(id),
    );
  }
}
