# Game screen audit — changed files

4 files touched, all bug/robustness fixes (no visual or gameplay changes).
Drop these into your `lib/` folder, overwriting the originals.

## lib/models/emoji_item.dart
`EmojiItem.id` was `DateTime.now().microsecondsSinceEpoch + rand.nextInt(9999)`.
A single spawn tick can create up to 6 emojis synchronously (level 12+),
and real Android clocks are often coarser than true microseconds — so two
emojis from the same burst could land on the same id. Duplicate ids mean
duplicate ValueKeys in the falling-emoji Stack, which Flutter can't
reconcile correctly (an emoji can render at a stale position or steal a
tap meant for another one). Replaced with a simple monotonic counter —
can't ever collide.

## lib/widgets/tap_effect_widget.dart
Same fix, same reasoning, for `TapEffect.id` (was timestamp + rounded x).

## lib/providers/game_provider.dart
`_maybeSpawn()` checked the `maxEmojisOnScreen` cap once, then could add up
to 6 emojis in one burst at level 12+ — so the actual on-screen count could
spike ~5 past the intended ceiling right when the game is already hardest.
`trySpawn()` now re-checks the cap before each individual spawn in the
burst. Same spawn odds/level gates as before, but the cap now actually
holds.

## lib/widgets/score_hud.dart
The session-coin counter was wrapped in a `ListenableBuilder` on
`CoinService.instance`, but it only ever displays `game.sessionCoins`
(GameProvider) — a value that has nothing to do with the coin service.
That's an unnecessary rebuild dependency on unrelated wallet activity
(spending on a power-up, etc.). Removed; the existing Selector in
game_screen.dart already scopes this correctly.
