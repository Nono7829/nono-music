import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/music_provider.dart';
import '../main.dart';

class ImportPlaylistScreen extends StatefulWidget {
  const ImportPlaylistScreen({super.key});

  @override
  State<ImportPlaylistScreen> createState() => _ImportPlaylistScreenState();
}

class _ImportPlaylistScreenState extends State<ImportPlaylistScreen> {
  final _urlCtrl  = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _isLoading = false;
  String? _error;
  List<_TrackPreview>? _preview;

  @override
  void dispose() {
    _urlCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  bool get _isYouTube =>
      _urlCtrl.text.contains('youtube.com/playlist') ||
      _urlCtrl.text.contains('music.youtube.com');

  bool get _isSpotify => _urlCtrl.text.contains('open.spotify.com/playlist');

  Future<void> _fetchPreview() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;
    if (!_isYouTube && !_isSpotify) {
      setState(() => _error = 'URL non reconnue. Utilise une URL Spotify ou YouTube Music.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error     = null;
      _preview   = null;
    });

    try {
      // Pour YouTube, on utilise yt-dlp via le backend
      // Pour Spotify, on utilise l'API Spotify
      // Cette version basique extrait les infos via le backend
      final provider = context.read<MusicProvider>();
      final tracks   = await provider.importPlaylistFromUrl(url);

      setState(() {
        _preview = tracks
            .map((s) => _TrackPreview(s.title, s.artist, s.coverUrl))
            .toList();
        if (_nameCtrl.text.isEmpty && tracks.isNotEmpty) {
          _nameCtrl.text = 'Playlist importée';
        }
      });
    } catch (e) {
      setState(() => _error = 'Erreur lors de l\'import : $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _importPlaylist() async {
    if (_preview == null || _preview!.isEmpty) return;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Donne un nom à ta playlist.');
      return;
    }

    final provider = context.read<MusicProvider>();
    provider.createPlaylist(name);

    scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(
      backgroundColor: const Color(0xFF30D158),
      content: Text('✅ Playlist "$name" importée avec ${_preview!.length} titres !',
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
      behavior: SnackBarBehavior.floating,
    ));

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFFFF2D55)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Importer une playlist',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sources supportées
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                children: [
                  _SourceRow(
                    color: Color(0xFF1DB954),
                    icon: Icons.music_note_rounded,
                    label: 'Spotify',
                    hint: 'open.spotify.com/playlist/…',
                  ),
                  Divider(color: Colors.white12, height: 20),
                  _SourceRow(
                    color: Color(0xFFFF0000),
                    icon: Icons.play_circle_rounded,
                    label: 'YouTube Music',
                    hint: 'youtube.com/playlist?list=…',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text('URL de la playlist',
                style: TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Colle l\'URL ici…',
                      hintStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: const Color(0xFF1C1C1E),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.paste_rounded,
                            color: Colors.grey, size: 20),
                        onPressed: () async {
                          final data =
                              await Clipboard.getData(Clipboard.kTextPlain);
                          if (data?.text != null) {
                            _urlCtrl.text = data!.text!;
                            setState(() {});
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed:
                    (_urlCtrl.text.isEmpty || _isLoading) ? null : _fetchPreview,
                icon: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.search_rounded),
                label: Text(_isLoading
                    ? 'Chargement…'
                    : 'Prévisualiser'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF2D55),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: const TextStyle(color: Color(0xFFFF453A), fontSize: 13)),
            ],

            if (_preview != null && _preview!.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text('Nom de la playlist',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 8),
              TextField(
                controller: _nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF1C1C1E),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              Text('${_preview!.length} titres détectés',
                  style: const TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 8),
              ...(_preview!.take(5).map((t) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: t.coverUrl.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.network(t.coverUrl,
                                width: 40, height: 40, fit: BoxFit.cover))
                        : Container(
                            width: 40,
                            height: 40,
                            color: const Color(0xFF2C2C2E),
                            child: const Icon(Icons.music_note,
                                color: Colors.white30, size: 20)),
                    title: Text(t.title,
                        style: const TextStyle(fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    subtitle: Text(t.artist,
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 11)),
                  ))),
              if (_preview!.length > 5)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('… et ${_preview!.length - 5} autres',
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 12)),
                ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _importPlaylist,
                  icon: const Icon(Icons.download_done_rounded),
                  label: const Text('Importer la playlist',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF30D158),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TrackPreview {
  final String title, artist, coverUrl;
  _TrackPreview(this.title, this.artist, this.coverUrl);
}

class _SourceRow extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label, hint;
  const _SourceRow(
      {required this.color,
      required this.icon,
      required this.label,
      required this.hint});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14)),
            Text(hint,
                style:
                    const TextStyle(color: Colors.grey, fontSize: 11)),
          ],
        ),
      ],
    );
  }
}