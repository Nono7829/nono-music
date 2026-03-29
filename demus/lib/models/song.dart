class Song {
  final String title;
  final String artist;
  final String coverUrl;

  const Song({
    required this.title,
    required this.artist,
    required this.coverUrl,
  });
}

class Playlist {
  final String name;
  List<Song> songs;

  Playlist({required this.name, this.songs = const []});

  void addSong(Song song) {
    songs.add(song);
  }
}
