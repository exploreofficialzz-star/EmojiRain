// ─────────────────────────────────────────────────────────────────────────────
// lib/widgets/background_picker_sheet.dart
//
// Shared bottom sheet for choosing/resetting the custom game background.
// Extracted from game_screen.dart so it can also be triggered from
// HomeScreen — previously it only lived inside the in-game pause menu,
// which meant there was no way to set a background before starting a game.
// Both call sites now share this single implementation instead of two
// separate copies of the same ~150 lines.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';
import '../services/wallpaper_service.dart';

void showBackgroundPickerSheet(BuildContext context) {
  showModalBottomSheet(
    context:            context,
    isScrollControlled: true,
    backgroundColor:    Colors.transparent,
    builder: (_) => ChangeNotifierProvider.value(
      value: WallpaperService.instance,
      child: const _BackgroundPickerSheet(),
    ),
  );
}

class _BackgroundPickerSheet extends StatelessWidget {
  const _BackgroundPickerSheet();

  @override
  Widget build(BuildContext context) {
    return Consumer<WallpaperService>(
      builder: (context, wallpaper, _) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color:        Color(0xFF12122A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(top: BorderSide(color: Color(0xFF2A2A50), width: 1)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color:        Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 22),
                const Text('🖼️  Game Background', style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white,
                )),
                const SizedBox(height: 6),
                const Text(
                  'Use a photo from your gallery as the\nbackground while you play.',
                  style: TextStyle(
                    fontSize: 13, color: Color(0xFF78909C), height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                if (wallpaper.error != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFB71C1C).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFEF5350).withOpacity(0.4),
                      ),
                    ),
                    child: Row(children: [
                      const Text('⚠️', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(wallpaper.error!, style: const TextStyle(
                          fontSize: 12, color: Color(0xFFEF9A9A),
                        )),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 14),
                ],

                // Choose Photo
                GestureDetector(
                  onTap: wallpaper.busy ? null : () async {
                    final ok = await wallpaper.pickFromGallery();
                    if (ok && context.mounted) Navigator.of(context).pop();
                  },
                  child: Container(
                    width: double.infinity, height: 52,
                    decoration: BoxDecoration(
                      gradient:     AppColors.primaryBtnGradient,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: wallpaper.busy
                          ? const SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.black,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('📷', style: TextStyle(fontSize: 18)),
                                SizedBox(width: 8),
                                Text('Choose Photo', style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w800,
                                  color: Colors.black,
                                )),
                              ],
                            ),
                    ),
                  ),
                ),

                // Reset to Default — only shown when a custom wallpaper is active
                if (wallpaper.hasCustomWallpaper) ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: wallpaper.busy ? null : () async {
                      await wallpaper.resetToDefault();
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    child: Container(
                      width: double.infinity, height: 52,
                      decoration: BoxDecoration(
                        color:        const Color(0xFF1A1A35),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('🔄', style: TextStyle(fontSize: 16)),
                          SizedBox(width: 8),
                          Text('Reset to Default', style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700,
                            color: Colors.white70,
                          )),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
