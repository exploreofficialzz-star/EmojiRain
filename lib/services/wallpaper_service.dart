// ─────────────────────────────────────────────────────────────────────────────
// lib/services/wallpaper_service.dart
//
// Lets the player pick a photo from their gallery to use as the falling-
// emoji game background instead of the default starfield gradient.
//
// DESIGN NOTES:
//   • image_picker's returned path is a TEMPORARY cache file — not
//     guaranteed to still exist after the app restarts or the OS clears
//     cache. The picked file is copied into the app's own persistent
//     documents directory (getApplicationDocumentsDirectory()) immediately,
//     and it's THAT stable path which gets saved/reused, never the
//     picker's original temp path.
//   • Only ONE custom wallpaper is kept at a time — picking a new one
//     deletes the previous file first, so repeated changes don't silently
//     accumulate orphaned image files on the player's device.
//   • init() validates the saved path still points to a real file before
//     trusting it (defensive: handles the OS clearing app storage
//     partially, or the file being removed some other way).
//   • All picker/file operations are wrapped in try/catch — gallery access
//     can fail for reasons outside our control (permission denied, no
//     gallery app, I/O error) and none of that should crash the app.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WallpaperService extends ChangeNotifier {
  WallpaperService._();
  static final WallpaperService instance = WallpaperService._();

  static const String _pathKey = 'custom_wallpaper_path';
  static const String _subDir  = 'wallpaper';

  String? _customPath;
  bool    _busy  = false;
  String? _error;

  String? get customPath        => _customPath;
  bool    get hasCustomWallpaper => _customPath != null;
  bool    get busy              => _busy;
  String? get error             => _error;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_pathKey);

    if (saved != null && File(saved).existsSync()) {
      _customPath = saved;
    } else if (saved != null) {
      // Stale reference (file missing) — clean up so future checks are fast.
      await prefs.remove(_pathKey);
    }
    notifyListeners();
  }

  /// Opens the gallery picker, copies the chosen image into persistent
  /// storage, and activates it as the game background. Returns true on
  /// success, false if the user cancelled or something went wrong (check
  /// [error] for a message in the failure case).
  Future<bool> pickFromGallery() async {
    _error = null;
    _busy  = true;
    notifyListeners();

    try {
      final picked = await ImagePicker().pickImage(
        source:      ImageSource.gallery,
        imageQuality: 85,   // background only — no need for full-res originals
      );

      if (picked == null) {
        _busy = false;
        notifyListeners();
        return false; // user cancelled — not an error
      }

      final docsDir  = await getApplicationDocumentsDirectory();
      final wallDir  = Directory('${docsDir.path}/$_subDir');
      if (!await wallDir.exists()) {
        await wallDir.create(recursive: true);
      }

      // Remove any previous custom wallpaper file before saving the new
      // one, so changing backgrounds repeatedly doesn't leave orphaned
      // images taking up space on the player's device.
      await _deleteExistingFile();

      final ext = _safeExtension(picked.path);
      final destPath = '${wallDir.path}/background$ext';
      await File(picked.path).copy(destPath);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pathKey, destPath);

      _customPath = destPath;
      _busy       = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Could not set background. Please try again.';
      _busy  = false;
      notifyListeners();
      return false;
    }
  }

  /// Clears the custom wallpaper and returns to the default starfield.
  Future<void> resetToDefault() async {
    _busy = true;
    notifyListeners();

    try {
      await _deleteExistingFile();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pathKey);
      _customPath = null;
    } catch (_) {
      _error = 'Could not reset background. Please try again.';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> _deleteExistingFile() async {
    if (_customPath == null) return;
    try {
      final f = File(_customPath!);
      if (await f.exists()) await f.delete();
    } catch (_) {
      // Non-fatal — an orphaned file is a minor storage cost, not worth
      // failing the whole operation over.
    }
  }

  // Keep only a small, known-safe set of extensions; default to .jpg for
  // anything unrecognized (covers HEIC and other formats image_picker may
  // hand back depending on device/OS, which Image.file/Flutter's image
  // decoder can still typically read once copied locally).
  String _safeExtension(String sourcePath) {
    final lower = sourcePath.toLowerCase();
    if (lower.endsWith('.png'))  return '.png';
    if (lower.endsWith('.webp')) return '.webp';
    if (lower.endsWith('.jpeg')) return '.jpeg';
    return '.jpg';
  }
}
