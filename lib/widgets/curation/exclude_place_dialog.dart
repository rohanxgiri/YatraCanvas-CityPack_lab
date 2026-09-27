import 'package:flutter/material.dart';
import '../../domain/curation/curated_place.dart';

class ExcludePlaceDialog extends StatefulWidget {
  final CuratedPlace place;
  final Function({required String reason, String? notes}) onConfirm;

  const ExcludePlaceDialog({
    super.key,
    required this.place,
    required this.onConfirm,
  });

  static Future<void> show(
    BuildContext context, {
    required CuratedPlace place,
    required Function({required String reason, String? notes}) onConfirm,
  }) {
    return showDialog(
      context: context,
      builder: (_) => ExcludePlaceDialog(place: place, onConfirm: onConfirm),
    );
  }

  @override
  State<ExcludePlaceDialog> createState() => _ExcludePlaceDialogState();
}

class _ExcludePlaceDialogState extends State<ExcludePlaceDialog> {
  String _selectedReason = 'closed_permanently';
  final _notesController = TextEditingController();

  final Map<String, String> _reasons = {
    'closed_permanently': 'Permanently closed / Defunct venue',
    'restricted_private': 'Restricted / Private facility (not accessible to public)',
    'institutional_canteen': 'Institutional canteen / Staff cafeteria',
    'duplicate': 'Duplicate record of another primary POI',
    'non_tourist_utility': 'Utility or municipal office (no tourist value)',
    'bad_source': 'Unverified or corrupt upstream record',
    'other': 'Other inappropriate destination',
  };

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.block, color: Colors.red),
          const SizedBox(width: 8),
          const Text('Exclude Place from Release', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 450,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Exclude "${widget.place.name}" from travel itineraries and certified release datasets?',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),

              // Reason dropdown
              const Text('Mandatory Exclusion Reason:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _selectedReason,
                isExpanded: true,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                items: _reasons.entries.map((e) {
                  return DropdownMenuItem(
                    value: e.key,
                    child: Text(e.value, style: const TextStyle(fontSize: 12)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedReason = val);
                },
              ),
              const SizedBox(height: 12),

              // Notes
              const Text('Additional Notes / Context:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: _notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'e.g. Building demolished, site now private housing society...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.all(10),
                ),
              ),
              const SizedBox(height: 14),

              // Safety notice
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.shield_outlined, size: 16, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Reversible Action: The raw database remains untouched. This stores a reversible exclusion in curation/exclusions/ that can be undone anytime.',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                      ),
                    ),
                  ],
                ),
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
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade700,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            widget.onConfirm(
              reason: _selectedReason,
              notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
            );
            Navigator.of(context).pop();
          },
          child: const Text('Confirm Exclusion'),
        ),
      ],
    );
  }
}
