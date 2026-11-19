import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';

import '../core/capture.dart';
import '../core/constants.dart';
import '../core/format.dart';
import '../models/gala.dart';
import '../models/location.dart';
import '../models/participant.dart';
import '../models/weather_info.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/nearby_section.dart';
import '../widgets/plan_card.dart';
import 'pin_picker_page.dart';

class GalaEditor extends StatefulWidget {
  const GalaEditor({
    super.key,
    this.gala,
    required this.people,
    required this.api,
  });
  final Gala? gala;
  final List<Participant> people;
  final ApiService api;
  @override
  State<GalaEditor> createState() => _GalaEditorState();
}

class _GalaEditorState extends State<GalaEditor> {
  late final TextEditingController name, location, plan, tagInput;
  late DateTime date;
  String status = 'Planned';
  double lat = 0, lon = 0;
  List<LocationSuggestion> suggestions = [];
  final locations = <GalaLocation>[];
  int activeLocation = 0;
  final tags = <String>[];
  Timer? suggestionTimer;
  final planBoundaryKey = GlobalKey();
  final selected = <String>{};
  bool busy = false;
  bool saving = false;

  // Weather for the chosen date at the active location.
  WeatherInfo? weather;
  String weatherText = '';
  int weatherCode = -1;
  String? weatherNote;
  bool weatherBusy = false;
  int weatherRequest = 0;

  String thumbnail = '';

  @override
  void initState() {
    super.initState();
    final gala = widget.gala;
    name = TextEditingController(text: gala?.name);
    location = TextEditingController(text: gala?.location);
    plan = TextEditingController(text: gala?.plan);
    tagInput = TextEditingController();
    date = gala?.date ?? DateTime.now().add(const Duration(days: 1));
    status = gala?.status ?? 'Planned';
    lat = gala?.latitude ?? 0;
    lon = gala?.longitude ?? 0;
    weatherText = gala?.weather ?? '';
    weatherCode = gala?.weatherCode ?? -1;
    thumbnail = gala?.thumbnail ?? '';
    locations.addAll(gala?.locations ?? const []);
    if (locations.isEmpty && lat != 0 && lon != 0) {
      locations.add(
        GalaLocation(name: gala?.location ?? '', latitude: lat, longitude: lon),
      );
    }
    if (locations.isNotEmpty) {
      lat = locations.first.latitude;
      lon = locations.first.longitude;
      if (location.text.trim().isEmpty) {
        location.text = locations.first.name;
      }
    }
    tags.addAll(gala?.tags ?? const []);
    selected.addAll(gala?.participantIds ?? []);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) loadWeather();
    });
  }

  @override
  void dispose() {
    name.dispose();
    location.dispose();
    plan.dispose();
    tagInput.dispose();
    suggestionTimer?.cancel();
    super.dispose();
  }

  // ----- Date / weather -----

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      initialDate: date,
    );
    if (picked != null) {
      setState(() {
        date = picked;
      });
      loadWeather();
    }
  }

  Future<void> loadWeather() async {
    final request = ++weatherRequest;
    if (lat == 0 || lon == 0) {
      setState(() {
        weather = null;
        weatherText = '';
        weatherCode = -1;
        weatherNote = 'Add a location to see the forecast.';
        weatherBusy = false;
      });
      return;
    }
    setState(() {
      weatherBusy = true;
      weatherNote = null;
    });
    try {
      final result = await widget.api.fetchWeather(lat, lon, date);
      if (!mounted || request != weatherRequest) return;
      setState(() {
        weather = result;
        weatherText = result?.summary ?? '';
        weatherCode = result?.code ?? -1;
        weatherNote = result == null
            ? 'Forecasts reach 16 days ahead. Check back closer to the date.'
            : null;
        weatherBusy = false;
      });
    } catch (_) {
      if (!mounted || request != weatherRequest) return;
      setState(() {
        weatherBusy = false;
        weatherNote = 'Weather unavailable right now. Tap refresh to retry.';
      });
    }
  }

  // ----- Locations -----

  Future<void> geocode() async {
    final query = location.text.trim();
    if (query.isEmpty) return;
    setState(() => busy = true);
    try {
      final results = await widget.api.searchLocations(query);
      if (!mounted) return;
      if (results.isNotEmpty) {
        addLocation(
          results.first.name,
          results.first.latitude,
          results.first.longitude,
        );
      }
      setState(() {
        suggestions = results;
        busy = false;
      });
      if (results.isEmpty) message('Location not found.');
    } catch (e) {
      if (!mounted) return;
      setState(() => busy = false);
      message('Location search failed: $e');
    }
  }

  void addLocation(
    String name,
    double latitude,
    double longitude, {
    bool local = false,
    bool keepAnchor = false,
  }) {
    if (latitude == 0 ||
        longitude == 0 ||
        locations.any(
          (item) =>
              item.name == name &&
              item.latitude == latitude &&
              item.longitude == longitude,
        )) {
      return;
    }
    setState(() {
      locations.add(
        GalaLocation(
          name: name,
          latitude: latitude,
          longitude: longitude,
          local: local,
        ),
      );
      // Nearby suggestions are extra stops: the weather and the nearby
      // search stay anchored to the first stop.
      final anchored = keepAnchor && locations.length > 1;
      if (!anchored) {
        activeLocation = locations.length - 1;
        location.clear();
        lat = latitude;
        lon = longitude;
      }
    });
    if (!(keepAnchor && locations.length > 1)) loadWeather();
  }

  void selectLocation(int index) {
    final selectedLocation = locations[index];
    setState(() {
      activeLocation = index;
      location.text = selectedLocation.name;
      lat = selectedLocation.latitude;
      lon = selectedLocation.longitude;
    });
    loadWeather();
  }

  void removeLocation(int index) {
    setState(() {
      locations.removeAt(index);
      if (locations.isEmpty) {
        activeLocation = 0;
        lat = 0;
        lon = 0;
      } else {
        activeLocation = activeLocation >= locations.length
            ? locations.length - 1
            : activeLocation;
        final selectedLocation = locations[activeLocation];
        location.text = selectedLocation.name;
        lat = selectedLocation.latitude;
        lon = selectedLocation.longitude;
      }
    });
    loadWeather();
  }

  Future<void> renameLocation(int index) async {
    final old = locations[index];
    final controller = TextEditingController(text: old.name);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename location'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == null || result.isEmpty || !mounted) return;
    setState(() {
      locations[index] = old.copyWith(name: result);
      if (location.text == old.name) location.text = result;
    });
  }

  Future<void> pickTime(int index) async {
    final old = locations[index];
    final picked = await showTimePicker(
      context: context,
      initialTime: parseTime(old.time) ?? const TimeOfDay(hour: 18, minute: 0),
    );
    if (picked == null || !mounted) return;
    setState(() => locations[index] = old.copyWith(time: formatTime(picked)));
  }

  Future<void> openPinMap() async {
    final picked = await Navigator.push<GalaLocation>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) =>
            PinPickerPage(existing: List.of(locations), api: widget.api),
      ),
    );
    if (picked != null) {
      addLocation(picked.name, picked.latitude, picked.longitude);
    }
  }

  // ----- Tags -----

  bool hasTag(String tag) =>
      tags.any((item) => item.toLowerCase() == tag.toLowerCase());

  void toggleTag(String tag) {
    setState(() {
      if (hasTag(tag)) {
        tags.removeWhere((item) => item.toLowerCase() == tag.toLowerCase());
      } else if (tags.length < 12) {
        tags.add(tag);
      }
    });
  }

  void addTag() {
    setState(() {
      for (final raw in tagInput.text.split(',')) {
        var tag = raw.trim().replaceAll(RegExp(r'^#+'), '').trim();
        if (tag.isEmpty) continue;
        if (tag.length > 24) tag = tag.substring(0, 24);
        if (tags.length >= 12) break;
        if (hasTag(tag)) continue;
        tags.add(tag);
      }
      tagInput.clear();
    });
  }

  // ----- Plan image -----

  Future<void> exportPlan() async {
    try {
      final bytes = await capturePng(planBoundaryKey, width: 1080);
      if (bytes == null) {
        message('Unable to create the plan image.');
        return;
      }
      await SharePlus.instance.share(
        ShareParams(
          text: 'Outly plan: ${name.text.trim()}',
          files: [
            XFile.fromData(
              bytes,
              mimeType: 'image/png',
              name: planFileName(name.text),
            ),
          ],
        ),
      );
    } on Exception {
      message('Unable to export the plan image.');
    }
  }

  Future<void> downloadPlan() async {
    try {
      final bytes = await capturePng(planBoundaryKey, width: 1080);
      if (bytes == null) {
        message('Unable to create the plan image.');
        return;
      }
      await Gal.putImageBytes(bytes, album: 'Outly');
      message('Image saved to your gallery.');
    } on Exception {
      message('Unable to save the plan image. Check gallery permissions.');
    }
  }

  Future<void> save() async {
    if (name.text.trim().isEmpty) {
      message('Give your gala a name first.');
      return;
    }
    setState(() => saving = true);
    var thumb = thumbnail;
    try {
      final bytes = await capturePng(planBoundaryKey, width: 320);
      if (bytes != null) thumb = base64Encode(bytes);
    } on Exception {
      // Keep the previous thumbnail if capturing fails.
    }
    if (!mounted) return;
    Navigator.pop(
      context,
      Gala(
        id: widget.gala?.id,
        name: name.text.trim(),
        date: date,
        location: location.text.trim(),
        locations: locations,
        latitude: lat,
        longitude: lon,
        status: status,
        plan: plan.text.trim(),
        tags: tags.toList(),
        weather: weatherText,
        weatherCode: weatherCode,
        thumbnail: thumb,
        participantIds: selected.toList(),
        // The editor doesn't touch expenses, so carry them over unchanged.
        expenses: widget.gala?.expenses ?? const [],
      ),
    );
  }

  void message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  // ----- Build -----

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.gala == null ? 'New gala' : 'Edit gala'),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: FilledButton(
            onPressed: saving ? null : save,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: saving
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.onBrand,
                    ),
                  )
                : const Text('Save'),
          ),
        ),
      ],
    ),
    // A plain scroll view (not a lazy ListView) keeps the plan card built
    // at all times, so it can always be captured for the thumbnail.
    body: SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          section('Gala details', [
            TextField(
              controller: name,
              onChanged: (_) => setState(() {}),
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Gala name',
                prefixIcon: Icon(Icons.celebration_outlined),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: pickDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Date',
                        prefixIcon: Icon(Icons.calendar_today_outlined),
                      ),
                      child: Text(dateText(date)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: galaStatuses
                        .map(
                          (item) =>
                              DropdownMenuItem(value: item, child: Text(item)),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => status = value ?? status),
                  ),
                ),
              ],
            ),
          ]),
          section('Type of outing', [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...suggestedTags.map(
                  (tag) => FilterChip(
                    label: Text(tag),
                    selected: hasTag(tag),
                    onSelected: (_) => toggleTag(tag),
                  ),
                ),
                ...tags
                    .where(
                      (tag) => !suggestedTags.any(
                        (item) => item.toLowerCase() == tag.toLowerCase(),
                      ),
                    )
                    .map(
                      (tag) => InputChip(
                        label: Text(tag),
                        selected: true,
                        showCheckmark: false,
                        onDeleted: () => setState(() => tags.remove(tag)),
                      ),
                    ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: tagInput,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => addTag(),
                    decoration: const InputDecoration(
                      labelText: 'Add your own',
                      hintText: 'e.g. Bar crawl, Picnic',
                      prefixIcon: Icon(Icons.sell_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: addTag,
                  icon: const Icon(Icons.add),
                  tooltip: 'Add tag',
                ),
              ],
            ),
            const SizedBox(height: 8),
            const HintText(
              'Tags show on the plan image and in the invite. Separate several with commas.',
            ),
          ]),
          section('Weather', [weatherCard()]),
          section('Locations', [
            TextField(
              controller: location,
              decoration: InputDecoration(
                labelText: 'Meeting location',
                prefixIcon: const Icon(Icons.location_on_outlined),
                suffixIcon: IconButton(
                  onPressed: busy ? null : geocode,
                  icon: const Icon(Icons.search),
                ),
              ),
              onChanged: (value) {
                suggestionTimer?.cancel();
                if (value.trim().length < 3) {
                  setState(() => suggestions = []);
                  return;
                }
                suggestionTimer = Timer(
                  const Duration(milliseconds: 800),
                  () async {
                    try {
                      final results = await widget.api.searchLocations(
                        value.trim(),
                      );
                      if (mounted && location.text.trim() == value.trim()) {
                        setState(() => suggestions = results);
                      }
                    } on Exception {
                      if (mounted) {
                        setState(() => suggestions = []);
                      }
                    }
                  },
                );
              },
            ),
            if (suggestions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Card(
                  child: Column(
                    children: suggestions
                        .map(
                          (suggestion) => ListTile(
                            dense: true,
                            leading: Icon(
                              Icons.location_on_outlined,
                              color: context.brandColor,
                            ),
                            title: Text(
                              suggestion.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () {
                              addLocation(
                                suggestion.name,
                                suggestion.latitude,
                                suggestion.longitude,
                              );
                              setState(() => suggestions = []);
                            },
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            const SizedBox(height: 10),
            if (locations.isNotEmpty)
              Card(
                color: context.soft,
                child: Column(
                  children: locations.asMap().entries.map((entry) {
                    final index = entry.key;
                    final place = entry.value;
                    return ListTile(
                      dense: true,
                      selected: activeLocation == index,
                      selectedTileColor: context.brandColor.withAlpha(24),
                      leading: CircleAvatar(
                        backgroundColor: context.brandColor,
                        foregroundColor: context.onBrand,
                        child: Text('${index + 1}'),
                      ),
                      title: Text(
                        place.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${place.time.isEmpty ? 'No time set' : timeLabel(place.time)} · ${activeLocation == index ? 'Selected' : 'Tap to select'}',
                      ),
                      onTap: () => selectLocation(index),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Set time',
                            icon: const Icon(Icons.access_time),
                            onPressed: () => pickTime(index),
                          ),
                          IconButton(
                            tooltip: 'Rename location',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => renameLocation(index),
                          ),
                          IconButton(
                            tooltip: 'Remove location',
                            icon: const Icon(Icons.close),
                            onPressed: () => removeLocation(index),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: openPinMap,
              icon: const Icon(Icons.pin_drop_outlined),
              label: const Text('Pin a location on the map'),
            ),
            if (lat != 0 && lon != 0)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: HintText('Location found with OpenStreetMap'),
              ),
            if (busy) const LinearProgressIndicator(),
          ]),
          section('Nearby local spots', [
            NearbySection(
              api: widget.api,
              latitude: locations.isEmpty ? 0 : locations.first.latitude,
              longitude: locations.isEmpty ? 0 : locations.first.longitude,
              onAdd: (place) => addLocation(
                place.name,
                place.latitude,
                place.longitude,
                local: !place.isChain,
                keepAnchor: true,
              ),
              isAdded: (place) => locations.any(
                (item) =>
                    item.name == place.name &&
                    (item.latitude - place.latitude).abs() < 0.0001 &&
                    (item.longitude - place.longitude).abs() < 0.0001,
              ),
            ),
          ], icon: Icons.storefront_outlined),
          section('Plan', [
            TextField(
              controller: plan,
              minLines: 3,
              maxLines: 5,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'What is the plan?',
                alignLabelWithHint: true,
              ),
            ),
          ]),
          section('Plan image', [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: RepaintBoundary(
                key: planBoundaryKey,
                child: PlanCard(
                  name: name.text,
                  date: date,
                  locations: locations,
                  tags: tags,
                  plan: plan.text,
                  weatherText: weatherText,
                  weatherCode: weatherCode,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: exportPlan,
                    icon: const Icon(Icons.share_outlined),
                    label: const Text('Share image'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: downloadPlan,
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Download'),
                  ),
                ),
              ],
            ),
          ]),
          section('Guest list', [
            if (widget.people.isEmpty)
              const HintText('Add participants from the Participants tab.'),
            ...widget.people.map(
              (person) => CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: selected.contains(person.id),
                title: Text(person.name.isEmpty ? 'Unnamed' : person.name),
                subtitle: Text(person.email),
                onChanged: (value) => setState(
                  () => value == true
                      ? selected.add(person.id)
                      : selected.remove(person.id),
                ),
              ),
            ),
          ]),
        ],
      ),
    ),
  );

  Widget weatherCard() {
    final forecast = weather;
    final place = activeLocation < locations.length
        ? locations[activeLocation].name
        : '';
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 6, 12),
        child: Row(
          children: [
            Icon(
              forecast?.icon ?? Icons.cloud_outlined,
              color: context.brandColor,
              size: 32,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: weatherBusy
                  ? const Text('Checking the forecast…')
                  : forecast != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          forecast.label,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          forecast.rainChance == null
                              ? forecast.range
                              : '${forecast.range} · ${forecast.rainChance}% rain',
                        ),
                        if (place.isNotEmpty)
                          Text(
                            'For ${shortName(place)} on ${dateText(date)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: context.muted, fontSize: 12),
                          ),
                      ],
                    )
                  : Text(
                      weatherNote ??
                          (weatherText.isEmpty
                              ? 'No forecast yet.'
                              : weatherText),
                      style: TextStyle(color: context.muted),
                    ),
            ),
            IconButton(
              tooltip: 'Refresh weather',
              onPressed: weatherBusy ? null : loadWeather,
              icon: Icon(Icons.refresh, color: context.brandColor),
            ),
          ],
        ),
      ),
    );
  }
}
