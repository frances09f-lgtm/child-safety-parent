import 'package:flutter/material.dart';
import 'style.dart';
import 'screens.dart';

void main() => runApp(const PreviewApp());

class PreviewApp extends StatefulWidget {
  const PreviewApp({super.key});
  @override
  State<PreviewApp> createState() => _PreviewAppState();
}

class _PreviewAppState extends State<PreviewApp> {
  int _screen = 0; // 0 = parent app, 1 = client app

  void _setDark(bool v) => setState(() => XTheme.dark = v);

  @override
  Widget build(BuildContext context) {
    return PreviewState(
      setDark: _setDark,
      child: MaterialApp(
        title: 'Child Safety UI Preview',
        debugShowCheckedModeBanner: false,
        theme: XTheme.theme(),
        home: Scaffold(
          backgroundColor: XTheme.bg,
          body: Column(
            children: [
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: XTheme.card,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final (i, label) in [
                              (0, 'Parent app'),
                              (1, 'Client app'),
                            ])
                              XPress(
                                onTap: () => setState(() => _screen = i),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 280),
                                  curve: Curves.easeOutBack,
                                  padding: EdgeInsets.symmetric(
                                      horizontal:
                                          _screen == i ? 18 : 12,
                                      vertical: 9),
                                  decoration: BoxDecoration(
                                    color: _screen == i
                                        ? X.ink
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(label,
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: _screen == i
                                              ? Colors.white
                                              : XTheme.inkSoft)),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: X.lemon,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Text('UI PREVIEW',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                color: X.lemonDeep)),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _screen == 0
                      ? const ParentFamilyScreen(key: ValueKey('parent'))
                      : const ClientHomeScreen(key: ValueKey('client')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
