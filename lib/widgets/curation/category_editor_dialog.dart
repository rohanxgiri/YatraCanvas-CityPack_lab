import 'package:flutter/material.dart';
import '../../domain/curation/curated_place.dart';

class CategoryEditorDialog extends StatefulWidget {
  final CuratedPlace place;
  final Function({required String category, String? subcategory, required String evidenceSource}) onSave;

  const CategoryEditorDialog({
    super.key,
    required this.place,
    required this.onSave,
  });

  static Future<void> show(
    BuildContext context, {
    required CuratedPlace place,
    required Function({required String category, String? subcategory, required String evidenceSource}) onSave,
  }) {
    return showDialog(
      context: context,
      builder: (_) => CategoryEditorDialog(place: place, onSave: onSave),
    );
  }

  @override
  State<CategoryEditorDialog> createState() => _CategoryEditorDialogState();
}

class _CategoryEditorDialogState extends State<CategoryEditorDialog> {
  static const List<String> standardCategories = [
    'heritage',
    'museum',
    'religious',
    'park',
    'nature',
    'viewpoint',
    'arts_culture',
    'food',
    'cafe',
    'shopping',
    'hotel',
    'experience',
    'transport',
    'entertainment',
  ];

  late String _selectedCategory;
  late final TextEditingController _subcategoryController;
  late final TextEditingController _reasonController;

  @override
  void initState() {
    super.initState();
    _selectedCategory = standardCategories.contains(widget.place.category)
        ? widget.place.category
        : standardCategories.first;
    _subcategoryController = TextEditingController(text: widget.place.subcategory ?? '');
    _reasonController = TextEditingController(text: 'Reclassified to match real venue type and YatraCanvas taxonomy');
  }

  @override
  void dispose() {
    _subcategoryController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.category_outlined, color: Colors.purple),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Fix Category Taxonomy', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
          width: 450,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Current classification
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Current: ${widget.place.category} ${widget.place.subcategory != null ? "(${widget.place.subcategory})" : ""}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Category Selector
              const Text('Primary Category (YatraCanvas Taxonomy):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                isExpanded: true,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: standardCategories.map((c) {
                  return DropdownMenuItem(
                    value: c,
                    child: Text(c.toUpperCase(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedCategory = val);
                },
              ),
              const SizedBox(height: 12),

              // Subcategory input
              const Text('Specific Subcategory / Entity Type:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: _subcategoryController,
                decoration: InputDecoration(
                  hintText: 'e.g. temple, fort, bakery, art_gallery, waterfall',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 12),

              // Reason
              const Text('Reason for Correction:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: _reasonController,
                decoration: InputDecoration(
                  hintText: 'Why is this new category appropriate?',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
          label: const Text('Save Category'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            final reason = _reasonController.text.trim();
            final sub = _subcategoryController.text.trim();
            widget.onSave(
              category: _selectedCategory,
              subcategory: sub.isNotEmpty ? sub : null,
              evidenceSource: reason.isNotEmpty ? reason : 'Taxonomy Alignment',
            );
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}
