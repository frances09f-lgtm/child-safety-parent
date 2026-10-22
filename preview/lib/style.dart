import 'package:flutter/material.dart';

/// Child Safety UI preview style: pastel rounded surfaces, pill chips,
/// big toggles, floating dock, springy motion. Recreated in-house.
class X {
  static const bg = Color(0xFFFAF7F2);
  static const ink = Color(0xFF201A17);
  static const inkSoft = Color(0xFF6F675F);
  static const mint = Color(0xFFD8F0DC);
  static const mintDeep = Color(0xFF1E6B3C);
  static const lavender = Color(0xFFE9E2FB);
  static const lavenderDeep = Color(0xFF5A3FA8);
  static const peach = Color(0xFFFFE4CE);
  static const peachDeep = Color(0xFF9A4A12);
  static const sky = Color(0xFFD9EAFB);
  static const skyDeep = Color(0xFF1D5A96);
  static const lemon = Color(0xFFF7F0C8);
  static const lemonDeep = Color(0xFF77680A);
  static const white = Colors.white;
  static const red = Color(0xFFE5484D);

  // Dark variants
  static const dBg = Color(0xFF171411);
  static const dCard = Color(0xFF23201C);
  static const dInk = Color(0xFFF2EDE6);
  static const dInkSoft = Color(0xFFB4ABA0);
}

class XTheme {
  static bool dark = false; // flipped by the preview shell

  static Color get bg => dark ? X.dBg : X.bg;
  static Color get card => dark ? X.dCard : X.white;
  static Color get ink => dark ? X.dInk : X.ink;
  static Color get inkSoft => dark ? X.dInkSoft : X.inkSoft;

  static ThemeData theme() => ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: X.lavenderDeep,
          brightness: dark ? Brightness.dark : Brightness.light,
        ).copyWith(surface: bg),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      );
}

/// Springy scale-on-press wrapper.
class XPress extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const XPress({super.key, required this.child, this.onTap});

  @override
  State<XPress> createState() => _XPressState();
}

class _XPressState extends State<XPress> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.97 : 1,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}

Widget xSwitch({
  required bool value,
  required Color accent,
  required ValueChanged<bool> onChanged,
}) {
  return Transform.scale(
    scale: 1.12,
    child: Switch(
      value: value,
      onChanged: onChanged,
      activeThumbColor: Colors.white,
      activeTrackColor: accent,
      inactiveThumbColor: X.inkSoft,
      inactiveTrackColor: XTheme.dark ? X.dCard : const Color(0xFFEDE8E0),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
  );
}

class XToggleTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color bg;
  final Color accent;
  final bool value;
  final ValueChanged<bool> onChanged;

  const XToggleTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.bg,
    required this.accent,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: value ? bg : XTheme.card,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutBack,
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: value ? accent : (XTheme.dark ? X.dBg : const Color(0xFFEDE8E0)),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon,
                size: 22, color: value ? Colors.white : XTheme.inkSoft),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: XTheme.ink)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(fontSize: 12.5, color: XTheme.inkSoft)),
              ],
            ),
          ),
          xSwitch(value: value, accent: accent, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// Floating pill dock with a springy selected-tab transition.
class XDock extends StatelessWidget {
  final List<(IconData, String)> items;
  final int selected;
  final void Function(int) onSelect;

  const XDock({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: XTheme.card,
          borderRadius: BorderRadius.circular(36),
          boxShadow: const [
            BoxShadow(
                color: Color(0x22000000), blurRadius: 24, offset: Offset(0, 8)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (var i = 0; i < items.length; i++)
              XPress(
                onTap: () => onSelect(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutBack,
                  padding: EdgeInsets.symmetric(
                      horizontal: i == selected ? 20 : 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: i == selected ? X.ink : Colors.transparent,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [
                      Icon(items[i].$1,
                          size: 22,
                          color: i == selected ? Colors.white : XTheme.inkSoft),
                      if (i == selected) ...[
                        const SizedBox(width: 8),
                        Text(items[i].$2,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13)),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
