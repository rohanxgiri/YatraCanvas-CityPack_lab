import 'package:flutter/material.dart';

import '../../domain/curation/place_addition.dart';

class AddPlaceWizardDialog extends StatefulWidget {
  final String cityId;
  final Map<String, dynamic>? bbox;
  final Function(PlaceAddition) onAdd;

  const AddPlaceWizardDialog({
    super.key,
    required this.cityId,
    this.bbox,
    required this.onAdd,
  });

  static Future<void> show(
    BuildContext context, {
    required String cityId,
    Map<String, dynamic>? bbox,
    required Function(PlaceAddition) onAdd,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          AddPlaceWizardDialog(cityId: cityId, bbox: bbox, onAdd: onAdd),
    );
  }

  @override
  State<AddPlaceWizardDialog> createState() => _AddPlaceWizardDialogState();
}

class _AddPlaceWizardDialogState extends State<AddPlaceWizardDialog> {
  int _currentStep = 0;

  // Controllers
  final _nameController = TextEditingController();
  final _nameHiController = TextEditingController();
  String _category = 'heritage';
  final _subcategoryController = TextEditingController();
  String _tier = 'recommended';

  final _latController = TextEditingController();
  final _lonController = TextEditingController();
  final _addressController = TextEditingController();

  final _descController = TextEditingController();
  final _hoursController = TextEditingController();
  final _websiteController = TextEditingController();
  final _phoneController = TextEditingController();
  final _evidenceController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _nameHiController.dispose();
    _subcategoryController.dispose();
    _latController.dispose();
    _lonController.dispose();
    _addressController.dispose();
    _descController.dispose();
    _hoursController.dispose();
    _websiteController.dispose();
    _phoneController.dispose();
    _evidenceController.dispose();
    super.dispose();
  }

  void _finish() {
    final lat = double.tryParse(_latController.text.trim());
    final lon = double.tryParse(_lonController.text.trim());
    if (lat == null ||
        lon == null ||
        !lat.isFinite ||
        !lon.isFinite ||
        lat.abs() > 90 ||
        lon.abs() > 180) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid latitude and longitude.')),
      );
      return;
    }
    if (_evidenceController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add source evidence for this new place.'),
        ),
      );
      return;
    }
    final now = DateTime.now();

    final addition = PlaceAddition(
      id: 'manual_${widget.cityId}_${now.millisecondsSinceEpoch}',
      cityId: widget.cityId,
      name: _nameController.text.trim(),
      nameHi: _nameHiController.text.trim().isNotEmpty
          ? _nameHiController.text.trim()
          : null,
      category: _category,
      subcategory: _subcategoryController.text.trim().isNotEmpty
          ? _subcategoryController.text.trim()
          : null,
      tier: _tier,
      latitude: lat,
      longitude: lon,
      address: _addressController.text.trim().isNotEmpty
          ? _addressController.text.trim()
          : null,
      description: _descController.text.trim().isNotEmpty
          ? _descController.text.trim()
          : null,
      openingHours: _hoursController.text.trim().isNotEmpty
          ? _hoursController.text.trim()
          : null,
      website: _websiteController.text.trim().isNotEmpty
          ? _websiteController.text.trim()
          : null,
      phone: _phoneController.text.trim().isNotEmpty
          ? _phoneController.text.trim()
          : null,
      author: 'Contributor',
      createdAt: now.toIso8601String(),
      evidenceSource: _evidenceController.text.trim().isNotEmpty
          ? _evidenceController.text.trim()
          : 'Manual Curation',
    );

    widget.onAdd(addition);
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added new place "${addition.name}"'),
        backgroundColor: Colors.green.shade800,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.add_location_alt,
              color: Colors.green,
              size: 20,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Add Missing Place (Step-by-Step)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SizedBox(
        width: 540,
        height: 480,
        child: Stepper(
          type: StepperType.horizontal,
          currentStep: _currentStep,
          onStepContinue: () {
            if (_currentStep == 0 && _nameController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter place name')),
              );
              return;
            }
            if (_currentStep < 4) {
              setState(() => _currentStep++);
            } else {
              _finish();
            }
          },
          onStepCancel: () {
            if (_currentStep > 0) {
              setState(() => _currentStep--);
            } else {
              Navigator.of(context).pop();
            }
          },
          steps: [
            Step(
              title: const Text('Identity', style: TextStyle(fontSize: 10)),
              isActive: _currentStep >= 0,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Place Name (English)*',
                      hintText: 'e.g. Nahargarh Biological Park',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameHiController,
                    decoration: const InputDecoration(
                      labelText: 'Name (Hindi / Local Script)',
                      hintText: 'e.g. नाहरगढ़ जैविक उद्यान',
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    decoration: const InputDecoration(
                      labelText: 'Primary Category',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'heritage',
                        child: Text('HERITAGE / MONUMENT'),
                      ),
                      DropdownMenuItem(value: 'museum', child: Text('MUSEUM')),
                      DropdownMenuItem(
                        value: 'religious',
                        child: Text('RELIGIOUS / TEMPLE'),
                      ),
                      DropdownMenuItem(
                        value: 'park',
                        child: Text('PARK / GARDEN'),
                      ),
                      DropdownMenuItem(
                        value: 'nature',
                        child: Text('NATURE / SCENIC'),
                      ),
                      DropdownMenuItem(
                        value: 'viewpoint',
                        child: Text('VIEWPOINT'),
                      ),
                      DropdownMenuItem(
                        value: 'food',
                        child: Text('FOOD / RESTAURANT'),
                      ),
                      DropdownMenuItem(value: 'cafe', child: Text('CAFE')),
                      DropdownMenuItem(
                        value: 'shopping',
                        child: Text('SHOPPING / BAZAAR'),
                      ),
                      DropdownMenuItem(
                        value: 'experience',
                        child: Text('EXPERIENCE / ACTIVITY'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _category = val);
                    },
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _tier,
                    decoration: const InputDecoration(
                      labelText: 'Importance / Tier',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'core_destination',
                        child: Text('CORE DESTINATION (Flagship)'),
                      ),
                      DropdownMenuItem(
                        value: 'recommended',
                        child: Text('RECOMMENDED (Standard)'),
                      ),
                      DropdownMenuItem(
                        value: 'discovery',
                        child: Text('DISCOVERY (Lesser-known)'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _tier = val);
                    },
                  ),
                ],
              ),
            ),
            Step(
              title: const Text('Location', style: TextStyle(fontSize: 10)),
              isActive: _currentStep >= 1,
              content: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _latController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Latitude (WGS84)*',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _lonController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Longitude (WGS84)*',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _addressController,
                    decoration: const InputDecoration(
                      labelText: 'Street Address',
                      hintText: 'e.g. Amber Road, Jaipur',
                    ),
                  ),
                ],
              ),
            ),
            Step(
              title: const Text('Details', style: TextStyle(fontSize: 10)),
              isActive: _currentStep >= 2,
              content: Column(
                children: [
                  TextField(
                    controller: _descController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'Highlights and visitor tips...',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _hoursController,
                    decoration: const InputDecoration(
                      labelText: 'Opening Hours',
                      hintText: 'e.g. 09:00-18:00',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _evidenceController,
                    decoration: const InputDecoration(
                      labelText: 'Evidence / Source Link*',
                      hintText: 'e.g. Official government registry or URL',
                    ),
                  ),
                ],
              ),
            ),
            Step(
              title: const Text('Media', style: TextStyle(fontSize: 10)),
              isActive: _currentStep >= 3,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Save this place, then use its photo curator to import a real image with provenance.',
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.blue),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'If no image is ready right now, you can add it later via Fix Center.',
                            style: TextStyle(fontSize: 11, color: Colors.blue),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Step(
              title: const Text('Review', style: TextStyle(fontSize: 10)),
              isActive: _currentStep >= 4,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Summary of New Place:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Text('• Name: ${_nameController.text.trim()}'),
                  Text('• Category: ${_category.toUpperCase()}'),
                  Text('• Tier: ${_tier.toUpperCase()}'),
                  Text(
                    '• Location: ${_latController.text.trim()}, ${_lonController.text.trim()}',
                  ),
                  Text('• Hours: ${_hoursController.text.trim()}'),
                  Text('• Evidence: ${_evidenceController.text.trim()}'),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: const Text(
                      'This place will be recorded with provenance tag [MANUAL ADDITION] and saved to Git-tracked curation storage.',
                      style: TextStyle(fontSize: 11, color: Colors.brown),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
