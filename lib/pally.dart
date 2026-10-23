import 'package:flutter/material.dart';

import 'main.dart';

class SafetyHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  const SafetyHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });
  @override
  Size get preferredSize => const Size.fromHeight(112);
  @override
  Widget build(BuildContext context) {
    return Container(
      color: pale,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 4, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Text(
                          'CHILD SAFETY',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                            color: muted,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: soft,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            'PARENT',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: onSoft,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.6,
                        color: ink,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: TextStyle(fontSize: 12, color: muted),
                      ),
                  ],
                ),
              ),
              ...actions,
            ],
          ),
        ),
      ),
    );
  }
}

class SafetyDockItem {
  final IconData icon;
  final String label;
  const SafetyDockItem(this.icon, this.label);
}

class SafetyDock extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  final List<SafetyDockItem> items;
  const SafetyDock({
    super.key,
    required this.index,
    required this.onTap,
    required this.items,
  });
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          height: 60,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: edge),
          ),
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTap(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: i == index ? soft : Colors.transparent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            items[i].icon,
                            size: 20,
                            color: i == index ? onSoft : muted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            items[i].label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: i == index ? onSoft : muted,
                            ),
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
}
