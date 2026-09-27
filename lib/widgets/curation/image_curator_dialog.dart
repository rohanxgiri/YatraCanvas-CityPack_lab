import 'package:flutter/material.dart';
import '../../domain/curation/curated_place.dart';

class ImageCuratorDialog extends StatefulWidget {
  final CuratedPlace place;
  final Function({required String? primaryImagePath, required String evidenceSource}) onSave;
  final Function(String issueType, String note) onFlag;

  const ImageCuratorDialog({
    super.key,
    required this.place,
    required this.onSave,
    required this.onFlag,
  });

  static Future<void> show(
    BuildContext context, {
    required CuratedPlace place,
    required Function({required String? primaryImagePath, required String evidenceSource}) onSave,
    required Function(String issueType, String note) onFlag,
  }) {
    return showDialog(
      context: context,
      builder: (_) => ImageCuratorDialog(place: place, onSave: onSave, onFlag: onFlag),
    );
  }

  @override
  State<ImageCuratorDialog> createState() => _ImageCuratorDialogState();
}

class _ImageCuratorDialogState extends State<ImageCuratorDialog> {
  late final TextEditingController _pathController;
  late final TextEditingController _sourceController;
  late final TextEditingController _authorController;
  String _selectedLicense = 'CC-BY-SA 4.0';

  @override
  void initState() {
    super.initState();
    _pathController = TextEditingController(text: widget.place.primaryImagePath ?? 'images/${widget.place.id}/primary.webp');
    _sourceController = TextEditingController(text: 'Wikimedia Commons / High Quality Tourist Media');
    _authorController = TextEditingController(text: 'Open Source Contributor');
  }

  @override
  void dispose() {
    _pathController.dispose();
    _sourceController.dispose();
    _authorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasImg = widget.place.hasImage;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.photo_library_outlined, color: Colors.teal),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Curate Place Image', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
              // Image status header
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: hasImg ? Colors.teal.shade50 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: hasImg ? Colors.teal.shade200 : Colors.orange.shade300),
                ),
                child: Row(
                  children: [
                    Icon(
                      hasImg ? Icons.image : Icons.broken_image,
                      color: hasImg ? Colors.teal.shade700 : Colors.orange.shade800,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hasImg ? 'Primary image configured' : 'Missing hero photo',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: hasImg ? Colors.teal.shade900 : Colors.orange.shade900,
                            ),
                          ),
                          if (hasImg)
                            Text(
                              widget.place.primaryImagePath!,
                              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Quick Verification / Flag Buttons
              if (hasImg) ...[
                const Text('Quick Quality Review:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.thumb_up_alt_outlined, size: 14, color: Colors.green),
                        label: const Text('Mark Correct', style: TextStyle(fontSize: 11)),
                        onPressed: () {
                          widget.onSave(
                            primaryImagePath: widget.place.primaryImagePath,
                            evidenceSource: 'Human reviewer confirmed image accurately depicts destination',
                          );
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.wrong_location_outlined, size: 14, color: Colors.red),
                        label: const Text('Wrong Place', style: TextStyle(fontSize: 11)),
                        onPressed: () {
                          widget.onFlag('wrong_image', 'Image depicts wrong monument/place');
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.blur_off_outlined, size: 14, color: Colors.orange),
                        label: const Text('Poor Quality', style: TextStyle(fontSize: 11)),
                        onPressed: () {
                          widget.onFlag('wrong_image', 'Image is low-resolution, blurry or watermarked');
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // Replace / Assign Image Section
              const Text('Add or Replace Image Path:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: _pathController,
                decoration: InputDecoration(
                  hintText: 'e.g. images/<place_id>/primary.webp or relative path',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 12),

              // Author & License
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Author / Photographer:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _authorController,
                          decoration: InputDecoration(
                            hintText: 'Photographer name or handle',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                        const Text('Open License:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(height: 4),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedLicense,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'CC-BY-SA 4.0', child: Text('CC-BY-SA 4.0', style: TextStyle(fontSize: 12))),
                            DropdownMenuItem(value: 'CC-BY 4.0', child: Text('CC-BY 4.0', style: TextStyle(fontSize: 12))),
                            DropdownMenuItem(value: 'CC0 / Public Domain', child: Text('CC0 / Public Domain', style: TextStyle(fontSize: 12))),
                            DropdownMenuItem(value: 'ODbL', child: Text('ODbL', style: TextStyle(fontSize: 12))),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedLicense = val);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Source evidence
              const Text('Source / Attribution URL:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: _sourceController,
                decoration: InputDecoration(
                  hintText: 'e.g. https://commons.wikimedia.org/wiki/File:...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (hasImg)
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              widget.onSave(
                primaryImagePath: '',
                evidenceSource: 'Removed inappropriate or broken image',
              );
              Navigator.of(context).pop();
            },
            child: const Text('Remove Image'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.check, size: 16),
          label: const Text('Save Photo Info'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            final path = _pathController.text.trim();
            final source = _sourceController.text.trim();
            if (path.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please specify image path')),
              );
              return;
            }
            widget.onSave(
              primaryImagePath: path,
              evidenceSource: '$source [License: $_selectedLicense, Author: ${_authorController.text.trim()}]',
            );
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}
