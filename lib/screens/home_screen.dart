import 'package:flutter/material.dart';

import '../core/format.dart';
import '../models/gala.dart';
import '../models/participant.dart';
import '../models/weather_info.dart';
import '../services/api_service.dart';
import '../services/local_store.dart';
import '../services/reminders.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/theme_menu.dart';
import 'gala_detail_page.dart';
import 'gala_editor.dart';
import 'participants_page.dart';

enum _Filter { all, upcoming, past }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final store = LocalStore();
  final api = ApiService();
  List<Gala> galas = [];
  List<Participant> people = [];
  int tab = 0;
  bool loading = true;
  _Filter filter = _Filter.all;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    galas = await store.galas();
    people = await store.participants();
    if (mounted) setState(() => loading = false);
  }

  /// Returns false if the gala couldn't be saved (e.g. date clash).
  Future<bool> saveGala(Gala gala) async {
    if (galas.any(
      (item) => item.id != gala.id && item.overlaps(gala),
    )) {
      message(
        'Another gala is already scheduled on ${dateRangeText(gala.date, gala.endDate)}.',
      );
      return false;
    }
    final index = galas.indexWhere((item) => item.id == gala.id);
    if (index == -1) {
      galas = [...galas, gala];
    } else {
      galas = [...galas]..[index] = gala;
    }
    await store.saveGalas(galas);
    await Reminders.schedule(gala);
    if (mounted) setState(() {});
    return true;
  }

  Future<void> edit([Gala? gala]) async {
    final result = await Navigator.push<Gala>(
      context,
      MaterialPageRoute(
        builder: (_) => GalaEditor(gala: gala, people: people, api: api),
      ),
    );
    people = await store.participants();
    if (result != null) await saveGala(result);
    if (mounted) setState(() {});
  }

  Future<void> openDetail(Gala gala) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => GalaDetailPage(
          gala: gala,
          people: people,
          api: api,
          onSave: saveGala,
        ),
      ),
    );
    people = await store.participants();
    if (mounted) setState(() {});
  }

  Future<void> deleteGala(Gala gala) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete gala?'),
        content: Text('"${gala.name}" and its expenses will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    galas.removeWhere((item) => item.id == gala.id);
    await store.saveGalas(galas);
    await Reminders.cancel(gala.id);
    if (mounted) setState(() {});
  }

  void message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  bool _isUpcoming(Gala gala) =>
      daysUntil(gala.lastDay) >= 0 &&
      gala.status != 'Cancelled' &&
      gala.status != 'Completed';

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [brandDark, brand]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.explore_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text('Outly'),
          ],
        ),
        actions: [
          const ThemeMenuButton(),
        ],
      ),
      body: IndexedStack(
        index: tab,
        children: [
          dashboard(),
          ParticipantsPage(people: people, store: store, onChanged: load),
        ],
      ),
      floatingActionButton: tab == 0
          ? FloatingActionButton.extended(
              onPressed: edit,
              backgroundColor: context.brandColor,
              foregroundColor: context.onBrand,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              icon: const Icon(Icons.add),
              label: const Text(
                'New gala',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (index) => setState(() => tab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.event_outlined),
            selectedIcon: Icon(Icons.event),
            label: 'Galas',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Participants',
          ),
        ],
      ),
    );
  }

  Widget dashboard() {
    final items = [...galas]..sort((a, b) => a.date.compareTo(b.date));
    final upcoming = items.where(_isUpcoming).toList();
    final shown = switch (filter) {
      _Filter.all => items,
      _Filter.upcoming => upcoming,
      _Filter.past => items.where((g) => !_isUpcoming(g)).toList().reversed.toList(),
    };
    final totalGuests = galas.fold<int>(
      0,
      (total, gala) => total + gala.participantIds.length,
    );
    return RefreshIndicator(
      onRefresh: load,
      color: context.brandColor,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
        children: [
          hero(upcoming.isEmpty ? null : upcoming.first),
          const SizedBox(height: 14),
          Row(
            children: [
              stat(Icons.event_available_rounded, '${galas.length}', 'Galas'),
              const SizedBox(width: 10),
              stat(Icons.people_alt_outlined, '$totalGuests', 'Guests'),
            ],
          ),
          const SizedBox(height: 26),
          const Text(
            'Your galas',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<_Filter>(
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: context.soft,
              selectedForegroundColor: context.brandColor,
              foregroundColor: context.muted,
              side: BorderSide(color: context.border),
            ),
            segments: const [
              ButtonSegment(value: _Filter.all, label: Text('All')),
              ButtonSegment(value: _Filter.upcoming, label: Text('Upcoming')),
              ButtonSegment(value: _Filter.past, label: Text('Past')),
            ],
            selected: {filter},
            onSelectionChanged: (value) =>
                setState(() => filter = value.first),
          ),
          const SizedBox(height: 14),
          if (shown.isEmpty)
            emptyState(galas.isEmpty)
          else
            for (final gala in shown) galaCard(gala),
        ],
      ),
    );
  }

  Widget hero(Gala? next) {
    final place = next == null || next.places.isEmpty
        ? null
        : shortName(next.places.first.name);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [brandDark, brand],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: brandDark.withAlpha(70),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          pill(
            next == null ? 'MAKE TIME FOR FUN' : whenLabel(next.date, next.endDate),
            color: Colors.white,
            background: Colors.white.withAlpha(38),
            icon: next == null ? null : Icons.schedule,
          ),
          const SizedBox(height: 14),
          Text(
            next == null ? 'Plan something\nmemorable.' : next.name,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              height: 1.05,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            next == null
                ? 'Your next great outing starts with one tap.'
                : [
                    shortDateRange(next.date, next.endDate),
                    if (place != null) place,
                  ].join(' · '),
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: next == null ? edit : () => openDetail(next),
            icon: Icon(
              next == null ? Icons.add_rounded : Icons.arrow_forward_rounded,
              size: 19,
            ),
            label: Text(next == null ? 'Create a gala' : 'View plan'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: brandDark,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget stat(IconData icon, String value, String label) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: context.soft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: context.brandColor, size: 20),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
          ),
          Text(label, style: TextStyle(color: context.muted, fontSize: 12)),
        ],
      ),
    ),
  );

  Widget emptyState(bool noGalasAtAll) => Card(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.soft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.celebration_outlined,
              size: 36,
              color: context.brandColor,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            noGalasAtAll ? 'Your next gala starts here' : 'Nothing here yet',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 6),
          Text(
            noGalasAtAll
                ? 'Add a date, location, plan and people. We will suggest local shops and eateries nearby.'
                : 'Try another filter.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.muted, height: 1.4),
          ),
        ],
      ),
    ),
  );

  Widget thumbnail(Gala gala) {
    final bytes = gala.thumbnailBytes;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 78,
        height: 104,
        child: bytes == null
            ? Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [brandDark, brand],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(
                  Icons.celebration_outlined,
                  color: Colors.white70,
                  size: 28,
                ),
              )
            : Image.memory(
                bytes,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                gaplessPlayback: true,
              ),
      ),
    );
  }

  Widget galaCard(Gala gala) {
    final places = gala.places;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: InkWell(
          onTap: () => openDetail(gala),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                thumbnail(gala),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          statusPill(gala.status),
                          const Spacer(),
                          SizedBox(
                            width: 32,
                            height: 28,
                            child: PopupMenuButton<String>(
                              padding: EdgeInsets.zero,
                              icon: Icon(Icons.more_horiz, color: context.muted),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              onSelected: (value) async {
                                if (value == 'edit') {
                                  await edit(gala);
                                } else if (value == 'delete') {
                                  await deleteGala(gala);
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'edit', child: Text('Edit')),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete gala'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        gala.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          height: 1.15,
                        ),
                      ),
                      infoRow(
                        Icons.calendar_month_outlined,
                        '${dateRangeText(gala.date, gala.endDate)} · ${whenLabel(gala.date, gala.endDate)}',
                      ),
                      infoRow(
                        Icons.location_on_outlined,
                        places.isEmpty
                            ? 'Location not set'
                            : places
                                  .map((item) => shortName(item.name))
                                  .join(' · '),
                      ),
                      if (gala.weather.isNotEmpty)
                        infoRow(
                          weatherIconFor(gala.weatherCode),
                          gala.weather,
                        ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          pill(
                            '${gala.participantIds.length} guest${gala.participantIds.length == 1 ? '' : 's'}',
                            color: context.muted,
                            icon: Icons.people_outline,
                          ),
                          if (gala.tags.isNotEmpty) pill(gala.tags.first),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
