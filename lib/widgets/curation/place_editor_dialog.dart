import 'package:flutter/material.dart';

import '../../domain/curation/curated_place.dart';

class PlaceEditorDialog extends StatefulWidget {
  final CuratedPlace place;
  final Function({
    required String name,
    String? nameHi,
    String? description,
    String? website,
    String? phone,
    String? tier,
    required String evidenceSource,
  })
  onSave;

  const PlaceEditorDialog({
    super.key,
    required this.place,
    required this.onSave,
  });

  static Future<void> show(
    BuildContext context, {
    required CuratedPlace place,
    required Function({
      required String name,
      String? nameHi,
      String? description,
      String? website,
      String? phone,
      String? tier,
      required String evidenceSource,
    })
    onSave,
  }) {
    return showDialog(
      context: context,
      builder: (_) => PlaceEditorDialog(place: place, onSave: onSave),
    );
  }

  @override
  State<PlaceEditorDialog> createState() => _PlaceEditorDialogState();
}

class _PlaceEditorDialogState extends State<PlaceEditorDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _nameHiController;
  late final TextEditingController _descController;
  late final TextEditingController _websiteController;
  late final TextEditingController _phoneController;
  late final TextEditingController _sourceController;
  late String _selectedTier;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.place.name);
    _nameHiController = TextEditingController(text: widget.place.nameHi ?? '');
    _descController = TextEditingController(
      text: widget.place.description ?? '',
    );
    _websiteController = TextEditingController(
      text: widget.place.website ?? '',
    );
    _phoneController = TextEditingController(text: widget.place.phone ?? '');
    _sourceController = TextEditingController(
      text: 'Manual contributor correction',
    );
    _selectedTier = widget.place.tier;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameHiController.dispose();
    _descController.dispose();
    _websiteController.dispose();
    _phoneController.dispose();
    _sourceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.edit_note, color: Colors.blueAccent),
          const SizedBox(width: 8),
          const Text(
            'Edit Place Details',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 500,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // English Name
              const Text(
                'Place Name (English):',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Hindi Name
              const Text(
                'Name (Hindi / Local Script):',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _nameHiController,
                decoration: InputDecoration(
                  hintText: 'e.g. हवा महल',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Tier selector
              const Text(
                'Tourism Tier / Prominence:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _selectedTier,
                isExpanded: true,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'core_destination',
                    child: Text('CORE DESTINATION (Flagship Landmark)'),
                  ),
                  DropdownMenuItem(
                    value: 'recommended',
                    child: Text('RECOMMENDED (Standard Sight / Dining)'),
                  ),
                  DropdownMenuItem(
                    value: 'discovery',
                    child: Text('DISCOVERY (Lesser-known spot)'),
                  ),
                  DropdownMenuItem(
                    value: 'support',
                    child: Text('SUPPORT (Transit / Facility)'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedTier = val);
                },
              ),
              const SizedBox(height: 12),

              // Description
              const Text(
                'Short Description:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _descController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText:
                      'Brief summary of what travelers can see and do here...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.all(10),
                ),
              ),
              const SizedBox(height: 12),

              // Website & Phone
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Official Website:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _websiteController,
                          decoration: InputDecoration(
                            hintText: 'https://...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Phone Number:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _phoneController,
                          decoration: InputDecoration(
                            hintText: '+91 ...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Source
              const Text(
                'Source Evidence:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _sourceController,
                decoration: InputDecoration(
                  hintText: 'e.g. Official brochure, Rajasthan Tourism Portal',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
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
        ElevatedButton.icon(
          icon: const Icon(Icons.check, size: 16),
          label: const Text('Save Details'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent.shade700,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            final name = _nameController.text.trim();
            if (name.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Name cannot be empty')),
              );
              return;
            }

            widget.onSave(
              name: name,
              nameHi: _nameHiController.text.trim().isNotEmpty
                  ? _nameHiController.text.trim()
                  : null,
              description: _descController.text.trim().isNotEmpty
                  ? _descController.text.trim()
                  : null,
              website: _websiteController.text.trim().isNotEmpty
                  ? _websiteController.text.trim()
                  : null,
              phone: _phoneController.text.trim().isNotEmpty
                  ? _phoneController.text.trim()
                  : null,
              tier: _selectedTier,
              evidenceSource: _sourceController.text.trim().isNotEmpty
                  ? _sourceController.text.trim()
                  : 'Manual CMS Edit',
            );
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}
