import 'package:flutter/material.dart';
import 'style.dart';

class _MiniMap extends StatelessWidget {
  final Color accent;
  final String city;
  const _MiniMap({required this.accent, required this.city});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 108,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: _MapPainter(accent)),
            Center(
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                ),
              ),
            ),
            Positioned(
              left: 10,
              bottom: 10,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: X.ink.withValues(alpha: .85),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(city,
                    style: const TextStyle(color: Colors.white, fontSize: 11)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  final Color accent;
  _MapPainter(this.accent);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Offset.zero & size, Paint()..color = const Color(0xFFEFF3EC));
    final road = Paint()
      ..color = Colors.white
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(-20, size.height * .35),
        Offset(size.width + 20, size.height * .55), road);
    canvas.drawLine(Offset(size.width * .3, -20),
        Offset(size.width * .55, size.height + 20), road);
    final park = Paint()..color = const Color(0xFFDCEBD8);
    canvas.drawCircle(Offset(size.width * .8, size.height * .25), 26, park);
    canvas.drawCircle(Offset(size.width * .15, size.height * .85), 20, park);
    final route = Paint()
      ..color = accent.withValues(alpha: .5)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(size.width * .15, size.height * .8)
      ..quadraticBezierTo(
          size.width * .4, size.height * .5, size.width * .5, size.height * .5)
      ..quadraticBezierTo(size.width * .65, size.height * .5,
          size.width * .8, size.height * .3);
    canvas.drawPath(path, route);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Parent app: Your Family
// ---------------------------------------------------------------------------
class ParentFamilyScreen extends StatefulWidget {
  const ParentFamilyScreen({super.key});
  @override
  State<ParentFamilyScreen> createState() => _ParentFamilyScreenState();
}

class _ParentFamilyScreenState extends State<ParentFamilyScreen> {
  int _tab = 0;

  Widget _stat(String label, String value, Color bg, Color fg) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration:
              BoxDecoration(color: bg, borderRadius: BorderRadius.circular(18)),
          child: Column(
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 9.5, fontWeight: FontWeight.w700, color: fg)),
              const SizedBox(height: 3),
              Text(value,
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w800, color: fg)),
            ],
          ),
        ),
      );

  Widget childCard({
    required String name,
    required String device,
    required bool live,
    required bool sos,
    required Color bg,
    required Color accent,
    required String city,
    required String battery,
    required String lastReport,
    String? zoneAlert,
  }) {
    return XPress(
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$name - full report opens here in the real app'))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(32)),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(20)),
                        alignment: Alignment.center,
                        child: Text(name[0].toUpperCase(),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(name,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: X.ink)),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: live
                                        ? accent
                                        : const Color(0xFFEDE8E0),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Text(live ? 'Live' : 'Last known',
                                      style: TextStyle(
                                          color: live
                                              ? Colors.white
                                              : X.inkSoft,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text('Android - $device',
                                style: TextStyle(
                                    fontSize: 12, color: X.inkSoft)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _MiniMap(accent: accent, city: city),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _stat('BATTERY', battery, XTheme.card, X.ink),
                      _stat('LAST REPORT', lastReport, XTheme.card, X.ink),
                      _stat(
                          'STATUS',
                          live ? 'Live GPS' : 'Last known',
                          live ? accent : XTheme.card,
                          live ? Colors.white : X.inkSoft),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: zoneAlert == null ? XTheme.card : X.lemon,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      zoneAlert ?? 'No zone alerts yet',
                      style: TextStyle(
                          fontSize: 11.5,
                          color: zoneAlert == null ? X.inkSoft : X.lemonDeep,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            if (sos)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: const BoxDecoration(
                    color: X.red,
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(32),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                  child: const Text('SOS ACTIVE',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      bottomNavigationBar: XDock(
        items: const [
          (Icons.family_restroom_rounded, 'Children'),
          (Icons.settings_rounded, 'Settings'),
        ],
        selected: _tab,
        onSelect: (i) => setState(() => _tab = i),
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _tab == 1
              ? ListView(
                  key: const ValueKey('settings'),
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                  children: [
                    Text('Parent Account Settings',
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                            color: XTheme.ink)),
                    const SizedBox(height: 18),
                    XToggleTile(
                      icon: Icons.dark_mode_rounded,
                      title: 'Dark mode',
                      subtitle: 'Easier on the eyes at night',
                      bg: X.lavender,
                      accent: X.lavenderDeep,
                      value: XTheme.dark,
                      onChanged: (v) =>
                          PreviewState.of(context).setDark(v),
                    ),
                    const SizedBox(height: 12),
                    XToggleTile(
                      icon: Icons.notifications_active_rounded,
                      title: 'Zone alerts',
                      subtitle: 'Push when a child enters or leaves a zone',
                      bg: X.lemon,
                      accent: X.lemonDeep,
                      value: true,
                      onChanged: (_) {},
                    ),
                  ],
                )
              : ListView(
                  key: const ValueKey('children'),
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Your Family',
                                  style: TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.8,
                                      color: XTheme.ink)),
                              const SizedBox(height: 2),
                              Text('2 protected devices connected',
                                  style: TextStyle(
                                      fontSize: 12.5, color: XTheme.inkSoft)),
                            ],
                          ),
                        ),
                        IconButton(
                            onPressed: () {},
                            icon: Icon(Icons.refresh_rounded,
                                color: XTheme.inkSoft)),
                      ],
                    ),
                    const SizedBox(height: 18),
                    childCard(
                      name: 'jee',
                      device: 'OnePlus Nord',
                      live: true,
                      sos: false,
                      bg: X.mint,
                      accent: X.mintDeep,
                      city: 'Ichalkaranji - +/-12m',
                      battery: '68%',
                      lastReport: '2 min ago',
                      zoneAlert: 'Zone Alert: Left Home - 9:41 AM',
                    ),
                    childCard(
                      name: 'non',
                      device: 'vivo',
                      live: false,
                      sos: true,
                      bg: X.lavender,
                      accent: X.lavenderDeep,
                      city: 'Ichalkaranji - +/-30m',
                      battery: '41%',
                      lastReport: '1 hr ago',
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'Reports refresh while open. This app does not call emergency services.',
                        style: TextStyle(fontSize: 11, color: XTheme.inkSoft),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Client app (child phone)
// ---------------------------------------------------------------------------
class ClientHomeScreen extends StatefulWidget {
  const ClientHomeScreen({super.key});
  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen> {
  bool _sharing = true;
  bool _tracking = true;

  Widget infoCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color bg,
    required Color accent,
  }) {
    return XPress(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(28)),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                  color: accent, borderRadius: BorderRadius.circular(18)),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: X.ink)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(fontSize: 12.5, color: X.inkSoft)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('This phone',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: XTheme.inkSoft)),
                ),
                Icon(Icons.system_update_alt_rounded, color: XTheme.inkSoft),
                const SizedBox(width: 16),
                XPress(
                  onTap: () => PreviewState.of(context).setDark(!XTheme.dark),
                  child: Icon(
                      XTheme.dark
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_outlined,
                      color: XTheme.inkSoft),
                ),
              ],
            ),
            const SizedBox(height: 18),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Text(
                _tracking ? 'Tracking is active' : 'Ready when you are',
                key: ValueKey(_tracking),
                style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                    height: 1.1,
                    color: XTheme.ink),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _tracking
                  ? 'Reports about every 5 min. Change the interval on the parent dashboard.'
                  : 'Tracking is paused. Nothing is being shared.',
              style: TextStyle(
                  fontSize: 13, height: 1.5, color: XTheme.inkSoft),
            ),
            const SizedBox(height: 20),
            infoCard(
              icon: Icons.gps_fixed_rounded,
              title: _tracking ? 'Live GPS' : 'GPS paused',
              subtitle: 'Last fix 9:41 AM - +/-12 m - Ichalkaranji',
              bg: _tracking ? X.mint : XTheme.card,
              accent: X.mintDeep,
            ),
            infoCard(
              icon: Icons.battery_5_bar_rounded,
              title: 'Battery 68%',
              subtitle: 'Background reporting healthy',
              bg: XTheme.card,
              accent: X.skyDeep,
            ),
            infoCard(
              icon: Icons.wifi_rounded,
              title: 'Connected',
              subtitle: 'Syncing with the parent dashboard',
              bg: XTheme.card,
              accent: X.lavenderDeep,
            ),
            XToggleTile(
              icon: Icons.location_on_rounded,
              title: 'Location sharing',
              subtitle:
                  _sharing ? 'Family can see this phone' : 'Sharing is off',
              bg: X.lemon,
              accent: X.lemonDeep,
              value: _sharing,
              onChanged: (v) => setState(() => _sharing = v),
            ),
            const SizedBox(height: 12),
            XToggleTile(
              icon: Icons.play_circle_rounded,
              title: 'Tracking',
              subtitle: _tracking
                  ? 'Reporting in the background'
                  : 'Paused by this phone',
              bg: X.mint,
              accent: X.mintDeep,
              value: _tracking,
              onChanged: (v) => setState(() => _tracking = v),
            ),
            const SizedBox(height: 22),
            XPress(
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('SOS saved for retry (preview only)'))),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: X.red,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Center(
                  child: Text('SEND SOS',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                'SOS is saved for retry if offline, even without GPS. This app does not call police or send SMS.',
                textAlign: TextAlign.center,
                style:
                    TextStyle(fontSize: 11, height: 1.6, color: XTheme.inkSoft),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared dark-mode bridge between screens and the shell.
class PreviewState extends InheritedWidget {
  final void Function(bool) setDark;
  const PreviewState({super.key, required this.setDark, required super.child});

  static PreviewState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PreviewState>()!;

  @override
  bool updateShouldNotify(PreviewState oldWidget) => true;
}
