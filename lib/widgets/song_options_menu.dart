import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/music_provider.dart';
import '../models/song.dart';
import '../main.dart';

void showSongOptionsMenu(BuildContext context, Song song) {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF1C1C1E),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return Consumer<MusicProvider>(
        builder: (_, provider, __) {
          final isLiked = provider.isFavorite(song);
          final isDownloaded = provider.isDownloaded(song);
          final isDownloading = provider.downloadProgress.containsKey(song.id);
          final progress = provider.downloadProgress[song.id] ?? 0.0;

          return SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Handle ──
                  const SizedBox(height: 12),
                  Center(
                      child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 12),

                  // ── Header ──────────────────────────────────────────────────
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.network(song.coverUrl,
                              width: 52,
                              height: 52,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                  width: 52,
                                  height: 52,
                                  color: Colors.white12,
                                  child: const Icon(Icons.music_note,
                                      color: Colors.white54))),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(song.title,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                Text(song.artist,
                                    style: const TextStyle(
                                        color: Colors.white60, fontSize: 13),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ]),
                        ),
                        if (isDownloaded)
                          const Icon(Icons.download_done_rounded,
                              color: Color(0xFF30D158), size: 22),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white12, height: 1),

                  // ── Options ──────────────────────────────────────────────────

                  // 1. Ajouter à la playlist
                  _item(ctx, Icons.add, 'Ajouter à la playlist',
                      showChevron: true, onTap: () {
                    Navigator.pop(ctx);
                    _showPlaylistPicker(context, song, provider);
                  }),

                  // 2. Liker / Déliker
                  _item(
                      ctx,
                      isLiked ? Icons.favorite : Icons.add_circle_outline,
                      isLiked
                          ? 'Retirer des Titres likés'
                          : 'Sauvegarder dans Titres likés',
                      iconColor: isLiked
                          ? const Color(0xFFFF2D55)
                          : Colors.white, onTap: () {
                    provider.toggleFavorite(song);
                    Navigator.pop(ctx);
                    _snack(isLiked
                        ? '💔 Retiré des favoris'
                        : '❤️ Ajouté aux favoris');
                  }),

                  // 3. Télécharger / Supprimer
                  if (isDownloading)
                    ListTile(
                      leading: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                              value: progress,
                              color: const Color(0xFF30D158),
                              strokeWidth: 2.5)),
                      title: Text(
                          'Téléchargement… ${(progress * 100).toInt()}%',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 15)),
                    )
                  else
                    _item(
                        ctx,
                        isDownloaded
                            ? Icons.delete_outline
                            : Icons.download_rounded,
                        isDownloaded
                            ? 'Supprimer le téléchargement'
                            : 'Télécharger',
                        iconColor: isDownloaded
                            ? const Color(0xFFFF453A)
                            : Colors.white, onTap: () {
                      if (isDownloaded) {
                        provider.removeDownload(song);
                        Navigator.pop(ctx);
                        _snack('🗑️ Téléchargement supprimé');
                      } else {
                        Navigator.pop(ctx);
                        _snack('⬇️ Téléchargement lancé…');
                        provider.downloadSong(song,
                            onComplete: () =>
                                _snackGreen('✅ "${song.title}" téléchargé !'));
                      }
                    }),

                  // 4. File d'attente
                  _item(ctx, Icons.queue_music_rounded,
                      "Ajouter à la file d'attente", onTap: () {
                    provider.addToQueue(song);
                    Navigator.pop(ctx);
                    _snack('📋 Ajouté à la file d\'attente');
                  }),

                  // 5. Radio liée
                  _item(ctx, Icons.sensors_rounded,
                      'Accéder à la radio liée au titre', onTap: () {
                    Navigator.pop(ctx);
                    _snack('📻 Radio : bientôt disponible');
                  }),

                  // 6. Accéder à l'artiste (recherche)
                  _item(
                      ctx, Icons.person_outline_rounded, "Accéder à l'artiste",
                      showChevron: true, onTap: () {
                    Navigator.pop(ctx);
                    provider.searchYouTube(song.artist);
                    _snack('🔍 Recherche : ${song.artist}');
                  }),

                  // 7. Accéder à l'album
                  _item(ctx, Icons.album_outlined, "Accéder à l'album",
                      onTap: () {
                    Navigator.pop(ctx);
                    _snack('💿 Album : ${song.title.split('(').first.trim()}');
                  }),

                  // 8. Afficher les crédits
                  _item(
                      ctx, Icons.receipt_long_outlined, 'Afficher les crédits',
                      onTap: () {
                    Navigator.pop(ctx);
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        backgroundColor: const Color(0xFF2C2C2E),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        title: Text(song.title,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700),
                            maxLines: 2),
                        content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _creditRow('Artiste', song.artist),
                              _creditRow('Durée', song.durationFormatted),
                              _creditRow('Source', 'YouTube Music via yt-dlp'),
                              _creditRow('ID', song.id),
                            ]),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Fermer',
                                  style: TextStyle(color: Color(0xFFFF2D55)))),
                        ],
                      ),
                    );
                  }),

                  // 9. Exclure du profil
                  _item(ctx, Icons.cancel_outlined,
                      'Exclure de votre profil de goût', onTap: () {
                    Navigator.pop(ctx);
                    _snack('🚫 Exclu de votre profil (disponible avec compte)');
                  }),

                  // 10. Partager (copie le lien YouTube)
                  _item(ctx, Icons.ios_share_rounded, 'Partager', onTap: () {
                    final url = 'https://www.youtube.com/watch?v=${song.id}';
                    Clipboard.setData(ClipboardData(text: url));
                    Navigator.pop(ctx);
                    _snack('🔗 Lien copié dans le presse-papier !');
                  }),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

// ── Helpers internes ────────────────────────────────────────────────────────

void _showPlaylistPicker(
    BuildContext context, Song song, MusicProvider provider) {
  if (provider.playlists.isEmpty) {
    _snack('Créez d\'abord une playlist dans l\'onglet Bibliothèque');
    return;
  }
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF1C1C1E),
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        const Text('Choisir une playlist',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white)),
        const Divider(color: Colors.white12, height: 24),
        ...provider.playlists.map((pl) => ListTile(
              leading:
                  const Icon(Icons.queue_music_rounded, color: Colors.white54),
              title: Text(pl['name'] as String,
                  style: const TextStyle(color: Colors.white)),
              subtitle: Text('${(pl['songs'] as List).length} titres',
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
              onTap: () {
                provider.addSongToPlaylist(pl['id'] as String, song);
                Navigator.pop(context);
                _snack('✅ Ajouté à "${pl['name']}"');
              },
            )),
        const SizedBox(height: 16),
      ],
    ),
  );
}

Widget _creditRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Text('$label : ',
          style: const TextStyle(color: Colors.white54, fontSize: 13)),
      Expanded(
          child: Text(value,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              overflow: TextOverflow.ellipsis)),
    ]),
  );
}

Widget _item(
  BuildContext context,
  IconData icon,
  String title, {
  VoidCallback? onTap,
  bool showChevron = false,
  Color iconColor = Colors.white,
}) {
  return ListTile(
    leading: Icon(icon, color: iconColor, size: 26),
    title:
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 15)),
    trailing: showChevron
        ? const Icon(Icons.chevron_right, color: Colors.white38)
        : null,
    onTap: onTap,
  );
}

void _snack(String msg) {
  scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(
    content: Text(msg),
    duration: const Duration(seconds: 2),
    behavior: SnackBarBehavior.floating,
  ));
}

void _snackGreen(String msg) {
  scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(
    backgroundColor: const Color(0xFF30D158),
    content: Text(msg,
        style:
            const TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
    duration: const Duration(seconds: 3),
    behavior: SnackBarBehavior.floating,
  ));
}
