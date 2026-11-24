import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/constants.dart';
import '../models/location.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

/// Full-screen map for dropping and naming a pin.
class PinPickerPage extends StatefulWidget {
  const PinPickerPage({super.key, required this.existing, required this.api});
  final List<GalaLocation> existing;
  final ApiService api;
  @override
  State<PinPickerPage> createState() => _PinPickerPageState();
}

class _PinPickerPageState extends State<PinPickerPage> {
  final nameController = TextEditingController();
  LatLng? pin;
  bool looking = false;
  int lookupId = 0;
  String autoName = '';

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  Future<void> placePin(LatLng point) async {
    final id = ++lookupId;
    // Clear the name only if the user hasn't typed their own.
    if (nameController.text.trim().isEmpty ||
        nameController.text == autoName) {
      nameController.clear();
      autoName = '';
    }
    setState(() {
      pin = point;
      looking = true;
    });
    try {
      final suggested = await widget.api.reverseGeocode(
        point.latitude,
        point.longitude,
      );
      if (!mounted || id != lookupId) return;
      if (suggested != null && nameController.text.trim().isEmpty) {
        autoName = suggested;
        nameController.text = suggested;
      }
    } catch (_) {
      // The name is optional help; the user can type their own.
    }
    if (mounted && id == lookupId) setState(() => looking = false);
  }

  void confirm() {
    final point = pin;
    if (point == null) return;
    final typed = nameController.text.trim();
    Navigator.pop(
      context,
      GalaLocation(
        name: typed.isEmpty ? 'Pinned location' : typed,
        latitude: point.latitude,
        longitude: point.longitude,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final points = widget.existing
        .map((place) => LatLng(place.latitude, place.longitude))
        .toList();
    final temp = pin;
    return Scaffold(
      appBar: AppBar(title: const Text('Pin a location')),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: points.isNotEmpty
                        ? points.first
                        : defaultMapCenter,
                    initialZoom: points.isNotEmpty ? 15 : 11,
                    initialCameraFit: points.length > 1
                        ? CameraFit.coordinates(
                            coordinates: points,
                            padding: const EdgeInsets.all(72),
                            maxZoom: 16,
                          )
                        : null,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                    onTap: (_, point) => placePin(point),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.outly',
                    ),
                    if (points.isNotEmpty)
                      MarkerLayer(
                        markers: points
                            .map(
                              (point) => Marker(
                                point: point,
                                width: 36,
                                height: 36,
                                alignment: Alignment.topCenter,
                                child: const Icon(
                                  Icons.location_pin,
                                  color: brandDark,
                                  size: 36,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    if (temp != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: temp,
                            width: 52,
                            height: 52,
                            alignment: Alignment.topCenter,
                            child: const Icon(
                              Icons.location_pin,
                              color: brand,
                              size: 52,
                            ),
                          ),
                        ],
                      ),
                    const RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution('OpenStreetMap contributors'),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  top: 12,
                  left: 16,
                  right: 16,
                  child: IgnorePointer(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.touch_app_outlined,
                                size: 18, color: context.brandColor),
                            const SizedBox(width: 8),
                            Text(
                              temp == null
                                  ? 'Tap the map to drop a pin'
                                  : 'Tap elsewhere to move the pin',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Material(
            elevation: 8,
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      enabled: temp != null,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => confirm(),
                      decoration: InputDecoration(
                        labelText: 'Pin name',
                        hintText: temp == null
                            ? 'Drop a pin first'
                            : 'e.g. Rooftop bar',
                        prefixIcon: const Icon(Icons.label_outline),
                        suffixIcon: looking
                            ? const Padding(
                                padding: EdgeInsets.all(14),
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: temp == null ? null : confirm,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                        ),
                        icon: const Icon(Icons.check),
                        label: const Text('Add this pin'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
