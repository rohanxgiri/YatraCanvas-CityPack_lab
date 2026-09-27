import 'package:flutter/material.dart';
import '../../domain/curation/curated_place.dart';

class CoordinateEditorDialog extends StatefulWidget {
  final CuratedPlace place;
  final Map<String, dynamic>? bbox;
  final Function({required double latitude, required double longitude, required String evidenceSource}) onSave;

  const CoordinateEditorDialog({
    super.key,
    required this.place,
    this.bbox,
    required this.onSave,
  });

  static Future<void> show(
    BuildContext context, {
    required CuratedPlace place,
    Map<String, dynamic>? bbox,
    required Function({required double latitude, required double longitude, required String evidenceSource}) onSave,
  }) {
    return showDialog(
      context: context,
      builder: (_) => CoordinateEditorDialog(place: place, bbox: bbox, onSave: onSave),
    );
  }

  @override
  State<CoordinateEditorDialog> createState() => _CoordinateEditorDialogState();
}

class _CoordinateEditorDialogState extends State<CoordinateEditorDialog> {
  late final TextEditingController _latController;
  late final TextEditingController _lonController;
  late final TextEditingController _sourceController;

  late double _currentLat;
  late double _currentLon;

  @override
  void initState() {
    super.initState();
    _currentLat = widget.place.latitude;
    _currentLon = widget.place.longitude;
    _latController = TextEditingController(text: _currentLat.toStringAsFixed(6));
    _lonController = TextEditingController(text: _currentLon.toStringAsFixed(6));
    _sourceController = TextEditingController(text: 'Visual map alignment / GPS coordinates');
  }

  @override
  void dispose() {
    _latController.dispose();
    _lonController.dispose();
    _sourceController.dispose();
    super.dispose();
  }

  bool _isInsideBounds(double lat, double lon) {
    if (widget.bbox == null) return true;
    final minLat = (widget.bbox!['min_lat'] as num?)?.toDouble();
    final maxLat = (widget.bbox!['max_lat'] as num?)?.toDouble();
    final minLon = (widget.bbox!['min_lon'] as num?)?.toDouble();
    final maxLon = (widget.bbox!['max_lon'] as num?)?.toDouble();

    if (minLat == null || maxLat == null || minLon == null || maxLon == null) return true;
    return lat >= minLat && lat <= maxLat && lon >= minLon && lon <= maxLon;
  }

  void _nudge(double dLat, double dLon) {
    setState(() {
      _currentLat = (_currentLat + dLat);
      _currentLon = (_currentLon + dLon);
      _latController.text = _currentLat.toStringAsFixed(6);
      _lonController.text = _currentLon.toStringAsFixed(6);
    });
  }

  @override
  Widget build(BuildContext context) {
    final inBounds = _isInsideBounds(_currentLat, _currentLon);

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.location_on, color: Colors.deepOrange),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Edit Coordinates', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
              // Boundary status banner
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: inBounds ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: inBounds ? Colors.green.shade200 : Colors.red.shade300),
                ),
                child: Row(
                  children: [
                    Icon(
                      inBounds ? Icons.check_circle : Icons.warning_amber_rounded,
                      color: inBounds ? Colors.green.shade800 : Colors.red.shade800,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        inBounds
                            ? 'Location is within certified city service boundaries.'
                            : 'WARNING: Coordinates are outside city administrative bounding box!',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: inBounds ? Colors.green.shade900 : Colors.red.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Inputs for Latitude and Longitude
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Latitude (WGS84):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _latController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            hintText: 'e.g. 26.912433',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          onChanged: (val) {
                            final parsed = double.tryParse(val);
                            if (parsed != null) setState(() => _currentLat = parsed);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Longitude (WGS84):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _lonController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            hintText: 'e.g. 75.787271',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          onChanged: (val) {
                            final parsed = double.tryParse(val);
                            if (parsed != null) setState(() => _currentLon = parsed);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Fine-Tuning Pin Nudge Controller (~100m)
              const Text('Fine-Tune Pin Alignment (100m steps):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              Center(
                child: SizedBox(
                  width: 180,
                  child: Column(
                    children: [
                      IconButton.filledTonal(
                        icon: const Icon(Icons.keyboard_arrow_up),
                        tooltip: 'Nudge North (+0.001°)',
                        onPressed: () => _nudge(0.001, 0.0),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton.filledTonal(
                            icon: const Icon(Icons.keyboard_arrow_left),
                            tooltip: 'Nudge West (-0.001°)',
                            onPressed: () => _nudge(0.0, -0.001),
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.pin_drop, size: 20, color: Colors.deepOrange),
                          ),
                          IconButton.filledTonal(
                            icon: const Icon(Icons.keyboard_arrow_right),
                            tooltip: 'Nudge East (+0.001°)',
                            onPressed: () => _nudge(0.0, 0.001),
                          ),
                        ],
                      ),
                      IconButton.filledTonal(
                        icon: const Icon(Icons.keyboard_arrow_down),
                        tooltip: 'Nudge South (-0.001°)',
                        onPressed: () => _nudge(-0.001, 0.0),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Evidence source
              const Text('Source / Evidence:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: _sourceController,
                decoration: InputDecoration(
                  hintText: 'e.g. Adjusted pin to correct entrance gate via satellite map',
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
          label: const Text('Save Coordinates'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepOrange,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            final lat = double.tryParse(_latController.text.trim());
            final lon = double.tryParse(_lonController.text.trim());
            final source = _sourceController.text.trim();

            if (lat == null || lon == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Invalid coordinates format')),
              );
              return;
            }

            widget.onSave(
              latitude: lat,
              longitude: lon,
              evidenceSource: source.isNotEmpty ? source : 'Manual GPS Coordinate Entry',
            );
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}
