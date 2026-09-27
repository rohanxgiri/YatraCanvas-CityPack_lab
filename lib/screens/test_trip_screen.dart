import 'package:flutter/material.dart';
import '../app/app_state.dart';
import '../domain/lab_place.dart';
import 'place_detail_screen.dart';
import 'map_screen.dart';

class TestTripScreen extends StatefulWidget {
  final AppState state;

  const TestTripScreen({super.key, required this.state});

  @override
  State<TestTripScreen> createState() => _TestTripScreenState();
}

class _TestTripScreenState extends State<TestTripScreen> {
  List<LabPlace> _selectedPlaces = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSelectedPlaces();
  }

  void _loadSelectedPlaces() async {
    final repo = widget.state.repository;
    final trip = widget.state.tripSelection;
    if (repo == null || trip == null) {
      setState(() => _isLoading = false);
      return;
    }

    final ids = trip.placeDays.keys.toList();
    final places = await repo.getPlacesByIds(ids);

    if (mounted) {
      setState(() {
        _selectedPlaces = places;
        _isLoading = false;
      });
    }
  }

  void _groupGeographically() {
    widget.state.groupTripGeographically(_selectedPlaces);
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Grouped geographically by coordinates into days.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.state.tripSelection;
    final tripDays = trip?.tripDays ?? 3;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Trip Basket'),
        actions: [
          IconButton(
            icon: const Icon(Icons.map),
            tooltip: 'View Trip Map',
            onPressed: _selectedPlaces.isEmpty
                ? null
                : () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => MapScreen(
                          state: widget.state,
                          initialPlaces: _selectedPlaces,
                        ),
                      ),
                    );
                  },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Top settings: Trip days selector
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.grey.shade100,
                  child: Row(
                    children: [
                      const Text(
                        'Trip Duration:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(width: 12),
                      DropdownButton<int>(
                        value: tripDays,
                        items: List.generate(7, (i) => i + 1).map((days) {
                          return DropdownMenuItem(
                            value: days,
                            child: Text('$days Day${days > 1 ? "s" : ""}'),
                          );
                        }).toList(),
                        onChanged: (days) {
                          if (days != null) {
                            widget.state.setTripDays(days);
                            setState(() {});
                          }
                        },
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: _selectedPlaces.isEmpty
                            ? null
                            : _groupGeographically,
                        icon: const Icon(Icons.auto_awesome, size: 16),
                        label: const Text('Cluster by Coords',
                            style: TextStyle(fontSize: 11)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                ),

                // Disclaimer banner (Rule 20)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  color: Colors.blue.shade50,
                  child: const Text(
                    '⚠️ Lab geographic grouping — not YatraCanvas itinerary optimization. Used to test if selected POIs make sense together.',
                    style: TextStyle(fontSize: 10, color: Colors.indigo),
                  ),
                ),

                // Selected places grouped by Day
                Expanded(
                  child: _selectedPlaces.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.luggage_outlined,
                                    size: 56, color: Colors.grey.shade400),
                                const SizedBox(height: 16),
                                const Text(
                                  'Your Test Basket is Empty',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Add places from Discover, Search, or Map to test POI clustering.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 24),
                          itemCount: tripDays,
                          itemBuilder: (context, dayIndex) {
                            final currentDay = dayIndex + 1;
                            final dayPlaces = _selectedPlaces.where((p) {
                              final d = trip?.getDayFor(p.id) ?? 1;
                              return d == currentDay;
                            }).toList();

                            return _buildDaySection(currentDay, dayPlaces, tripDays);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildDaySection(int dayNumber, List<LabPlace> places, int totalDays) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.grey.shade200,
          child: Row(
            children: [
              Text(
                'DAY $dayNumber',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(width: 8),
              Text(
                '(${places.length} places)',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        if (places.isEmpty)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'No places assigned to Day $dayNumber.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          )
        else
          ...places.map((place) => _buildTripPlaceTile(place, dayNumber, totalDays)),
      ],
    );
  }

  Widget _buildTripPlaceTile(LabPlace place, int currentDay, int totalDays) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        title: Text(place.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          '${place.tier.toUpperCase()} • ${place.category} • Coords: ${place.latitude.toStringAsFixed(3)}, ${place.longitude.toStringAsFixed(3)}',
          style: const TextStyle(fontSize: 11),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Day selector
            DropdownButton<int>(
              value: currentDay,
              underline: const SizedBox(),
              items: List.generate(totalDays, (i) => i + 1).map((d) {
                return DropdownMenuItem(
                  value: d,
                  child: Text('Day $d', style: const TextStyle(fontSize: 12)),
                );
              }).toList(),
              onChanged: (newDay) {
                if (newDay != null) {
                  widget.state.assignTripDay(place.id, newDay);
                  setState(() {});
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () {
                widget.state.removePlaceFromTrip(place.id);
                setState(() {
                  _selectedPlaces.removeWhere((p) => p.id == place.id);
                });
              },
            ),
          ],
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PlaceDetailScreen(
                place: place,
                state: widget.state,
              ),
            ),
          );
        },
      ),
    );
  }
}
