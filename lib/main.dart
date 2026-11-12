import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Firebase dikonfigurasi untuk aplikasi Android/iOS.
  // Saat menjalankan UI di Chrome, inisialisasi dilewati karena
  // konfigurasi Firebase Web belum disiapkan.
  if (!kIsWeb) {
    await Firebase.initializeApp();
  }

  runApp(const SmartAttendanceApp());
}

// ───────────────────────── Design tokens ─────────────────────────

const Color ink = Color(0xFF0B1220);
const Color navy = Color(0xFF14213D);
const Color blue = Color(0xFF3563E9);
const Color sky = Color(0xFF5B8CFF);
const Color background = Color(0xFFF3F5FB);
const Color muted = Color(0xFF7B8497);
const Color line = Color(0xFFE8ECF5);
const Color mint = Color(0xFF16A673);
const Color amber = Color(0xFFF59E0B);
const Color rose = Color(0xFFE05252);

const LinearGradient brandGradient = LinearGradient(
  colors: [Color(0xFF16245A), Color(0xFF2B4FD8), Color(0xFF5B8CFF)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

List<BoxShadow> softShadow([double opacity = 0.06]) => [
  BoxShadow(
    color: navy.withOpacity(opacity),
    blurRadius: 28,
    offset: const Offset(0, 10),
  ),
];

BoxDecoration cardDecoration({double radius = 24}) => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(radius),
  boxShadow: softShadow(),
);

enum AttStatus { hadir, terlambat, izin, alpa, contoh }

extension AttStatusX on AttStatus {
  String get label => switch (this) {
    AttStatus.hadir => 'Hadir',
    AttStatus.terlambat => 'Terlambat',
    AttStatus.izin => 'Izin',
    AttStatus.alpa => 'Alpa',
    AttStatus.contoh => 'Contoh',
  };

  Color get color => switch (this) {
    AttStatus.hadir => mint,
    AttStatus.terlambat => amber,
    AttStatus.izin => blue,
    AttStatus.alpa => rose,
    AttStatus.contoh => blue,
  };

  Color get bg => color.withOpacity(0.12);

  IconData get icon => switch (this) {
    AttStatus.hadir => Icons.check_rounded,
    AttStatus.terlambat => Icons.schedule_rounded,
    AttStatus.izin => Icons.event_note_rounded,
    AttStatus.alpa => Icons.close_rounded,
    AttStatus.contoh => Icons.login_rounded,
  };
}

class AttRecord {
  final String day;
  final String month;
  final String title;
  final String time;
  final AttStatus status;

  const AttRecord(this.day, this.month, this.title, this.time, this.status);
}

const List<AttRecord> sampleRecords = [
  AttRecord('19', 'Okt', 'Absensi masuk', '07:00', AttStatus.contoh),
  AttRecord('18', 'Okt', 'Absensi masuk', '06:55', AttStatus.hadir),
  AttRecord('17', 'Okt', 'Absensi masuk', '07:05', AttStatus.terlambat),
  AttRecord('16', 'Okt', 'Absensi masuk', '06:48', AttStatus.hadir),
  AttRecord('15', 'Okt', 'Izin sakit', 'Surat dokter', AttStatus.izin),
  AttRecord('14', 'Okt', 'Absensi masuk', '06:52', AttStatus.hadir),
  AttRecord('13', 'Okt', 'Absensi masuk', '07:12', AttStatus.terlambat),
  AttRecord('12', 'Okt', 'Absensi masuk', '06:50', AttStatus.hadir),
];

const _days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
const _months = [
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

String greeting() {
  final h = DateTime.now().hour;
  if (h < 11) return 'Selamat pagi';
  if (h < 15) return 'Selamat siang';
  if (h < 18) return 'Selamat sore';
  return 'Selamat malam';
}

String two(int n) => n.toString().padLeft(2, '0');

// ───────────────────────── App shell ─────────────────────────

class SmartAttendanceApp extends StatelessWidget {
  const SmartAttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Attendance',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: background,
        colorScheme: ColorScheme.fromSeed(seedColor: blue),
        fontFamily: 'Roboto',
        splashFactory: InkSparkle.splashFactory,
      ),
      home: const MainNavigation(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int selectedIndex = 0;

  final List<Widget> pages = const [
    DashboardPage(),
    HistoryPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: selectedIndex, children: pages),
      bottomNavigationBar: FloatingNav(
        index: selectedIndex,
        onTap: (i) {
          HapticFeedback.selectionClick();
          setState(() => selectedIndex = i);
        },
      ),
    );
  }
}

class FloatingNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;

  const FloatingNav({super.key, required this.index, required this.onTap});

  static const items = [
    (Icons.grid_view_outlined, Icons.grid_view_rounded, 'Beranda'),
    (Icons.calendar_month_outlined, Icons.calendar_month_rounded, 'Riwayat'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Center(
        heightFactor: 1,
        child: Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 14),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: ink,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: ink.withOpacity(0.28),
                blurRadius: 30,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(items.length, (i) {
              final selected = i == index;
              final item = items[i];
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: EdgeInsets.symmetric(
                    horizontal: selected ? 20 : 18,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    gradient: selected ? brandGradient : null,
                    borderRadius: BorderRadius.circular(21),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        selected ? item.$2 : item.$1,
                        color: selected
                            ? Colors.white
                            : const Color(0xFF8B95AD),
                        size: 22,
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutCubic,
                        child: selected
                            ? Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Text(
                                  item.$3,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Shared widgets ─────────────────────────

class PageShell extends StatelessWidget {
  final List<Widget> children;

  const PageShell({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 130),
            children: children,
          ),
        ),
      ),
    );
  }
}

/// Satu animasi masuk berurutan saat halaman pertama dibuka.
class Reveal extends StatefulWidget {
  final int order;
  final Widget child;

  const Reveal({super.key, required this.order, required this.child});

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _c,
    curve: Curves.easeOut,
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.05),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 90 * widget.order), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

class SectionHeading extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;

  const SectionHeading({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  color: navy,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: muted),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class StatusChip extends StatelessWidget {
  final AttStatus status;

  const StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: status.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: status.color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class ActivityTile extends StatelessWidget {
  final AttRecord record;

  const ActivityTile({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final s = record.status;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(radius: 20),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 54,
            decoration: BoxDecoration(
              color: s.bg,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  record.day,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: s.color,
                    height: 1.1,
                  ),
                ),
                Text(
                  record.month,
                  style: TextStyle(
                    fontSize: 11,
                    color: s.color.withOpacity(0.8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.title,
                  style: const TextStyle(
                    color: navy,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(Icons.schedule_rounded, size: 13, color: muted),
                    const SizedBox(width: 4),
                    Text(
                      record.time,
                      style: const TextStyle(fontSize: 12, color: muted),
                    ),
                  ],
                ),
              ],
            ),
          ),
          StatusChip(status: s),
        ],
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final bool showChevron;

  const InfoRow({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF0FF),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: blue, size: 21),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: navy,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(value, style: const TextStyle(color: muted, fontSize: 12)),
            ],
          ),
        ),
        if (showChevron) const Icon(Icons.chevron_right_rounded, color: muted),
      ],
    );
  }
}

// ───────────────────────── Dashboard ─────────────────────────

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PageShell(
      children: [
        Reveal(order: 0, child: _Header()),
        const SizedBox(height: 26),
        const Reveal(order: 1, child: HeroAttendanceCard()),
        const SizedBox(height: 26),
        const Reveal(order: 2, child: WeekStrip()),
        const SizedBox(height: 26),
        const Reveal(order: 3, child: StatsOverview()),
        const SizedBox(height: 26),
        Reveal(
          order: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeading(
                title: 'Aktivitas terakhir',
                subtitle: 'Contoh riwayat kehadiran',
              ),
              const SizedBox(height: 14),
              ActivityTile(record: sampleRecords[0]),
              const SizedBox(height: 12),
              ActivityTile(record: sampleRecords[1]),
              const SizedBox(height: 16),
              const Text(
                '* Data pada tampilan ini masih berupa contoh.',
                style: TextStyle(fontSize: 11, color: muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: brandGradient,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: blue.withOpacity(0.3),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.face_retouching_natural_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting(),
                style: const TextStyle(fontSize: 13, color: muted),
              ),
              const SizedBox(height: 2),
              const Text(
                'Nama Siswa',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: navy,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
        Material(
          color: Colors.white,
          shape: const CircleBorder(),
          elevation: 0,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: ink,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  content: const Text('Belum ada notifikasi baru.'),
                ),
              );
            },
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: softShadow(),
              ),
              child: const Icon(Icons.notifications_none_rounded, color: navy),
            ),
          ),
        ),
      ],
    );
  }
}

class HeroAttendanceCard extends StatefulWidget {
  const HeroAttendanceCard({super.key});

  @override
  State<HeroAttendanceCard> createState() => _HeroAttendanceCardState();
}

class _HeroAttendanceCardState extends State<HeroAttendanceCard> {
  late Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final date =
        '${_days[_now.weekday - 1]}, ${_now.day} ${_months[_now.month - 1]}';

    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: Container(
        decoration: BoxDecoration(
          gradient: brandGradient,
          boxShadow: [
            BoxShadow(
              color: blue.withOpacity(0.35),
              blurRadius: 40,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -60,
              top: -60,
              child: _Orb(size: 200, opacity: 0.09),
            ),
            Positioned(
              right: 40,
              bottom: -90,
              child: _Orb(size: 170, opacity: 0.06),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.18),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.circle,
                              color: Color(0xFFFFD27A),
                              size: 8,
                            ),
                            SizedBox(width: 7),
                            Text(
                              'Belum absen',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        date,
                        style: const TextStyle(
                          color: Color(0xFFD8E2FF),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  Text(
                    '${two(_now.hour)}:${two(_now.minute)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 64,
                      height: 1,
                      fontWeight: FontWeight.w300,
                      letterSpacing: -2,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Detik ke-${two(_now.second)}. Mulai harimu tepat waktu.',
                    style: const TextStyle(
                      color: Color(0xFFD8E2FF),
                      fontSize: 13,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Row(
                    children: [
                      _HeroPill(icon: Icons.login_rounded, text: 'Masuk 07:00'),
                      SizedBox(width: 10),
                      _HeroPill(
                        icon: Icons.location_on_outlined,
                        text: 'Area sekolah',
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        Navigator.of(context).push(
                          PageRouteBuilder(
                            transitionDuration: const Duration(
                              milliseconds: 450,
                            ),
                            pageBuilder: (_, __, ___) => const AttendancePage(),
                            transitionsBuilder: (_, anim, __, child) {
                              final curved = CurvedAnimation(
                                parent: anim,
                                curve: Curves.easeOutCubic,
                              );
                              return FadeTransition(
                                opacity: curved,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0, 0.06),
                                    end: Offset.zero,
                                  ).animate(curved),
                                  child: child,
                                ),
                              );
                            },
                          ),
                        );
                      },
                      icon: const Icon(Icons.face_retouching_natural_rounded),
                      label: const Text(
                        'Mulai absensi',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        foregroundColor: navy,
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  final double size;
  final double opacity;

  const _Orb({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(opacity),
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _HeroPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.14),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFFD8E2FF)),
          const SizedBox(width: 7),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class WeekStrip extends StatelessWidget {
  const WeekStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now().weekday; // 1..7
    const short = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    final monday = DateTime.now().subtract(Duration(days: today - 1));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: cardDecoration(radius: 26),
      child: Row(
        children: List.generate(7, (i) {
          final date = monday.add(Duration(days: i));
          final isToday = i == today - 1;
          final isPast = i < today - 1;
          final weekend = i >= 5;

          Color dot = const Color(0xFFD5DAE6);
          if (isPast && !weekend) dot = i == 2 ? amber : mint;

          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                gradient: isToday ? brandGradient : null,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  Text(
                    short[i],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isToday ? const Color(0xFFD8E2FF) : muted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: isToday ? Colors.white : navy,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isToday ? Colors.white : dot,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class StatsOverview extends StatelessWidget {
  const StatsOverview({super.key});

  static const hadir = 18.0, terlambat = 2.0, izin = 1.0, alpa = 0.0;

  @override
  Widget build(BuildContext context) {
    const total = hadir + terlambat + izin + alpa;
    final percent = (hadir / total * 100).round();

    final legend = const [
      ('Hadir', '18', mint),
      ('Terlambat', '2', amber),
      ('Izin', '1', blue),
      ('Alpa', '0', rose),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeading(
          title: 'Statistik kehadiran',
          subtitle: 'Ringkasan bulan ini',
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: cardDecoration(radius: 28),
          child: Row(
            children: [
              SizedBox(
                width: 132,
                height: 132,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 1300),
                  curve: Curves.easeOutCubic,
                  builder: (context, t, _) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: const Size.square(132),
                          painter: RingPainter(
                            values: const [hadir, terlambat, izin, alpa],
                            colors: const [mint, amber, blue, rose],
                            progress: t,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${(percent * t).round()}%',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: navy,
                                letterSpacing: -1,
                              ),
                            ),
                            const Text(
                              'Kehadiran',
                              style: TextStyle(fontSize: 11, color: muted),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(width: 22),
              Expanded(
                child: Column(
                  children: [
                    for (final l in legend)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: l.$3,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                l.$1,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: muted,
                                ),
                              ),
                            ),
                            Text(
                              l.$2,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: navy,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class RingPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  final double progress;

  RingPainter({
    required this.values,
    required this.colors,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 15.0;
    final rect =
        Offset(stroke / 2, stroke / 2) &
        Size(size.width - stroke, size.height - stroke);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = const Color(0xFFEEF1F8);
    canvas.drawArc(rect, 0, math.pi * 2, false, track);

    final total = values.fold<double>(0, (a, b) => a + b);
    if (total == 0) return;

    var start = -math.pi / 2;
    const gap = 0.16;
    for (var i = 0; i < values.length; i++) {
      if (values[i] <= 0) continue;
      final full = values[i] / total * math.pi * 2 * progress;
      final sweep = full - gap;
      if (sweep > 0) {
        final p = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..color = colors[i];
        canvas.drawArc(rect, start + gap / 2, sweep, false, p);
      }
      start += full;
    }
  }

  @override
  bool shouldRepaint(covariant RingPainter old) => old.progress != progress;
}

// ───────────────────────── Attendance (face scan) ─────────────────────────

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();

  // 0 menunggu, 1 diperiksa, 2 selesai
  final List<int> _steps = [0, 0, 0];
  bool _running = false;

  bool get _ready => _steps.every((s) => s == 2);

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _simulate() async {
    if (_running) return;
    setState(() => _running = true);
    for (var i = 0; i < _steps.length; i++) {
      setState(() => _steps[i] = 1);
      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      setState(() => _steps[i] = 2);
      HapticFeedback.selectionClick();
    }
    HapticFeedback.mediumImpact();
    setState(() => _running = false);
  }

  Future<void> _confirm() async {
    if (!_ready || _running) return;

    // Firebase Web belum dikonfigurasi. Jangan mengaku berhasil menyimpan
    // jika aplikasi dijalankan di Chrome tanpa FirebaseOptions untuk Web.
    if (Firebase.apps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: ink,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: const Text(
            'Firebase belum aktif di platform ini. Jalankan di Android '
            'atau siapkan konfigurasi Firebase Web terlebih dahulu.',
          ),
        ),
      );
      return;
    }

    setState(() => _running = true);

    try {
      final now = DateTime.now();
      await FirebaseFirestore.instance.collection('attendance').add({
        'studentName': 'Nama Siswa',
        'status': now.hour > 7 || (now.hour == 7 && now.minute > 0)
            ? 'terlambat'
            : 'hadir',
        'timestamp': FieldValue.serverTimestamp(),
        'localDate': '${now.year}-${two(now.month)}-${two(now.day)}',
        'localTime': '${two(now.hour)}:${two(now.minute)}:${two(now.second)}',
        'source': 'smart_attendance_app',
        'cameraVerified': false,
        'gpsVerified': false,
        'faceMatched': false,
      });

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: ink,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: const Text(
            'Data absensi berhasil dikirim ke Firestore. '
            'Verifikasi kamera dan GPS masih simulasi.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _running = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: rose,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Text('Gagal menyimpan absensi: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _ready ? const Color(0xFF3DDC97) : sky;

    return Scaffold(
      backgroundColor: ink,
      body: Stack(
        children: [
          Positioned(
            top: -120,
            left: -80,
            child: Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [blue.withOpacity(0.45), Colors.transparent],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Absensi wajah',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: 270,
                        height: 330,
                        child: AnimatedBuilder(
                          animation: _ctl,
                          builder: (context, _) {
                            final t = _ctl.value;
                            final pulse = Curves.easeOut.transform(t);
                            final scanY = (math.sin(t * math.pi * 2) + 1) / 2;
                            return Stack(
                              alignment: Alignment.center,
                              children: [
                                Opacity(
                                  opacity: (1 - pulse) * 0.55,
                                  child: Transform.scale(
                                    scale: 0.92 + pulse * 0.14,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(56),
                                        border: Border.all(
                                          color: accent,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Container(
                                  margin: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(44),
                                    color: Colors.white.withOpacity(0.05),
                                  ),
                                  child: Center(
                                    child: AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 350,
                                      ),
                                      child: Icon(
                                        _ready
                                            ? Icons.verified_rounded
                                            : Icons
                                                  .face_retouching_natural_rounded,
                                        key: ValueKey(_ready),
                                        size: 110,
                                        color: accent.withOpacity(0.9),
                                      ),
                                    ),
                                  ),
                                ),
                                if (!_ready)
                                  Positioned(
                                    left: 28,
                                    right: 28,
                                    top: 30 + scanY * 262,
                                    child: Container(
                                      height: 3,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(3),
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.transparent,
                                            accent,
                                            Colors.transparent,
                                          ],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: accent.withOpacity(0.7),
                                            blurRadius: 14,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                Positioned.fill(
                                  child: CustomPaint(
                                    painter: BracketPainter(color: accent),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 26),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          _ready ? 'Wajah terverifikasi' : 'Verifikasi wajah',
                          key: ValueKey(_ready),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _ready
                            ? 'Semua pemeriksaan lolos. Konfirmasi untuk mencatat kehadiran.'
                            : 'Posisikan wajah di dalam bingkai dan pastikan pencahayaan cukup.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          height: 1.55,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.08),
                          ),
                        ),
                        child: Column(
                          children: [
                            _CheckRow(
                              icon: Icons.camera_alt_outlined,
                              title: 'Kamera',
                              idle: 'Belum diaktifkan',
                              done: 'Siap digunakan',
                              state: _steps[0],
                            ),
                            const SizedBox(height: 16),
                            _CheckRow(
                              icon: Icons.location_on_outlined,
                              title: 'Lokasi GPS',
                              idle: 'Belum diperiksa',
                              done: 'Berada di area sekolah',
                              state: _steps[1],
                            ),
                            const SizedBox(height: 16),
                            _CheckRow(
                              icon: Icons.fingerprint_rounded,
                              title: 'Pencocokan wajah',
                              idle: 'Menunggu pemeriksaan',
                              done: 'Cocok dengan data siswa',
                              state: _steps[2],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: _ready
                                ? const LinearGradient(
                                    colors: [
                                      Color(0xFF13A872),
                                      Color(0xFF3DDC97),
                                    ],
                                  )
                                : brandGradient,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: accent.withOpacity(0.35),
                                blurRadius: 26,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _running
                                ? null
                                : (_ready ? _confirm : _simulate),
                            style: ElevatedButton.styleFrom(
                              elevation: 0,
                              backgroundColor: Colors.transparent,
                              disabledBackgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              disabledForegroundColor: Colors.white70,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: Text(
                              _running
                                  ? 'Memeriksa...'
                                  : (_ready
                                        ? 'Konfirmasi absensi'
                                        : 'Periksa kesiapan'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Mode simulasi: kamera dan GPS belum terhubung.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String idle;
  final String done;
  final int state;

  const _CheckRow({
    required this.icon,
    required this.title,
    required this.idle,
    required this.done,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final isDone = state == 2;
    final color = isDone ? const Color(0xFF3DDC97) : sky;

    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withOpacity(0.14),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color, size: 21),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                isDone ? done : (state == 1 ? 'Sedang diperiksa...' : idle),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.55),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          width: 24,
          height: 24,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: switch (state) {
              1 => CircularProgressIndicator(
                key: const ValueKey('load'),
                strokeWidth: 2.4,
                color: color,
              ),
              2 => Icon(
                Icons.check_circle_rounded,
                key: const ValueKey('ok'),
                color: color,
              ),
              _ => Icon(
                Icons.radio_button_unchecked_rounded,
                key: const ValueKey('wait'),
                color: Colors.white.withOpacity(0.25),
              ),
            },
          ),
        ),
      ],
    );
  }
}

class BracketPainter extends CustomPainter {
  final Color color;

  BracketPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    const inset = 8.0;
    const len = 38.0;
    const r = 22.0;
    final w = size.width, h = size.height;

    Path corner(double x, double y, double dx, double dy) {
      return Path()
        ..moveTo(x, y + dy * len)
        ..lineTo(x, y + dy * r)
        ..quadraticBezierTo(x, y, x + dx * r, y)
        ..lineTo(x + dx * len, y);
    }

    canvas.drawPath(corner(inset, inset, 1, 1), p);
    canvas.drawPath(corner(w - inset, inset, -1, 1), p);
    canvas.drawPath(corner(inset, h - inset, 1, -1), p);
    canvas.drawPath(corner(w - inset, h - inset, -1, -1), p);
  }

  @override
  bool shouldRepaint(covariant BracketPainter old) => old.color != color;
}

// ───────────────────────── History ─────────────────────────

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  AttStatus? filter;

  @override
  Widget build(BuildContext context) {
    final filters = <(String, AttStatus?)>[
      ('Semua', null),
      ('Hadir', AttStatus.hadir),
      ('Terlambat', AttStatus.terlambat),
      ('Izin', AttStatus.izin),
    ];

    final records = sampleRecords
        .where(
          (r) =>
              filter == null ||
              r.status == filter ||
              (filter == AttStatus.hadir && r.status == AttStatus.contoh),
        )
        .toList();

    return PageShell(
      children: [
        const Text(
          'Riwayat absensi',
          style: TextStyle(
            color: navy,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Pantau catatan kehadiranmu.',
          style: TextStyle(color: muted, fontSize: 13),
        ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: brandGradient,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: blue.withOpacity(0.3),
                blurRadius: 30,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: const Row(
            children: [
              _MiniStat(value: '18', label: 'Hadir'),
              _Divider(),
              _MiniStat(value: '2', label: 'Terlambat'),
              _Divider(),
              _MiniStat(value: '1', label: 'Izin'),
              _Divider(),
              _MiniStat(value: '0', label: 'Alpa'),
            ],
          ),
        ),
        const SizedBox(height: 22),
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: filters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final f = filters[i];
              final selected = filter == f.$2;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => filter = f.$2);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? ink : Colors.white,
                    borderRadius: BorderRadius.circular(21),
                    boxShadow: selected ? null : softShadow(0.04),
                  ),
                  child: Text(
                    f.$1,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : muted,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 22),
        const SectionHeading(
          title: 'Oktober 2026',
          subtitle: 'Urut dari yang terbaru',
        ),
        const SizedBox(height: 14),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Column(
            key: ValueKey(filter),
            children: [
              for (final r in records) ...[
                ActivityTile(record: r),
                const SizedBox(height: 12),
              ],
              if (records.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: const [
                      Icon(Icons.inbox_outlined, size: 40, color: muted),
                      SizedBox(height: 10),
                      Text(
                        'Belum ada catatan untuk filter ini.',
                        style: TextStyle(color: muted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          '* Riwayat masih berupa data contoh, belum dari Firebase.',
          style: TextStyle(color: muted, fontSize: 11),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String value;
  final String label;

  const _MiniStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(color: Color(0xFFD8E2FF), fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 34,
      color: Colors.white.withOpacity(0.18),
    );
  }
}

// ───────────────────────── Profile ─────────────────────────

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool reminder = true;

  @override
  Widget build(BuildContext context) {
    return PageShell(
      children: [
        const Text(
          'Profil siswa',
          style: TextStyle(
            color: navy,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 22),
        ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: Container(
            decoration: BoxDecoration(
              gradient: brandGradient,
              boxShadow: [
                BoxShadow(
                  color: blue.withOpacity(0.3),
                  blurRadius: 30,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -50,
                  top: -50,
                  child: _Orb(size: 180, opacity: 0.09),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.4),
                            width: 2,
                          ),
                        ),
                        child: const CircleAvatar(
                          radius: 42,
                          backgroundColor: Colors.white,
                          child: Icon(
                            Icons.person_rounded,
                            size: 48,
                            color: blue,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Nama Siswa',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Siswa di Smart Attendance',
                        style: TextStyle(
                          color: Color(0xFFD8E2FF),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Row(
                          children: [
                            _MiniStat(value: '86%', label: 'Kehadiran'),
                            _Divider(),
                            _MiniStat(value: '18', label: 'Hari hadir'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: cardDecoration(radius: 26),
          child: const Column(
            children: [
              InfoRow(
                icon: Icons.badge_outlined,
                title: 'Nomor induk siswa',
                value: 'Belum diatur',
              ),
              SizedBox(height: 18),
              InfoRow(
                icon: Icons.school_outlined,
                title: 'Kelas',
                value: 'Belum diatur',
              ),
              SizedBox(height: 18),
              InfoRow(
                icon: Icons.face_retouching_natural_rounded,
                title: 'Data wajah',
                value: 'Belum didaftarkan',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
          decoration: cardDecoration(radius: 26),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF0FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.notifications_active_outlined,
                  color: blue,
                  size: 21,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pengingat absensi',
                      style: TextStyle(
                        color: navy,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Ingatkan 15 menit sebelum masuk',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Switch(
                value: reminder,
                activeColor: Colors.white,
                activeTrackColor: blue,
                onChanged: (v) {
                  HapticFeedback.selectionClick();
                  setState(() => reminder = v);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 54,
          child: OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.logout_rounded, size: 20),
            label: const Text(
              'Keluar',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: rose,
              side: BorderSide(color: rose.withOpacity(0.3)),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Informasi profil ini masih contoh dan bisa disesuaikan nanti.',
          style: TextStyle(color: muted, fontSize: 12),
        ),
      ],
    );
  }
}
