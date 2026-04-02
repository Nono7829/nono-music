import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../services/music_provider.dart';
import '../models/song.dart';
import '../widgets/full_screen_player.dart';
import '../widgets/song_options_menu.dart';

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
    setState(() {}); // Rebuild for clear button visibility
  }

  void _submitSearch() {
    final q = _ctrl.text.trim();
    if (q.isEmpty) return;
    _focus.unfocus();
    context.read<MusicProvider>().searchYouTube(q);
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
                  left: AppSpacing.screenHPad,
                  bottom: AppSpacing.md),
              title: Text('Search', style: AppTextStyles.title1),
              background: Container(color: AppColors.background),
            ),
          ),

          // ── Search field ──────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenHPad, AppSpacing.sm,
                  AppSpacing.screenHPad, 0),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: TextField(
                  controller: _ctrl,
                  focusNode: _focus,
                  onChanged: _onChanged,
                  onSubmitted: (_) => _submitSearch(),
                  style: AppTextStyles.body,
                  decoration: InputDecoration(
                    hintText: 'Artists, songs, albums…',
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
                              setState(() {});
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
          ),

          // ── States ────────────────────────────────────────────────────────
          if (provider.isLoading)
            const SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                        color: AppColors.accent, strokeWidth: 2),
                    SizedBox(height: 16),
                    Text('Searching…',
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
                        'Start backend:\ncd demus-backend && node server.js',
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
                child: Text('No results.',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenHPad, AppSpacing.md,
                  AppSpacing.screenHPad, AppSpacing.bottomPad),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) =>
                      _SearchResultTile(song: provider.songs[i]),
                  childCount: provider.songs.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  final Song song;
  const _SearchResultTile({required this.song});

  Widget _placeholder() => Container(
        width: 52,
        height: 52,
        color: AppColors.surfaceHighlight,
        child: const Icon(Icons.music_note, color: AppColors.textTertiary));

  @override
  Widget build(BuildContext context) {
    final provider     = context.watch<MusicProvider>();
    final isDownloaded = provider.isDownloaded(song);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: Stack(
        children: [
          ClipRRect(
            borderRadius:
                BorderRadius.circular(AppSpacing.radiusSm),
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
          if (isDownloaded)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                    color: AppColors.accentGreen,
                    shape: BoxShape.circle),
                child: const Icon(Icons.download_done_rounded,
                    size: 11, color: Colors.black),
              ),
            ),
        ],
      ),
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.calloutMedium,
      ),
      subtitle: Text(
        song.durationFormatted.isNotEmpty
            ? '${song.artist} · ${song.durationFormatted}'
            : song.artist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.subhead,
      ),
      trailing: IconButton(
        icon: const Icon(Icons.more_vert_rounded,
            color: AppColors.textTertiary, size: 20),
        onPressed: () => showSongOptionsMenu(context, song),
      ),
      onTap: () {
        provider.playSong(song, queue: provider.songs);
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const FullScreenPlayer(),
        );
      },
      onLongPress: () => showSongOptionsMenu(context, song),
    );
  }
}