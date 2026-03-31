import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/music_provider.dart';
import '../widgets/mini_player.dart';
import '../widgets/full_screen_player.dart';
import 'home_screen.dart';
import 'explore_screen.dart';
import 'search_screen.dart';
import 'library_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  static _MainNavigationState? of(BuildContext context) =>
      context.findAncestorStateOfType<_MainNavigationState>();

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  final TextEditingController searchController = TextEditingController();

  void goToSearch(String query) {
    searchController.text = query;
    setState(() => _currentIndex = 2);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MusicProvider>().searchYouTube(query);
    });
  }

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const HomeScreen(),
      const ExploreScreen(),
      SearchScreen(externalController: searchController),
      const LibraryScreen(),
    ];
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MusicProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Stack(
        children: [
          IndexedStack(index: _currentIndex, children: _screens),
          Positioned(
            bottom: 65, left: 0, right: 0,
            child: GestureDetector(
              onTap: () {
                if (provider.currentSong != null) {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const FullScreenPlayer(),
                  );
                }
              },
              child: const MiniPlayer(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildNavBar(),
    );
  }

  Widget _buildNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08), width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 65,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(icon: Icons.home_rounded, label: 'Accueil',
                  selected: _currentIndex == 0,
                  onTap: () => setState(() => _currentIndex = 0)),
              _NavItem(icon: Icons.grid_view_rounded, label: 'Explorer',
                  selected: _currentIndex == 1,
                  onTap: () => setState(() => _currentIndex = 1)),
              _NavItem(icon: Icons.search_rounded, label: 'Recherche',
                  selected: _currentIndex == 2,
                  onTap: () => setState(() => _currentIndex = 2)),
              _NavItem(icon: Icons.library_music_rounded, label: 'Bibliothèque',
                  selected: _currentIndex == 3,
                  onTap: () => setState(() => _currentIndex = 3)),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _NavItem({required this.icon, required this.label,
      required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFFFF2D55) : Colors.grey;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 90,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(icon, color: color, size: 26, key: ValueKey(selected)),
            ),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(
              color: color, fontSize: 10,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            )),
          ],
        ),
      ),
    );
  }
}