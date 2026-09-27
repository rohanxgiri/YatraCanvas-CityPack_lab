import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../domain/lab_place.dart';
import '../data/local_place_repository.dart';

class PlaceCard extends StatelessWidget {
  final LabPlace place;
  final LocalPlaceRepository repository;
  final VoidCallback onTap;
  final bool isInTrip;
  final VoidCallback? onToggleTrip;
  final VoidCallback? onReport;

  const PlaceCard({
    super.key,
    required this.place,
    required this.repository,
    required this.onTap,
    this.isInTrip = false,
    this.onToggleTrip,
    this.onReport,
  });

  Color _getTierColor(String tier) {
    switch (tier.toLowerCase()) {
      case 'core_destination':
        return Colors.amber.shade700;
      case 'recommended':
        return Colors.blue.shade600;
      case 'discovery':
        return Colors.teal.shade600;
      case 'support':
      default:
        return Colors.grey.shade600;
    }
  }

  String _formatTier(String tier) {
    switch (tier.toLowerCase()) {
      case 'core_destination':
        return 'CORE';
      case 'recommended':
        return 'RECOMMENDED';
      case 'discovery':
        return 'DISCOVERY';
      case 'support':
        return 'SUPPORT';
      default:
        return tier.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final File? localImgFile = kIsWeb ? null : repository.resolveImage(place.primaryImagePath);

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image or No Local Image Placeholder
            SizedBox(
              height: 160,
              width: double.infinity,
              child: localImgFile != null
                  ? Image.file(
                      localImgFile,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, stack) => _buildPlaceholder(),
                    )
                  : (kIsWeb && place.primaryImagePath != null && place.primaryImagePath!.isNotEmpty
                      ? Image.asset(
                          repository.resolveAssetPath(place.primaryImagePath) ?? '',
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, err, stack) => _buildPlaceholder(),
                        )
                      : _buildPlaceholder()),
            ),

            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tier and Category chips
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _getTierColor(place.tier).withAlpha(30),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _getTierColor(place.tier),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          _formatTier(place.tier),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _getTierColor(place.tier),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          place.category.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                      if (place.subcategory != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          '• ${place.subcategory}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (place.travelRelevanceScore > 0)
                        Text(
                          'Score: ${(place.travelRelevanceScore * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.blueGrey.shade700,
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Place Name
                  Text(
                    place.name,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  if (place.nameHi != null && place.nameHi!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      place.nameHi!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],

                  if (place.address != null && place.address!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            place.address!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 8),

                  // Actions row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (onReport != null)
                        TextButton.icon(
                          onPressed: onReport,
                          icon: const Icon(Icons.flag_outlined, size: 16),
                          label: const Text('Report', style: TextStyle(fontSize: 12)),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red.shade700,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      if (onToggleTrip != null)
                        OutlinedButton.icon(
                          onPressed: onToggleTrip,
                          icon: Icon(
                            isInTrip ? Icons.check : Icons.add_location_alt_outlined,
                            size: 16,
                          ),
                          label: Text(
                            isInTrip ? 'In Trip' : 'Add to Trip',
                            style: const TextStyle(fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: isInTrip ? Colors.teal.shade50 : null,
                            foregroundColor:
                                isInTrip ? Colors.teal.shade800 : Colors.indigo,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.blueGrey.shade50,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_not_supported_outlined,
              size: 38, color: Colors.blueGrey.shade300),
          const SizedBox(height: 6),
          Text(
            'No local image',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.blueGrey.shade600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'City Pack does not contain local media',
            style: TextStyle(
              fontSize: 10,
              color: Colors.blueGrey.shade400,
            ),
          ),
        ],
      ),
    );
  }
}
