import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/constants/app_spacing.dart';
import '../services/music_provider.dart';
import '../widgets/mini_player.dart';
import '../widgets/full_screen_player.dart';
import 'home_screen.dart';
import 'explore_screen.dart';
import 'search_screen.dart';
import 'library_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

// ignore: library_private_types_in_public_api
static _MainNavigationState? of(BuildContext context) =>
    context.findAncestorStateOfType<_MainNavigationState>();

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  final TextEditingController _searchController = TextEditingController();

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const HomeScreen(),
      const ExploreScreen(),
      SearchScreen(externalController: _searchController),
      const LibraryScreen(),
    ];
  }

  void goToSearch(String query) {
    setState(() => _currentIndex = 2);
    _searchController.text = query;
    // Trigger the search immediately after nav (provider already called by ExploreScreen)
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasSong =
        context.select((MusicProvider p) => p.currentSong != null);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Screen content ───────────────────────────────────────────────
          IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),

          // ── Mini player (floats above nav bar) ───────────────────────────
          if (hasSong)
            Positioned(
              bottom: AppSpacing.navBarHeight + AppSpacing.sm,
              left: 0,
              right: 0,
              child: GestureDetector(
                onTap: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const FullScreenPlayer(),
                ),
                child: const MiniPlayer(),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _NavBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

// ── Navigation Bar ────────────────────────────────────────────────────────────

class _NavBar extends StatelessWidget {
  final int currentIndex;
  final void Function(int) onTap;
  const _NavBar({required this.currentIndex, required this.onTap});

  static const List<_NavItem> _items = [
    _NavItem(icon: Icons.home_rounded,          label: 'Accueil'),
    _NavItem(icon: Icons.grid_view_rounded,     label: 'Explorer'),
    _NavItem(icon: Icons.search_rounded,        label: 'Recherche'),
    _NavItem(icon: Icons.library_music_rounded, label: 'Bibliothèque'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.navBackground,
        border: Border(
          top: BorderSide(color: AppColors.navBorder, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: AppSpacing.navBarHeight,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(
              _items.length,
              (i) => _NavButton(
                item: _items[i],
                selected: currentIndex == i,
                onTap: () => onTap(i),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

class _NavButton extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;
  const _NavButton(
      {required this.item,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color =
        selected ? AppColors.accent : AppColors.textTertiary;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, anim) =>
                  FadeTransition(opacity: anim, child: child),
              child: Icon(item.icon,
                  key: ValueKey(selected), color: color, size: 24),
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              style: AppTextStyles.caption2.copyWith(
                color: color,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}