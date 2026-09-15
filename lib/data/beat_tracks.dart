import '../models/beat_track.dart';

/// Static registry of the 5 free built-in tracks shipped with the app.
///
/// Audio files must be placed at assets/audio/beats/ — they are not bundled
/// in the repository (add your own royalty-free instrumentals matching each
/// genre and BPM before building). The asset path is declared in pubspec.yaml.
class BuiltInTracks {
  const BuiltInTracks._();

  static const List<BeatTrack> all = [
    BeatTrack(
      id:        'afrobeats_96',
      name:      'Afrobeats Groove',
      genre:     'Afrobeats',
      bpm:       96,
      assetPath: 'assets/audio/beats/afrobeats_96bpm.mp3',
      emoji:     '🎺',
    ),
    BeatTrack(
      id:        'amapiano_104',
      name:      'Amapiano Log',
      genre:     'Amapiano',
      bpm:       104,
      assetPath: 'assets/audio/beats/amapiano_104bpm.mp3',
      emoji:     '🎹',
    ),
    BeatTrack(
      id:        'afropop_110',
      name:      'Afropop Bounce',
      genre:     'Afropop',
      bpm:       110,
      assetPath: 'assets/audio/beats/afropop_110bpm.mp3',
      emoji:     '🎵',
    ),
    BeatTrack(
      id:        'highlife_120',
      name:      'Highlife Classic',
      genre:     'Highlife',
      bpm:       120,
      assetPath: 'assets/audio/beats/highlife_120bpm.mp3',
      emoji:     '🎷',
    ),
    BeatTrack(
      id:        'afrodrill_140',
      name:      'Afro Drill',
      genre:     'Afro Drill',
      bpm:       140,
      assetPath: 'assets/audio/beats/afrodrill_140bpm.mp3',
      emoji:     '🥁',
    ),
  ];

  /// Returns the BPM from [all] that is numerically closest to [bpm].
  static int closestBpm(double bpm) {
    return all
        .map((t) => t.bpm)
        .reduce((a, b) => (a - bpm).abs() < (b - bpm).abs() ? a : b);
  }

  /// Returns the track whose BPM is closest to [bpm].
  static BeatTrack closestTrack(double bpm) {
    return all.reduce(
      (a, b) => (a.bpm - bpm).abs() < (b.bpm - bpm).abs() ? a : b,
    );
  }
}
