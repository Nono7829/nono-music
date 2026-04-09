import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/constants/app_spacing.dart';
import '../services/music_provider.dart';

class SearchScreen extends StatefulWidget {
  final TextEditingController? externalController;
  const SearchScreen({super.key, this.externalController});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = widget.externalController ?? TextEditingController();
  }

  void _onSearchSubmitted() {
    final q = _ctrl.text.trim();
    if (q.isNotEmpty) {
      context.read<MusicProvider>().searchUnified(q);
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MusicProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.background,
            title: const Text('Recherche', style: AppTextStyles.title1),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: TextField(
                controller: _ctrl,
                style: AppTextStyles.body,
                onSubmitted: (_) => _onSearchSubmitted(),
                decoration: InputDecoration(
                  hintText: 'Artistes, titres, albums...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _ctrl.text.isNotEmpty 
                    ? IconButton(icon: const Icon(Icons.clear), onPressed: () => _ctrl.clear()) 
                    : null,
                  filled: true,
                  fillColor: AppColors.surfaceElevated,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ),
          ),
          if (provider.isLoading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: AppColors.accent)))
          else if (provider.errorMessage != null)
            SliverFillRemaining(child: Center(child: Text(provider.errorMessage!, style: AppTextStyles.subhead)))
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final song = provider.songs[index];
                    return ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.network(song.coverUrl, width: 50, height: 50, fit: BoxFit.cover),
                      ),
                      title: Text(song.title, style: AppTextStyles.calloutMedium),
                      subtitle: Text(song.artist, style: AppTextStyles.subhead),
                      onTap: () => provider.playSong(song),
                    );
                  },
                  childCount: provider.songs.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
