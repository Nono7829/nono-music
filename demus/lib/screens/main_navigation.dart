import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/music_provider.dart';
import '../services/auth_service.dart';
import '../widgets/mini_player.dart';
import '../widgets/full_screen_player.dart';
import 'home_screen.dart';
import 'explore_screen.dart';
import 'search_screen.dart';
import 'library_screen.dart';
import 'profile_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  // AJOUT : Permet aux autres écrans de trouver ce widget
  static _MainNavigationState? of(BuildContext context) {
    return context.findAncestorStateOfType<_MainNavigationState>();
  }

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  // AJOUT : Contrôleur pour passer le texte à la recherche
  final TextEditingController _searchController = TextEditingController();

  // MODIFICATION : "late final" au lieu de "const" pour pouvoir passer le contrôleur
  late final List<Widget> _screens = [
    const HomeScreen(),
    const ExploreScreen(),
    SearchScreen(externalController: _searchController), // AJOUT DU CONTRÔLEUR ICI
    const LibraryScreen(),
  ];

  // AJOUT : La méthode appelée par ExploreScreen
  void goToSearch(String query) {
    setState(() {
      _currentIndex = 2; // Va sur l'onglet recherche
    });
    _searchController.text = query; // Remplis le texte
  }

  // AJOUT : Nettoyage du contrôleur
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MusicProvider>();
    final authService = AuthService();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Stack(
        children: [
          _screens[_currentIndex],

          // Mini player flottant au-dessus de la nav bar
          Positioned(
            bottom: 65,
            left: 0,
            right: 0,
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
      bottomNavigationBar: _buildNavBar(authService),
    );
  }

  Widget _buildNavBar(AuthService authService) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.08), width: 0.5), // Remplacé withValues par withOpacity au cas où
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 65,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home_rounded,
                label: 'Accueil',
                selected: _currentIndex == 0,
                onTap: () => setState(() => _currentIndex = 0),
              ),
              _NavItem(
                icon: Icons.grid_view_rounded,
                label: 'Explorer',
                selected: _currentIndex == 1,
                onTap: () => setState(() => _currentIndex = 1),
              ),
              _NavItem(
                icon: Icons.search_rounded,
                label: 'Recherche',
                selected: _currentIndex == 2,
                onTap: () => setState(() => _currentIndex = 2),
              ),
              _NavItem(
                icon: Icons.library_music_rounded,
                label: 'Bibliothèque',
                selected: _currentIndex == 3,
                onTap: () => setState(() => _currentIndex = 3),
              ),
              _ProfileNavItem(
                selected: false,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  );
                },
                avatarUrl: authService.userAvatar,
              ),
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

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFFFF2D55) : Colors.grey;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 70,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(icon, color: color, size: 26, key: ValueKey(selected)),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileNavItem extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final String? avatarUrl;

  const _ProfileNavItem({
    required this.selected,
    required this.onTap,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 70,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? const Color(0xFFFF2D55) : Colors.grey,
                  width: 2,
                ),
              ),
              child: ClipOval(
                child: avatarUrl != null && avatarUrl!.isNotEmpty
                    ? Image.network(
                        avatarUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _defaultAvatar(),
                      )
                    : _defaultAvatar(),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Profil',
              style: TextStyle(
                color: selected ? const Color(0xFFFF2D55) : Colors.grey,
                fontSize: 10,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _defaultAvatar() {
    return Container(
      color: const Color(0xFFFF2D55),
      child: const Center(
        child: Icon(Icons.person, color: Colors.white, size: 16),
      ),
    );
  }
}