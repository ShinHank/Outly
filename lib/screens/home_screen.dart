import 'package:flutter/material.dart';

import '../core/format.dart';
import '../models/gala.dart';
import '../models/participant.dart';
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

class _WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()
      ..color = Colors.white.withAlpha(20)
      ..style = PaintingStyle.fill;
    final paint2 = Paint()
      ..color = Colors.white.withAlpha(10)
      ..style = PaintingStyle.fill;

    final path1 = Path()
      ..moveTo(0, size.height * 0.65)
      ..quadraticBezierTo(size.width * 0.3, size.height * 0.8, size.width * 0.7, size.height * 0.6)
      ..quadraticBezierTo(size.width * 0.9, size.height * 0.5, size.width, size.height * 0.7)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final path2 = Path()
      ..moveTo(0, size.height * 0.75)
      ..quadraticBezierTo(size.width * 0.4, size.height * 0.55, size.width * 0.8, size.height * 0.8)
      ..quadraticBezierTo(size.width * 0.95, size.height * 0.85, size.width, size.height * 0.75)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path1, paint1);
    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

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
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kumusta!',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Where to next?',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  const ThemeMenuButton(),
                ],
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: tab,
                children: [
                  dashboard(),
                  ParticipantsPage(people: people, store: store, onChanged: load),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        margin: EdgeInsets.fromLTRB(
          24,
          0,
          24,
          MediaQuery.of(context).padding.bottom + 16,
        ),
        height: 72,
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(36),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(40),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            TextButton.icon(
              onPressed: () => setState(() => tab = 0),
              icon: Icon(
                Icons.event_note_rounded,
                color: tab == 0 ? Colors.white : Colors.white60,
              ),
              label: Text(
                'Plans',
                style: TextStyle(
                  color: tab == 0 ? Colors.white : Colors.white60,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
            GestureDetector(
              onTap: edit,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: accentOrange,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: accentOrange.withAlpha(100),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 28),
              ),
            ),
            TextButton.icon(
              onPressed: () => setState(() => tab = 1),
              icon: Icon(
                Icons.people_alt_outlined,
                color: tab == 1 ? Colors.white : Colors.white60,
              ),
              label: Text(
                'People',
                style: TextStyle(
                  color: tab == 1 ? Colors.white : Colors.white60,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
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
    final localBusinessCount = galas.fold<int>(
      0,
      (total, g) => total + g.localStops,
    );

    return RefreshIndicator(
      onRefresh: load,
      color: brand,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 120),
        children: [
          hero(upcoming.isEmpty ? null : upcoming.first),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2FE).withAlpha(150),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFBAE6FD)),
            ),
            child: Row(
              children: [
                const Icon(Icons.favorite_outline, color: Color(0xFF0284C7), size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '$localBusinessCount of ${galas.fold<int>(0, (t, g) => t + g.places.length)} stops are local, independent businesses',
                    style: const TextStyle(
                      color: Color(0xFF0369A1),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                filterPill(_Filter.all, 'All plans'),
                const SizedBox(width: 8),
                filterPill(_Filter.upcoming, 'Upcoming'),
                const SizedBox(width: 8),
                filterPill(_Filter.past, 'Past'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (shown.isEmpty)
            emptyState(galas.isEmpty)
          else
            for (final gala in shown) galaCard(gala),
        ],
      ),
    );
  }

  Widget filterPill(_Filter f, String label) {
    final selected = filter == f;
    return GestureDetector(
      onTap: () => setState(() => filter = f),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? const Color(0xFF0F172A) : Colors.grey.shade300,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withAlpha(30),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.grey.shade700,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget hero(Gala? next) {
    final days = next == null ? 0 : daysUntil(next.date);
    final routeStr = next == null || next.places.isEmpty
        ? 'No stops added yet'
        : next.places.map((p) => shortName(p.name)).join(' → ');

    return Container(
      height: 310,
      decoration: BoxDecoration(
        color: brand,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: brand.withAlpha(80),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _WavePainter()),
            ),
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  color: accentOrange,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (next != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        days == 0 ? 'Today!' : '$days days to go',
                        style: const TextStyle(
                          color: brand,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    next == null ? 'Plan something\nmemorable.' : next.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      height: 1.05,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    next == null
                        ? 'Your next great outing starts with one tap.'
                        : '${shortDateRange(next.date, next.endDate)} · ${next.places.length} stops',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    routeStr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (next != null && next.participantIds.isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (var index = 0; index < mathMin(3, next.participantIds.length); index++)
                                  Align(
                                    widthFactor: 0.65,
                                    child: Container(
                                      width: 30,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        color: index % 2 == 0 ? Colors.amber : Colors.teal,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: brand, width: 2),
                                      ),
                                      child: Center(
                                        child: Text(
                                          people.firstWhere(
                                            (p) => p.id == next.participantIds[index],
                                            orElse: () => Participant(id: '', name: 'G', email: ''),
                                          ).name.isNotEmpty
                                              ? people.firstWhere((p) => p.id == next.participantIds[index], orElse: () => Participant(id: '', name: 'G', email: '')).name[0].toUpperCase()
                                              : 'G',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${next.participantIds.length} going',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        )
                      else
                        const SizedBox.shrink(),
                      ElevatedButton(
                        onPressed: next == null ? edit : () => openDetail(next),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black87,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: Text(
                          next == null ? 'Create' : 'Open plan',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
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

  int mathMin(int a, int b) => a < b ? a : b;

  static const _monthNames = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
  String monthName(DateTime d) => _monthNames[d.month - 1];

  Widget emptyState(bool noGalasAtAll) => Container(
    padding: const EdgeInsets.all(32),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Colors.grey.shade200),
    ),
    child: Column(
      children: [
        const Icon(Icons.celebration_outlined, size: 48, color: brand),
        const SizedBox(height: 16),
        Text(
          noGalasAtAll ? 'Your next gala starts here' : 'Nothing here yet',
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        const SizedBox(height: 8),
        Text(
          noGalasAtAll
              ? 'Add a date, location, and plan to get started.'
              : 'Try another filter.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade600, height: 1.4),
        ),
      ],
    ),
  );

  Widget galaCard(Gala gala) {
    final places = gala.places;
    final monthStr = monthName(gala.date);
    final dayStr = gala.date.day.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => openDetail(gala),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEDD5),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        monthStr.length > 3 ? monthStr.substring(0, 3) : monthStr,
                        style: const TextStyle(
                          color: Color(0xFFC2410C),
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dayStr,
                        style: const TextStyle(
                          color: Color(0xFF9A3412),
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        gala.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        places.isEmpty
                            ? 'Location not set'
                            : '${shortName(places.first.name)} · ${gala.participantIds.length} invited',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.more_vert, color: Colors.grey.shade400),
                  onPressed: () => edit(gala),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
