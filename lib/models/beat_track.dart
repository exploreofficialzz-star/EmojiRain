/// A built-in beat track available to all players in Beat Mode.
class BeatTrack {
  final String id;
  final String name;
  final String genre;
  final int bpm;
  final String assetPath;
  final String emoji; // decorative genre emoji for cards

  const BeatTrack({
    required this.id,
    required this.name,
    required this.genre,
    required this.bpm,
    required this.assetPath,
    required this.emoji,
  });
}
