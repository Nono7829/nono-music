import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/music_provider.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';

void showQueueSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF1C1C1E),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _QueueSheet(),
  );
}

class _QueueSheet extends StatelessWidget {
  const _QueueSheet();

  @override
  Widget build(BuildContext context) {
    final provider     = context.watch<MusicProvider>();
    final queue        = provider.queue;
    final currentIndex = provider.currentQueueIndex;

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (_, ctrl) => Column(
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('File d\'attente',
                    style: AppTextStyles.headline),
                Text(
                  '${queue.length} titre${queue.length != 1 ? 's' : ''}',
                  style: AppTextStyles.subhead,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(color: Colors.white12, height: 1),
          Expanded(
            child: queue.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.queue_music_rounded,
                            color: Colors.white12, size: 48),
                        SizedBox(height: 12),
                        Text('La file d\'attente est vide.',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: ctrl,
                    itemCount: queue.length,
                    itemBuilder: (_, i) {
                      final song      = queue[i];
                      final isCurrent = i == currentIndex;
                      final isPlayed  = i < currentIndex;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 2),
                        leading: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: ColorFiltered(
                                colorFilter: isPlayed
                                    ? const ColorFilter.matrix([
                                        0.2126, 0.7152, 0.0722, 0, 0,
                                        0.2126, 0.7152, 0.0722, 0, 0,
                                        0.2126, 0.7152, 0.0722, 0, 0,
                                        0,      0,      0,      1, 0,
                                      ])
                                    : const ColorFilter.mode(
                                        Colors.transparent,
                                        BlendMode.multiply),
                                child: Image.network(
                                  song.coverUrl,
                                  width: 44,
                                  height: 44,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 44,
                                    height: 44,
                                    color: AppColors.surfaceHighlight,
                                    child: const Icon(Icons.music_note,
                                        color: Colors.white30),
                                  ),
                                ),
                              ),
                            ),
                            if (isCurrent)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black45,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(
                                    Icons.equalizer_rounded,
                                    color: AppColors.accent,
                                    size: 20,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        title: Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isCurrent
                                ? AppColors.accent
                                : isPlayed
                                    ? Colors.white38
                                    : Colors.white,
                            fontWeight: isCurrent
                                ? FontWeight.w700
                                : FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          song.artist,
                          style: TextStyle(
                            color: isPlayed ? Colors.white24 : Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        trailing: isCurrent
                            ? null
                            : Text(
                                song.durationFormatted,
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 12),
                              ),
                        onTap: () {
                          provider.playSongFromQueue(i);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}