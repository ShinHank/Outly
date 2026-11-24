import 'dart:convert';
import 'dart:math' show min;
import 'dart:typed_data';

import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  int selectedDay = 0;
  final nearbyKey = GlobalKey();
  final expensesKey = GlobalKey();

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

  void scrollTo(GlobalKey key) {
    final target = key.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      alignment: 0.05,
    );
  }

  @override
  Widget build(BuildContext context) {
    final invited = widget.people
        .where((person) => gala.participantIds.contains(person.id))
        .toList();
    final total = gala.expenses.fold<double>(0, (sum, e) => sum + e.amount);
    final topInset = MediaQuery.of(context).padding.top;
    return Scaffold(
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
        ),
        child: Stack(
          children: [
            // A plain scroll view keeps the plan image built so it can be shared.
            SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 140),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  header(invited),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            statusPill(gala.status),
                            for (final tag in gala.tags) pill(tag),
                          ],
                        ),
                        ...stopsBlock(),
                        KeyedSubtree(
                          key: nearbyKey,
                          child: section('Nearby local spots', [
                            NearbySection(
                              api: widget.api,
                              latitude: gala.places.isEmpty
                                  ? 0
                                  : gala.places.first.latitude,
                              longitude: gala.places.isEmpty
                                  ? 0
                                  : gala.places.first.longitude,
                              onAdd: addNearby,
                              isAdded: isAdded,
                            ),
                          ], icon: Icons.storefront_outlined),
                        ),
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
                        KeyedSubtree(
                          key: expensesKey,
                          child: section(
                            'Expenses',
                            expenseWidgets(invited),
                            icon: Icons.payments_outlined,
                          ),
                        ),
                        section('Plan image', [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: RepaintBoundary(
                              key: planKey,
                              child: PlanCard(
                                name: gala.name,
                                date: gala.date,
                                endDate: gala.endDate,
                                guests: [
                                  for (final person in invited)
                                    if (person.name.trim().isNotEmpty)
                                      person.name.trim(),
                                ],
                                locations: gala.places,
                                tags: gala.tags,
                                plan: gala.plan,
                                weatherText:
                                    liveWeather?.summary ?? gala.weather,
                                weatherCode:
                                    liveWeather?.code ?? gala.weatherCode,
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
                ],
              ),
            ),
            // Keeps the status bar readable once the blue header scrolls away.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: topInset,
              child: const ColoredBox(color: brand),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 0,
              child: SafeArea(
                top: false,
                minimum: const EdgeInsets.only(bottom: 16),
                child: spendBar(invited, total),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget headerButton(IconData icon, String tooltip, VoidCallback onTap) =>
      Padding(
        padding: const EdgeInsets.only(left: 8),
        child: IconButton(
          tooltip: tooltip,
          onPressed: onTap,
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withAlpha(51),
            foregroundColor: Colors.white,
            fixedSize: const Size(44, 44),
          ),
          icon: Icon(icon, size: 20),
        ),
      );

  /// Blue header: back, actions, title, date and weather, who's going.
  Widget header(List<Participant> invited) {
    final weatherText = liveWeather?.summary ?? gala.weather;
    final subtitle = [
      compactDateRange(gala.date, gala.endDate),
      if (weatherText.isNotEmpty) weatherText,
    ].join(' · ');
    final top = MediaQuery.of(context).padding.top;
    final names = [
      for (final person in invited)
        if (person.name.trim().isNotEmpty) person.name.trim(),
    ];
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      child: Container(
        color: brand,
        child: Stack(
          children: [
            Positioned(right: -30, top: -30, child: coralCircle(120)),
            Padding(
              padding: EdgeInsets.fromLTRB(20, top + 12, 20, 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Back',
                        onPressed: () => Navigator.maybePop(context),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withAlpha(51),
                          foregroundColor: Colors.white,
                          fixedSize: const Size(44, 44),
                        ),
                        icon: const Icon(Icons.arrow_back_rounded, size: 22),
                      ),
                      const Spacer(),
                      headerButton(
                        Icons.event_available_outlined,
                        'Add to calendar',
                        addToCalendar,
                      ),
                      headerButton(
                        Icons.group_outlined,
                        'Share with friends',
                        shareWithFriends,
                      ),
                      headerButton(
                        Icons.edit_outlined,
                        'Edit gala',
                        edit,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    gala.name,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      AvatarStack(names: names, ring: brand),
                      if (names.isNotEmpty) const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          invited.isEmpty
                              ? 'No guests yet'
                              : '${invited.length} going',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
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

  /// Floating dark bar: what has been spent and the way into splitting it.
  Widget spendBar(List<Participant> invited, double total) {
    final each = invited.isEmpty || total <= 0 ? null : total / invited.length;
    return Container(
      height: 76,
      padding: const EdgeInsets.fromLTRB(24, 0, 12, 0),
      decoration: BoxDecoration(
        color: context.bar,
        borderRadius: BorderRadius.circular(38),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(50),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total spent',
                  style: TextStyle(color: context.onBarMuted, fontSize: 12),
                ),
                Text.rich(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  TextSpan(
                    children: [
                      TextSpan(
                        text: moneyShort(total),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (each != null)
                        TextSpan(
                          text: ' · ${moneyShort(each)} each',
                          style: TextStyle(
                            color: context.onBarMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: gala.expenses.isEmpty
                ? () => editExpense(invited)
                : () => scrollTo(expensesKey),
            style: FilledButton.styleFrom(
              backgroundColor: coral,
              foregroundColor: inkColor,
              minimumSize: const Size(0, 52),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
            child: Text(gala.expenses.isEmpty ? 'Add expense' : 'Split bill'),
          ),
        ],
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

  /// Day of a stop, never past the last day of the outing.
  int dayOf(GalaLocation stop) =>
      min(stopDay(stop, gala.date), gala.dayCount - 1);

  List<Widget> stopsBlock() {
    final places = gala.places;
    if (places.isEmpty) {
      return const [
        SizedBox(height: 14),
        MessageCard('No location set yet. Tap the pencil to add one.'),
      ];
    }
    final points = places
        .map((place) => LatLng(place.latitude, place.longitude))
        .toList();
    final day = min(selectedDay, gala.dayCount - 1);
    final visible = [
      for (var i = 0; i < places.length; i++)
        if (!gala.isMultiDay || dayOf(places[i]) == day) i,
    ];
    return [
      if (gala.isMultiDay)
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: gala.dayCount,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, index) => ChoicePill(
                label: dayTabLabel(index, gala.date),
                selected: index == day,
                onTap: () => setState(() => selectedDay = index),
              ),
            ),
          ),
        ),
      const SizedBox(height: 14),
      if (visible.isEmpty)
        const MessageCard('Nothing planned for this day yet.')
      else
        for (final i in visible)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: stopTile(places[i], points[i]),
          ),
      addSpotCallout(),
      section('Map', [locationMap(points)], icon: Icons.map_outlined),
    ];
  }

  /// One stop: time, optional local badge, name and the rest of the address.
  Widget stopTile(GalaLocation stop, LatLng point) {
    final parts = stop.name
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    final first = shortName(stop.name);
    final address = first == stop.name || parts.length < 2
        ? ''
        : parts.skip(1).join(', ');
    return Card(
      child: InkWell(
        // Tapping a stop opens its website (or a web search).
        onTap: () => openPlacePage(
          context,
          api: widget.api,
          name: stop.name,
          latitude: stop.latitude,
          longitude: stop.longitude,
          website: stop.website,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 6, 14),
          child: Row(
            children: [
              SizedBox(
                width: 62,
                child: stop.time.isEmpty
                    ? Text('–', style: TextStyle(color: context.muted))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            clockLabel(stop.time),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            meridiem(stop.time),
                            style: TextStyle(
                              color: context.muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (stop.local)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: localBadge(),
                      ),
                    Text(
                      first,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    if (address.isNotEmpty)
                      Text(
                        address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: context.muted, fontSize: 13),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'More actions',
                icon: Icon(Icons.more_vert, color: context.muted),
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  builder: (context) => SafeArea(
                    child: Wrap(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.edit_outlined),
                          title: const Text('Edit stop'),
                          onTap: () async {
                            Navigator.pop(context);
                            final updated = await Navigator.push<Gala>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => GalaEditor(
                                  gala: gala,
                                  people: widget.people,
                                  api: widget.api,
                                ),
                              ),
                            );
                            if (updated != null) apply(updated);
                          },
                        ),
                        ListTile(
                          leading: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                          title: const Text(
                            'Delete stop',
                            style: TextStyle(color: Colors.red),
                          ),
                          onTap: () async {
                            Navigator.pop(context);
                            final remaining = gala.places
                                .where((item) => item != stop)
                                .toList();
                            await apply(gala.copyWith(locations: remaining));
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ----- Widgets matching the v2 design -----

  Widget addSpotCallout() => Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 6),
    child: Material(
      color: context.soft,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => scrollTo(nearbyKey),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Text(
                '+ Add a local spot nearby',
                style: TextStyle(
                  color: context.onSoft,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Icon(Icons.arrow_forward_rounded, size: 18, color: context.onSoft),
            ],
          ),
        ),
      ),
    ),
  );

  Widget locationMap(List<LatLng> points) => ClipRRect(
    borderRadius: BorderRadius.circular(24),
    child: SizedBox(
      height: 200,
      child: FlutterMap(
        mapController: mapController,
        options: MapOptions(
          initialCenter: points.first,
          initialZoom: 13,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.none,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.outly.app',
          ),
          MarkerLayer(
            markers: [
              for (var i = 0; i < points.length; i++)
                Marker(
                  point: points[i],
                  width: 32,
                  height: 32,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: coral,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
  );

  List<Widget> participantWidgets(List<Participant> invited) => [
    if (invited.isEmpty)
      const MessageCard('No guests invited yet. Tap Edit to add people.')
    else
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final person in invited)
                Chip(
                  avatar: CircleAvatar(
                    backgroundColor: context.soft,
                    child: Text(initialOf(person.name)),
                  ),
                  label: Text(person.name),
                ),
            ],
          ),
        ),
      ),
  ];
}
