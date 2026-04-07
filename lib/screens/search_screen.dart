import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../services/music_provider.dart';
import '../models/song.dart';
import '../widgets/full_screen_player.dart';
import '../widgets/song_options_menu.dart';
import '../main.dart';

class SearchScreen extends StatefulWidget {
  final TextEditingController? externalController;
  const SearchScreen({super.key, this.externalController});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _ctrl;
  final FocusNode _focus = FocusNode();
  bool _ownController = false;

  // ── Multi-sélection ──────────────────────────────────────────────────────
  final Set<String> _selectedIds = {};
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    if (widget.externalController != null) {
      _ctrl = widget.externalController!;
    } else {
      _ctrl = TextEditingController();
      _ownController = true;
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    if (_ownController) _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    context.read<MusicProvider>().searchDebounced(q);
    setState(() {});
  }

  void _submitSearch() {
    final q = _ctrl.text.trim();
    if (q.isEmpty) return;
    _focus.unfocus();
    context.read<MusicProvider>().searchYouTube(q);
  }

  void _toggleSong(Song song) {
    setState(() {
      if (_selectedIds.contains(song.id)) {
        _selectedIds.remove(song.id);
        if (_selectedIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedIds.add(song.id);
        _isSelectionMode = true;
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedIds.clear();
      _isSelectionMode = false;
    });
  }

  List<Song> get _selectedSongs {
    final all = context.read<MusicProvider>().songs;
    return all.where((s) => _selectedIds.contains(s.id)).toList();
  }

  void _addAllToQueue() {
    final provider = context.read<MusicProvider>();
    for (final s in _selectedSongs) {
      provider.addToQueue(s);
    }
    _clearSelection();
    scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(
      content: Text('📋 ${_selectedIds.length} titre(s) ajouté(s) à la file'),
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _downloadAll() {
    final provider = context.read<MusicProvider>();
    int count = 0;
    for (final s in _selectedSongs) {
      if (!provider.isDownloaded(s)) {
        provider.downloadSong(s);
        count++;
      }
    }
    _clearSelection();
    scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(
      content: Text('⬇️ Téléchargement de $count titre(s) lancé'),
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _showPlaylistPickerForSelection() {
    final provider = context.read<MusicProvider>();
    if (provider.playlists.isEmpty) {
      scaffoldMessengerKey.currentState?.showSnackBar(const SnackBar(
        content:
            Text('Créez d\'abord une playlist dans l\'onglet Bibliothèque'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    final songs = _selectedSongs;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Text(
            'Ajouter ${songs.length} titre(s) à…',
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          const Divider(color: Colors.white12, height: 24),
          ...provider.playlists.map((pl) => ListTile(
                leading: const Icon(Icons.queue_music_rounded,
                    color: Colors.white54),
                title: Text(pl['name'] as String,
                    style: const TextStyle(color: Colors.white)),
                subtitle: Text('${(pl['songs'] as List).length} titres',
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
                onTap: () {
                  for (final s in songs) {
                    provider.addSongToPlaylist(pl['id'] as String, s);
                  }
                  Navigator.pop(ctx);
                  _clearSelection();
                  scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(
                    content: Text(
                        '✅ ${songs.length} titre(s) ajouté(s) à "${pl['name']}"'),
                    behavior: SnackBarBehavior.floating,
                  ));
                },
              )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MusicProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── App Bar ───────────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.background,
            expandedHeight: 100,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(
                  left: AppSpacing.screenHPad, bottom: AppSpacing.md),
              title: _isSelectionMode
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: _clearSelection,
                          child: const Icon(Icons.close_rounded,
                              color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_selectedIds.length} sélectionné(s)',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white),
                        ),
                      ],
                    )
                  : const Text('Recherche', style: AppTextStyles.title1),
              background: Container(color: AppColors.background),
            ),
            actions: [
              if (!_isSelectionMode)
                Consumer<MusicProvider>(
                  builder: (_, prov, __) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: prov.toggleSearchSource,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: prov.useSpotify
                              ? const Color(0xFF1DB954).withValues(alpha: 0.15)
                              : AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: prov.useSpotify
                                ? const Color(0xFF1DB954)
                                : AppColors.borderDefault,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              prov.useSpotify
                                  ? Icons.music_note_rounded
                                  : Icons.play_circle_outline_rounded,
                              size: 14,
                              color: prov.useSpotify
                                  ? const Color(0xFF1DB954)
                                  : Colors.white70,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              prov.useSpotify ? 'Spotify' : 'YouTube',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: prov.useSpotify
                                    ? const Color(0xFF1DB954)
                                    : Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              if (_isSelectionMode)
                if (_isSelectionMode) ...[
                  IconButton(
                    tooltip: 'Tout sélectionner',
                    icon: const Icon(Icons.select_all_rounded,
                        color: Colors.white),
                    onPressed: () {
                      setState(() {
                        _selectedIds.clear();
                        for (final s in provider.songs) {
                          _selectedIds.add(s.id);
                        }
                        _isSelectionMode = true;
                      });
                    },
                  ),
                ],
            ],
          ),

          // ── Champ de recherche ────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screenHPad,
                  AppSpacing.sm, AppSpacing.screenHPad, 0),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: TextField(
                  controller: _ctrl,
                  focusNode: _focus,
                  onChanged: _onChanged,
                  onSubmitted: (_) => _submitSearch(),
                  style: AppTextStyles.body,
                  decoration: InputDecoration(
                    hintText: 'Artistes, titres, albums…',
                    hintStyle: AppTextStyles.body
                        .copyWith(color: AppColors.textTertiary),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: AppColors.textTertiary, size: 20),
                    suffixIcon: _ctrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.cancel,
                                color: AppColors.textTertiary, size: 18),
                            onPressed: () {
                              _ctrl.clear();
                              context.read<MusicProvider>().clearSearch();
                              _clearSelection();
                              setState(() {});
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
          ),

          // ── Barre de sélection ────────────────────────────────────────────
          if (_isSelectionMode)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.screenHPad,
                    AppSpacing.md, AppSpacing.screenHPad, 0),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _SelectionAction(
                        icon: Icons.playlist_add_rounded,
                        label: 'Playlist',
                        onTap: _showPlaylistPickerForSelection,
                      ),
                      Container(width: 1, height: 32, color: Colors.white12),
                      _SelectionAction(
                        icon: Icons.queue_music_rounded,
                        label: 'File d\'attente',
                        onTap: _addAllToQueue,
                      ),
                      Container(width: 1, height: 32, color: Colors.white12),
                      _SelectionAction(
                        icon: Icons.download_rounded,
                        label: 'Télécharger',
                        onTap: _downloadAll,
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── États ─────────────────────────────────────────────────────────
          if (provider.isLoading)
            const SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                        color: AppColors.accent, strokeWidth: 2),
                    SizedBox(height: 16),
                    Text('Recherche en cours…',
                        style: TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            )
          else if (provider.errorMessage != null)
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.wifi_off_rounded,
                          color: AppColors.textDisabled, size: 48),
                      const SizedBox(height: AppSpacing.md),
                      Text(provider.errorMessage!,
                          style: AppTextStyles.subhead,
                          textAlign: TextAlign.center),
                      const SizedBox(height: AppSpacing.sm),
                      const Text(
                        'Démarre le backend :\ncd demus-backend && node server.js',
                        style: TextStyle(
                            color: AppColors.textTertiary, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (provider.songs.isEmpty && _ctrl.text.isNotEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Text('Aucun résultat.',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screenHPad,
                  AppSpacing.md, AppSpacing.screenHPad, AppSpacing.bottomPad),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _SearchResultTile(
                    song: provider.songs[i],
                    isSelected: _selectedIds.contains(provider.songs[i].id),
                    isSelectionMode: _isSelectionMode,
                    onToggleSelect: () => _toggleSong(provider.songs[i]),
                  ),
                  childCount: provider.songs.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Action dans la barre de sélection ────────────────────────────────────────

class _SelectionAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SelectionAction(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.accent, size: 22),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }
}

// ── Tuile résultat de recherche ───────────────────────────────────────────────

class _SearchResultTile extends StatelessWidget {
  final Song song;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onToggleSelect;
  const _SearchResultTile({
    required this.song,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onToggleSelect,
  });

  Widget _placeholder() => Container(
      width: 52,
      height: 52,
      color: AppColors.surfaceHighlight,
      child: const Icon(Icons.music_note, color: AppColors.textTertiary));

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MusicProvider>();
    final isDownloaded = provider.isDownloaded(song);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: GestureDetector(
        onTap: isSelectionMode ? onToggleSelect : null,
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              child: song.coverUrl.isNotEmpty
                  ? Image.network(
                      song.coverUrl,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(),
                    )
                  : _placeholder(),
            ),
            if (isSelectionMode)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.accent.withValues(alpha: 0.6)
                        : Colors.black38,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 26)
                      : null,
                ),
              ),
            if (!isSelectionMode && isDownloaded)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                      color: AppColors.accentGreen, shape: BoxShape.circle),
                  child: const Icon(Icons.download_done_rounded,
                      size: 11, color: Colors.black),
                ),
              ),
          ],
        ),
      ),
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.calloutMedium.copyWith(
          color: isSelected ? AppColors.accent : null,
        ),
      ),
      subtitle: Text(
        song.durationFormatted.isNotEmpty
            ? '${song.artist} · ${song.durationFormatted}'
            : song.artist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.subhead,
      ),
      trailing: isSelectionMode
          ? null
          : IconButton(
              icon: const Icon(Icons.more_vert_rounded,
                  color: AppColors.textTertiary, size: 20),
              onPressed: () => showSongOptionsMenu(context, song),
            ),
      onTap: () {
        if (isSelectionMode) {
          onToggleSelect();
          return;
        }
        provider.playSong(song, queue: provider.songs);
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const FullScreenPlayer(),
        );
      },
      onLongPress: () {
        if (!isSelectionMode) {
          onToggleSelect();
        } else {
          showSongOptionsMenu(context, song);
        }
      },
    );
  }
}
