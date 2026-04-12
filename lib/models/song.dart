class Song {
  final String id;
  final String title;
  final String artist;
  final String coverUrl;
  final int duration;

  const Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.coverUrl,
    this.duration = 0,
  });

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      id:       _str(json['id']),
      title:    _str(json['title'],     fallback: 'Titre inconnu'),
      artist:   _str(json['artist'],    fallback: 'Artiste inconnu'),
      coverUrl: _str(json['thumbnail'] ?? json['coverUrl']),
      duration: (json['duration'] as num?)?.toInt() ?? 0,
    );
  }

  static String _str(dynamic v, {String fallback = ''}) {
    if (v == null) return fallback;
    final s = v.toString().trim();
    return s.isEmpty ? fallback : s;
  }

  String get durationFormatted {
    if (duration <= 0) return '';
    final m = duration ~/ 60;
    final s = duration % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

class Playlist {
  final String name;
  List<Song> songs;

  Playlist({required this.name, List<Song>? songs}) : songs = songs ?? [];

  void addSong(Song song) => songs.add(song);
}