import 'dart:convert';
import 'dart:typed_data';

import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:gal/gal.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';

import '../core/calendar.dart';
import '../core/capture.dart';
import '../core/constants.dart';
import '../core/format.dart';
import '../core/links.dart';
import '../core/schedule.dart';
import '../models/expense.dart';
import '../models/gala.dart';
import '../models/location.dart';
import '../models/nearby_place.dart';
import '../models/participant.dart';
import '../models/weather_info.dart';
import '../services/api_service.dart';
import '../services/local_store.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/expense_dialog.dart';
import '../widgets/nearby_section.dart';
import '../widgets/plan_card.dart';
import 'gala_editor.dart';

class GalaDetailPage extends StatefulWidget {
  const GalaDetailPage({
    super.key,
    required this.gala,
    required this.people,
    required this.api,
    required this.onSave,
  });
  final Gala gala;
  final List<Participant> people;
  final ApiService api;
  final Future<bool> Function(Gala) onSave;
  @override
  State<GalaDetailPage> createState() => _GalaDetailPageState();
}

class _GalaDetailPageState extends State<GalaDetailPage> {
  late Gala gala;
  final planKey = GlobalKey();
  final mapController = MapController();
  WeatherInfo? liveWeather;

  @override
  void initState() {
    super.initState();
    gala = widget.gala;
    refreshWeather();
  }

  void message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  /// Re-checks the forecast so the page never shows stale weather.
  Future<void> refreshWeather() async {
    final places = gala.places;
    if (places.isEmpty) return;
    try {
      final result = await widget.api.fetchWeather(
        places.first.latitude,
        places.first.longitude,
        gala.date,
      );
      if (!mounted || result == null) return;
      setState(() => liveWeather = result);
      if (result.summary != gala.weather || result.code != gala.weatherCode) {
        final updated = gala.copyWith(
          weather: result.summary,
          weatherCode: result.code,
        );
        setState(() => gala = updated);
        await widget.onSave(updated);
      }
    } catch (_) {
      // Keep showing the saved weather if the lookup fails.
    }
  }

  Future<void> edit() async {
    final result = await Navigator.push<Gala>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            GalaEditor(gala: gala, people: widget.people, api: widget.api),
      ),
    );
    final updatedPeople = await LocalStore().participants();
    widget.people.clear();
    widget.people.addAll(updatedPeople);
    if (result == null) return;
    if (await widget.onSave(result) && mounted) {
      setState(() {
        gala = result;
        liveWeather = null;
      });
      refreshWeather();
    }
  }

  List<String> guestNames() => [
        for (final person in widget.people)
          if (gala.participantIds.contains(person.id)) person.name,
      ];

  /// Opens the phone's own "new event" screen, pre-filled, so the person only
  /// taps Save. Nothing is written to a file or shared.
  Future<void> addToCalendar() async {
    try {
      final entry = galaToCalendarEntry(gala, guests: guestNames());
      final opened = await Add2Calendar.addEvent2Cal(
        Event(
          title: entry.title,
          description: entry.description,
          location: entry.location,
          startDate: entry.start,
          // The plugin treats an all-day end as the last day shown.
          endDate: entry.end,
          allDay: entry.allDay,
          iosParams: const IOSParams(reminder: Duration(days: 1)),
        ),
      );
      if (!opened) message('Unable to open your calendar.');
    } on Exception catch (e) {
      debugPrint('[Outly] add to calendar failed: $e');
      message('Unable to open your calendar.');
    }
  }

  /// Share sheet for friends: a short invite message plus an .ics file, so
  /// anyone who receives it can add the gala to their own calendar.
  Future<void> shareWithFriends() async {
    try {
      final guests = guestNames();
      final ics = galaToIcs(gala, guests: guests);
      final when = gala.isMultiDay
          ? '${longDateRange(gala.date, gala.endDate)} · ${gala.dayCount} days'
          : longDate(gala.date);
      final stops = [
        for (final stop in gala.places)
          if (stop.name.trim().isNotEmpty) stop.name.trim(),
      ];
      await SharePlus.instance.share(
        ShareParams(
          subject: gala.name,
          text: [
            "You're invited: ${gala.name}",
            when,
            if (stops.isNotEmpty) stops.join(' → '),
            'Open the attached file to add it to your calendar.',
          ].join('\n'),
          files: [
            XFile.fromData(
              Uint8List.fromList(utf8.encode(ics)),
              mimeType: 'text/calendar',
              name: '${planFileName(gala.name).replaceAll(RegExp(r'\.\w+$'), '')}.ics',
            ),
          ],
        ),
      );
    } on Exception catch (e) {
      debugPrint('[Outly] share with friends failed: $e');
      message('Unable to share with friends.');
    }
  }

  Future<void> shareImage() async {
    try {
      final bytes = await capturePng(planKey, width: 1080);
      if (bytes == null) {
        message('Unable to create the plan image.');
        return;
      }
      await SharePlus.instance.share(
        ShareParams(
          text: 'Outly plan: ${gala.name}',
          files: [
            XFile.fromData(
              bytes,
              mimeType: 'image/png',
              name: planFileName(gala.name),
            ),
          ],
        ),
      );
    } on Exception {
      message('Unable to export the plan image.');
    }
  }

  Future<void> downloadImage() async {
    try {
      final bytes = await capturePng(planKey, width: 1080);
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

  @override
  Widget build(BuildContext context) {
    final invited = widget.people
        .where((person) => gala.participantIds.contains(person.id))
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(gala.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Add to calendar',
            onPressed: addToCalendar,
            icon: const Icon(Icons.event_available_outlined),
          ),
          IconButton(
            tooltip: 'Share with friends',
            onPressed: shareWithFriends,
            icon: const Icon(Icons.group_outlined),
          ),
          IconButton(
            tooltip: 'Edit gala',
            onPressed: edit,
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      // A plain scroll view keeps the plan image built so it can be shared.
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            headerCard(),
            section('Locations', locationWidgets(), icon: Icons.place_outlined),
            section('Nearby local spots', [
              NearbySection(
                api: widget.api,
                latitude: gala.places.isEmpty ? 0 : gala.places.first.latitude,
                longitude: gala.places.isEmpty ? 0 : gala.places.first.longitude,
                onAdd: addNearby,
                isAdded: isAdded,
              ),
            ], icon: Icons.storefront_outlined),
            if (gala.plan.trim().isNotEmpty)
              section('Plan', [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      gala.plan.trim(),
                      style: const TextStyle(height: 1.45),
                    ),
                  ),
                ),
              ], icon: Icons.notes_outlined),
            section(
              'Participants',
              participantWidgets(invited),
              icon: Icons.people_outline,
            ),
            section(
              'Expenses',
              expenseWidgets(invited),
              icon: Icons.payments_outlined,
            ),
            section('Plan image', [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: RepaintBoundary(
                  key: planKey,
                  child: PlanCard(
                    name: gala.name,
                    date: gala.date,
                    endDate: gala.endDate,
                    guests: [
                      for (final person in invited)
                        if (person.name.trim().isNotEmpty) person.name.trim(),
                    ],
                    locations: gala.places,
                    tags: gala.tags,
                    plan: gala.plan,
                    weatherText: liveWeather?.summary ?? gala.weather,
                    weatherCode: liveWeather?.code ?? gala.weatherCode,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: shareImage,
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('Share image'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: downloadImage,
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('Download'),
                    ),
                  ),
                ],
              ),
            ], icon: Icons.image_outlined),
          ],
        ),
      ),
    );
  }

  Future<void> apply(Gala updated) async {
    setState(() => gala = updated);
    await widget.onSave(updated);
  }

  String nameOf(String id) {
    // Older galas may still reference the host.
    if (id == hostId) return 'Host';
    for (final person in widget.people) {
      if (person.id == id) return person.name.isEmpty ? 'Unnamed' : person.name;
    }
    return 'Someone';
  }

  // ----- Nearby local spots (SDG 8) -----

  bool isAdded(NearbyPlace place) => gala.places.any(
    (item) =>
        item.name == place.name &&
        (item.latitude - place.latitude).abs() < 0.0001 &&
        (item.longitude - place.longitude).abs() < 0.0001,
  );

  Future<void> addNearby(NearbyPlace place) async {
    if (isAdded(place)) return;
    await apply(
      gala.copyWith(
        locations: [
          ...gala.places,
          GalaLocation(
            name: place.name,
            latitude: place.latitude,
            longitude: place.longitude,
            local: !place.isChain,
            // Same day as the last stop, so trips stay grouped sensibly.
            date: gala.places.isEmpty ? '' : gala.places.last.date,
            website: place.website,
          ),
        ],
      ),
    );
    message('Added ${place.name} to your stops.');
  }

  // ----- Expenses -----

  Future<void> editExpense(
    List<Participant> invited, [
    Expense? existing,
  ]) async {
    if (invited.isEmpty) {
      message('Invite guests first. Expenses are split between guests.');
      return;
    }
    final result = await showDialog<Expense>(
      context: context,
      builder: (_) => ExpenseDialog(people: invited, existing: existing),
    );
    if (result == null || !mounted) return;
    final list = [...gala.expenses];
    final index = list.indexWhere((item) => item.id == result.id);
    if (index == -1) {
      list.add(result);
    } else {
      list[index] = result;
    }
    await apply(gala.copyWith(expenses: list));
  }

  Future<void> deleteExpense(Expense expense) => apply(
    gala.copyWith(
      expenses: gala.expenses.where((item) => item.id != expense.id).toList(),
    ),
  );

  String expenseSummary() {
    final total = gala.expenses.fold<double>(0, (sum, e) => sum + e.amount);
    final buffer = StringBuffer()
      ..writeln('💸 ${gala.name} expenses')
      ..writeln();
    for (final e in gala.expenses) {
      buffer.writeln(
        '• ${e.title}: ${money(e.amount)} (paid by ${nameOf(e.paidBy)})',
      );
    }
    buffer
      ..writeln()
      ..writeln('Total: ${money(total)}');
    final transfers = settle(balances(gala.expenses));
    buffer
      ..writeln()
      ..writeln(transfers.isEmpty ? 'Everyone is settled up.' : 'Who owes who:');
    for (final t in transfers) {
      buffer.writeln('• ${nameOf(t.from)} owes ${nameOf(t.to)} ${money(t.amount)}');
    }
    return buffer.toString().trimRight();
  }

  Future<void> shareExpenses() async {
    try {
      await SharePlus.instance.share(ShareParams(text: expenseSummary()));
    } on Exception {
      message('Unable to share the summary.');
    }
  }

  List<Widget> expenseWidgets(List<Participant> invited) {
    final expenses = gala.expenses;
    final total = expenses.fold<double>(0, (sum, e) => sum + e.amount);
    final transfers = settle(balances(expenses));
    return [
      if (expenses.isEmpty)
        const MessageCard(
          'No expenses yet. Add what was paid and who it is split between.',
        )
      else
        Card(
          child: Column(
            children: [
              for (final e in expenses)
                ListTile(
                  dense: true,
                  title: Text(
                    e.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    'Paid by ${nameOf(e.paidBy)} · split ${e.splitWith.length} way${e.splitWith.length == 1 ? '' : 's'}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        money(e.amount),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      IconButton(
                        tooltip: 'Delete expense',
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => deleteExpense(e),
                      ),
                    ],
                  ),
                  onTap: () => editExpense(invited, e),
                ),
            ],
          ),
        ),
      if (expenses.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text(
          'Total ${money(total)}',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
      ],
      if (expenses.isNotEmpty) ...[
        const SizedBox(height: 16),
        const Text(
          'Who owes who',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        const SizedBox(height: 8),
        if (transfers.isEmpty)
          const MessageCard('Everyone is settled up.')
        else
          Card(
            child: Column(
              children: [
                for (var i = 0; i < transfers.length; i++) ...[
                  if (i > 0) const Divider(),
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: context.soft,
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: 20,
                        color: context.brandColor,
                      ),
                    ),
                    title: Text(
                      '${nameOf(transfers[i].from)} owes ${nameOf(transfers[i].to)}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    trailing: Text(
                      money(transfers[i].amount),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: FilledButton.tonalIcon(
              onPressed: () => editExpense(invited),
              style: FilledButton.styleFrom(
                backgroundColor: context.soft,
                foregroundColor: context.brandColor,
              ),
              icon: const Icon(Icons.add),
              label: const Text('Add expense'),
            ),
          ),
          if (expenses.isNotEmpty) ...[
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: shareExpenses,
                icon: const Icon(Icons.share_outlined),
                label: const Text('Share'),
              ),
            ),
          ],
        ],
      ),
    ];
  }

  Widget headerCard() {
    final weatherText = liveWeather?.summary ?? gala.weather;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                statusPill(gala.status),
                const SizedBox(width: 8),
                pill(
                  whenLabel(gala.date, gala.endDate),
                  color: context.muted,
                  icon: Icons.schedule,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              gala.name,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 26,
                height: 1.1,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            infoRow(
              Icons.calendar_month_outlined,
              gala.isMultiDay
                  ? '${longDateRange(gala.date, gala.endDate)} · ${gala.dayCount} days'
                  : longDate(gala.date),
            ),
            if (weatherText.isNotEmpty)
              infoRow(
                liveWeather?.icon ?? weatherIconFor(gala.weatherCode),
                weatherText,
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: addToCalendar,
                    icon: const Icon(Icons.edit_calendar_outlined),
                    label: const Text('Add to calendar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: shareWithFriends,
                    icon: const Icon(Icons.group_outlined),
                    label: const Text('Share with friends'),
                  ),
                ),
              ],
            ),
            if (gala.tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: gala.tags.map((tag) => pill(tag)).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> locationWidgets() {
    final places = gala.places;
    if (places.isEmpty) {
      return const [MessageCard('No location set yet. Tap the pencil to add one.')];
    }
    final points = places
        .map((place) => LatLng(place.latitude, place.longitude))
        .toList();
    return [
      ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: 220,
          child: FlutterMap(
            key: ValueKey(places.length),
            mapController: mapController,
            options: MapOptions(
              initialCenter: points.first,
              initialZoom: 15,
              initialCameraFit: points.length > 1
                  ? CameraFit.coordinates(
                      coordinates: points,
                      padding: const EdgeInsets.all(48),
                      maxZoom: 16,
                    )
                  : null,
              // Static map so it doesn't fight with page scrolling.
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.none,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.outly',
              ),
              MarkerLayer(
                markers: [
                  for (var i = 0; i < points.length; i++)
                    Marker(
                      point: points[i],
                      width: 34,
                      height: 34,
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: context.brandColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: const [
                            BoxShadow(blurRadius: 4, color: Colors.black26),
                          ],
                        ),
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            color: context.onBrand,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
        ),
      ),
      const SizedBox(height: 10),
      Card(
        child: Column(
          children: [
            for (var i = 0; i < places.length; i++) ...[
              if (gala.isMultiDay &&
                  (i == 0 ||
                      stopDay(places[i], gala.date) !=
                          stopDay(places[i - 1], gala.date)))
                Container(
                  width: double.infinity,
                  color: context.soft,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(
                    dayLabel(stopDay(places[i], gala.date), gala.date),
                    style: TextStyle(
                      color: context.brandColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: context.brandColor,
                  foregroundColor: context.onBrand,
                  child: Text('${i + 1}'),
                ),
                title: Text(
                  places[i].time.isEmpty
                      ? shortName(places[i].name)
                      : '${timeLabel(places[i].time)} · ${shortName(places[i].name)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: shortName(places[i].name) == places[i].name
                    ? null
                    : Text(
                        places[i].name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (places[i].local)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Tooltip(
                          message: 'Local business',
                          child: Icon(
                            Icons.storefront_outlined,
                            size: 18,
                            color: context.brandColor,
                          ),
                        ),
                      ),
                    IconButton(
                      tooltip: 'Show on map',
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.my_location,
                        size: 18,
                        color: context.brandColor,
                      ),
                      onPressed: () => mapController.move(points[i], 16),
                    ),
                  ],
                ),
                // Tapping a stop opens its website (or a web search).
                onTap: () => openPlacePage(
                  context,
                  api: widget.api,
                  name: places[i].name,
                  latitude: places[i].latitude,
                  longitude: places[i].longitude,
                  website: places[i].website,
                ),
              ),
            ],
          ],
        ),
      ),
    ];
  }

  List<Widget> participantWidgets(List<Participant> invited) {
    if (invited.isEmpty) {
      return const [
        MessageCard(
          'No participants yet. Tap the pencil to add or select participants.',
        ),
      ];
    }
    return [
      Card(
        child: Column(
          children: invited.map((person) {
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: context.soft,
                child: Text(
                  person.name.isEmpty ? '?' : person.name[0].toUpperCase(),
                  style: TextStyle(
                    color: context.brandColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(person.name.isEmpty ? 'Unnamed' : person.name),
              subtitle: person.email.isEmpty ? null : Text(person.email),
            );
          }).toList(),
        ),
      ),
    ];
  }
}
