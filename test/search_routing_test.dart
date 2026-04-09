// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:nono_music/models/song.dart';

// ── Tests: Search routing & deduplication logic ───────────────────────────────
//
// These tests validate the search routing logic that would be applied when
// consuming results from /unified-search, including:
//   - Source priority (Spotify before YouTube)
//   - Deduplication by normalized title+artist fingerprint
//   - Fallback parsing when unified-search returns YouTube-only results
//   - Song.fromJson handles both source formats

void main() {
  group('Song.fromJson — source formats', () {
    test('parses YouTube search result', () {
      final json = {
        'id':        'yt_vid_id_11',
        'title':     'Blinding Lights',
        'artist':    'The Weeknd - Topic',
        'duration':  200,
        'thumbnail': 'https://i.ytimg.com/vi/yt_vid_id_11/hqdefault.jpg',
        'source':    'youtube',
      };
      final song = Song.fromJson(json);
      expect(song.id,    'yt_vid_id_11');
      expect(song.title, 'Blinding Lights');
    });

    test('parses Spotify-enriched (unified) result', () {
      final json = {
        'id':        'sp_yt_vid_1a',
        'title':     'Blinding Lights',
        'artist':    'The Weeknd',
        'duration':  200,
        'thumbnail': 'https://i.scdn.co/image/abc123',
        'source':    'spotify',
      };
      final song = Song.fromJson(json);
      expect(song.id,       'sp_yt_vid_1a');
      expect(song.coverUrl, 'https://i.scdn.co/image/abc123');
    });

    test('handles missing thumbnail gracefully', () {
      final json = {
        'id':     'ab12345678a',
        'title':  'Song',
        'artist': 'Artist',
      };
      final song = Song.fromJson(json);
      expect(song.coverUrl, '');
    });
  });

  group('Search result deduplication logic', () {
    // Replicate the server-side normalization logic in Dart for testing
    String normalize(String s) {
      return s
          .toLowerCase()
          .replaceAll(RegExp(r'\(.*?\)'), '')
          .replaceAll(RegExp(r'\[.*?\]'), '')
          .replaceAll(RegExp(r'[^\w\s]'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
    }

    String fingerprint(String title, String artist) {
      return '${normalize(title)}|${normalize(artist)}';
    }

    List<Map<String, dynamic>> dedup(List<Map<String, dynamic>> items) {
      final seen = <String>{};
      final result = <Map<String, dynamic>>[];
      for (final item in items) {
        final fp = fingerprint(
          item['title'] as String,
          item['artist'] as String,
        );
        if (!seen.contains(fp)) {
          seen.add(fp);
          result.add(item);
        }
      }
      return result;
    }

    test('deduplicates identical title+artist from two sources', () {
      final items = [
        {'title': 'Blinding Lights', 'artist': 'The Weeknd', 'source': 'spotify', 'id': 'id1'},
        {'title': 'Blinding Lights', 'artist': 'The Weeknd', 'source': 'youtube', 'id': 'id2'},
      ];
      final result = dedup(items);
      expect(result.length, 1);
      expect(result.first['source'], 'spotify'); // first one wins (Spotify priority)
    });

    test('deduplicates when titles have parentheticals', () {
      final items = [
        {'title': 'Bad Guy (Official Audio)', 'artist': 'Billie Eilish', 'source': 'spotify', 'id': 'id1'},
        {'title': 'Bad Guy',                  'artist': 'Billie Eilish', 'source': 'youtube', 'id': 'id2'},
      ];
      final result = dedup(items);
      expect(result.length, 1);
    });

    test('keeps distinct songs (different title)', () {
      final items = [
        {'title': 'Song A', 'artist': 'Artist', 'source': 'spotify', 'id': 'id1'},
        {'title': 'Song B', 'artist': 'Artist', 'source': 'youtube', 'id': 'id2'},
      ];
      final result = dedup(items);
      expect(result.length, 2);
    });

    test('keeps distinct songs (same title, different artist)', () {
      final items = [
        {'title': 'Hello', 'artist': 'Adele',  'source': 'spotify', 'id': 'id1'},
        {'title': 'Hello', 'artist': 'Lionel Richie', 'source': 'youtube', 'id': 'id2'},
      ];
      final result = dedup(items);
      expect(result.length, 2);
    });

    test('Spotify results ranked before YouTube', () {
      // When Spotify results come first, they should appear first in output
      final items = [
        {'title': 'Track 1', 'artist': 'A1', 'source': 'spotify', 'id': 'id1'},
        {'title': 'Track 2', 'artist': 'A2', 'source': 'youtube', 'id': 'id2'},
        {'title': 'Track 3', 'artist': 'A3', 'source': 'spotify', 'id': 'id3'},
      ];
      // Simulate unified-search ordering: spotify first
      final spotifyItems = items.where((i) => i['source'] == 'spotify').toList();
      final youtubeItems = items.where((i) => i['source'] == 'youtube').toList();
      final merged = [...spotifyItems, ...youtubeItems];
      final result = dedup(merged);

      expect(result.length, 3);
      expect(result.first['source'], 'spotify');
      expect(result[1]['source'],    'spotify');
      expect(result.last['source'],  'youtube');
    });
  });

  group('JSON roundtrip', () {
    test('Song serialized and deserialized matches original', () {
      final original = Song(
        id:       'roundtrip000',
        title:    'Test',
        artist:   'Artist',
        coverUrl: 'https://cover.url/img.jpg',
        duration: 240,
      );

      final json = jsonDecode(jsonEncode({
        'id':        original.id,
        'title':     original.title,
        'artist':    original.artist,
        'thumbnail': original.coverUrl,
        'duration':  original.duration,
      })) as Map<String, dynamic>;

      final restored = Song.fromJson(json);
      expect(restored.id,       original.id);
      expect(restored.title,    original.title);
      expect(restored.artist,   original.artist);
      expect(restored.coverUrl, original.coverUrl);
      expect(restored.duration, original.duration);
    });
  });
}
