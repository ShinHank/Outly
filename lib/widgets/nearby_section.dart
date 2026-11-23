import 'package:flutter/material.dart';

import '../core/geo.dart';
import '../core/links.dart';
import '../models/nearby_place.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// SDG 8 (Decent work and economic growth): suggests pasalubong shops,
/// restaurants, cafes and more around the first stop, and by default hides
/// chains so spending goes to independent local businesses.
class NearbySection extends StatefulWidget {
  const NearbySection({
    super.key,
    required this.api,
    required this.latitude,
    required this.longitude,
    required this.onAdd,
    required this.isAdded,
  });

  final ApiService api;

  /// The first stop. Zero means no location has been chosen yet.
  final double latitude;
  final double longitude;
  final ValueChanged<NearbyPlace> onAdd;
  final bool Function(NearbyPlace) isAdded;

  @override
  State<NearbySection> createState() => _NearbySectionState();
}

class _NearbySectionState extends State<NearbySection> {
  static const _maxShown = 12;

  PlaceCategory category = PlaceCategory.pasalubong;
  bool localOnly = true;
  bool loading = false;
  String? error;
  final cache = <PlaceCategory, List<NearbyPlace>>{};
  int request = 0;

  bool get hasOrigin => widget.latitude != 0 && widget.longitude != 0;

  @override
  void initState() {
    super.initState();
    if (hasOrigin) {
      loading = true;
      fetch(category);
    }
  }

  @override
  void didUpdateWidget(NearbySection old) {
    super.didUpdateWidget(old);
    final moved =
        old.latitude != widget.latitude || old.longitude != widget.longitude;
    if (!moved) return;
    cache.clear();
    if (hasOrigin) {
      setState(() {
        loading = true;
        error = null;
      });
      fetch(category);
    } else {
      setState(() {
        loading = false;
        error = null;
      });
    }
  }

  Future<void> fetch(PlaceCategory target) async {
    final token = ++request;
    try {
      final places = await widget.api.nearbyPlaces(
        widget.latitude,
        widget.longitude,
        target,
      );
      if (!mounted || token != request) return;
      setState(() {
        cache[target] = places;
        loading = false;
        error = null;
      });
    } catch (e) {
      if (!mounted || token != request) return;
      setState(() {
        loading = false;
        error = 'Could not load nearby places.\n$e';
      });
    }
  }

  void select(PlaceCategory next) {
    if (next == category) return;
    final needsLoad = !cache.containsKey(next);
    setState(() {
      category = next;
      error = null;
      loading = needsLoad;
    });
    if (needsLoad) fetch(next);
  }

  void retry() {
    setState(() {
      loading = true;
      error = null;
    });
    fetch(category);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HintText(
          'SDG 8 · Decent work and economic growth. Spending at independent local shops and eateries keeps income in the community.',
        ),
        const SizedBox(height: 4),
        HintText('Tap a place to open its website. Tap + to add it as a stop.'),
        const SizedBox(height: 12),
        if (!hasOrigin)
          const MessageCard(
            'Add a location first and we will suggest places nearby.',
          )
        else ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final option in PlaceCategory.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      avatar: Icon(
                        option.icon,
                        size: 18,
                        color: category == option
                            ? context.brandColor
                            : context.muted,
                      ),
                      label: Text(option.label),
                      selected: category == option,
                      showCheckmark: false,
                      onSelected: (_) => select(option),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: localOnly,
            onChanged: (value) => setState(() => localOnly = value),
            title: const Text(
              'Local independents only',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: const Text('Hides places tagged as chains on the map'),
          ),
          results(),
        ],
      ],
    );
  }

  Widget results() {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.cloud_off_outlined, color: context.muted),
              const SizedBox(width: 12),
              Expanded(child: Text(error!, style: const TextStyle(fontSize: 13))),
              TextButton(onPressed: retry, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    final all = cache[category] ?? const <NearbyPlace>[];
    final shown = all
        .where((place) => !localOnly || !place.isChain)
        .take(_maxShown)
        .toList();
    if (shown.isEmpty) {
      return MessageCard(
        all.isEmpty
            ? 'No ${category.label.toLowerCase()} found within 1.5 km. OpenStreetMap coverage varies, so try another category.'
            : 'Only chains found nearby. Turn off "Local independents only" to see them.',
      );
    }
    return Card(
      child: Column(
        children: [
          for (var i = 0; i < shown.length; i++) ...[
            if (i > 0) const Divider(),
            tile(shown[i]),
          ],
        ],
      ),
    );
  }

  Widget tile(NearbyPlace place) {
    final added = widget.isAdded(place);
    final subtitle = [
      distanceLabel(place.distanceKm),
      if (place.detail.isNotEmpty) place.detail,
    ].join(' · ');
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: context.soft,
        child: Icon(category.icon, size: 20, color: context.brandColor),
      ),
      title: Text(
        place.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      // Tap a place to read about it before deciding to add it.
      onTap: () => openPlacePage(
        context,
        api: widget.api,
        name: place.name,
        latitude: place.latitude,
        longitude: place.longitude,
        website: place.website,
      ),
      trailing: added
          ? Icon(Icons.check_circle, color: context.brandColor)
          : IconButton(
              tooltip: 'Add as a stop',
              icon: Icon(Icons.add_circle_outline, color: context.brandColor),
              onPressed: () => widget.onAdd(place),
            ),
    );
  }
}
