import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/music_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final provider = context.watch<MusicProvider>();
    
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: CustomScrollView(
        slivers: [
          // App Bar avec profil
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: const Color(0xFF0A0A0A),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Color(0xFFFF2D55)),
              onPressed: () => Navigator.of(context).pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF1C1C1E),
                      Color(0xFF0A0A0A),
                    ],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      // Avatar
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFFF2D55),
                            width: 3,
                          ),
                        ),
                        child: ClipOval(
                          child: authService.userAvatar != null
                              ? Image.network(
                                  authService.userAvatar!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _defaultAvatar(),
                                )
                              : _defaultAvatar(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Nom
                      Text(
                        authService.userName ?? 'Utilisateur',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Email
                      Text(
                        authService.userEmail ?? '',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Statistiques
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatColumn(
                        value: '${provider.favoriteSongs.length}',
                        label: 'Favoris',
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: Colors.white12,
                      ),
                      _StatColumn(
                        value: '${provider.playlists.length}',
                        label: 'Playlists',
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: Colors.white12,
                      ),
                      _StatColumn(
                        value: '${provider.downloadedSongs.length}',
                        label: 'Téléchargés',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Synchronisation
                const Text(
                  'Synchronisation',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),

                _SettingsTile(
                  icon: Icons.cloud_sync_rounded,
                  title: 'Synchroniser maintenant',
                  subtitle: 'Enregistrer dans le cloud',
                  onTap: () async {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('☁️ Synchronisation en cours...'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                    
                    // Forcer la synchronisation
                    await provider.loadFromSupabase();
                    
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: Color(0xFF30D158),
                        content: Text('✅ Synchronisé !',
                            style: TextStyle(color: Colors.black)),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),

                _SettingsTile(
                  icon: Icons.autorenew_rounded,
                  title: 'Lecture automatique',
                  subtitle: provider.autoPlayNext
                      ? 'Activée'
                      : 'Désactivée',
                  trailing: Switch(
                    value: provider.autoPlayNext,
                    onChanged: (_) => provider.toggleAutoPlay(),
                    activeColor: const Color(0xFFFF2D55),
                  ),
                  onTap: () => provider.toggleAutoPlay(),
                ),

                const SizedBox(height: 24),

                // Stockage
                const Text(
                  'Stockage',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),

                _SettingsTile(
                  icon: Icons.storage_rounded,
                  title: 'Téléchargements',
                  subtitle: '${provider.downloadedSongs.length} titre${provider.downloadedSongs.length != 1 ? 's' : ''}',
                  onTap: () {},
                ),

                const SizedBox(height: 24),

                // À propos
                const Text(
                  'À propos',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),

                _SettingsTile(
                  icon: Icons.info_outline_rounded,
                  title: 'Version',
                  subtitle: '1.0.0',
                  onTap: () {},
                ),

                _SettingsTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Confidentialité',
                  onTap: () {},
                ),

                const SizedBox(height: 24),

                // Déconnexion
                const Text(
                  'Compte',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),

                _SettingsTile(
                  icon: Icons.logout_rounded,
                  title: 'Se déconnecter',
                  subtitle: 'Vos données restent sauvegardées',
                  iconColor: const Color(0xFFFF453A),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        backgroundColor: const Color(0xFF1C1C1E),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        title: const Text('Déconnexion',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        content: const Text(
                          'Êtes-vous sûr de vouloir vous déconnecter ?\n\nVos données restent sauvegardées dans le cloud.',
                          style: TextStyle(color: Colors.white70),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Annuler',
                                style: TextStyle(color: Colors.grey)),
                          ),
                          TextButton(
                            onPressed: () async {
                              await authService.signOut();
                              if (!context.mounted) return;
                              Navigator.of(context).popUntil((route) => route.isFirst);
                            },
                            child: const Text('Déconnexion',
                                style: TextStyle(
                                  color: Color(0xFFFF453A),
                                  fontWeight: FontWeight.w600,
                                )),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _defaultAvatar() {
    return Container(
      color: const Color(0xFFFF2D55),
      child: const Center(
        child: Icon(Icons.person, color: Colors.white, size: 40),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String value;
  final String label;

  const _StatColumn({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: Color(0xFFFF2D55),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color iconColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.iconColor = Colors.white,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(title,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            )),
        subtitle: subtitle != null
            ? Text(subtitle!,
                style: const TextStyle(color: Colors.grey, fontSize: 12))
            : null,
        trailing: trailing ??
            const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
        onTap: onTap,
      ),
    );
  }
}
