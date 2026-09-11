# Full codebase audit — round 3

1 file changed: lib/screens/home_screen.dart

## The confirmed bug: HomeScreen keeps running in the background during play
HomeScreen navigates to GameScreen with a plain Navigator.push (see
_startGame) — not pushReplacement. That means HomeScreen is never disposed
when you start a game; it just sits underneath GameScreen, alive, for the
entire play session.

HomeScreen had a `Timer.periodic(90s, ...)` that calls `setState(() {})` to
refresh some display numbers. Flutter automatically mutes AnimationControllers
in a covered route (confirmed against Flutter's own test suite — this is
why _pulseController was never actually a problem), but a plain Timer has
no such protection. So every 90 seconds, for the whole time you're playing,
it was rebuilding the entire ~660-line HomeScreen tree in the background —
a real, periodic hitch stealing time from the game's own frame budget, for
a screen nobody can even see.

Fixed: the timer now checks `ModalRoute.of(context)?.isCurrent` before
calling setState, so it only actually rebuilds while HomeScreen is the
visible route.

## What I re-checked and ruled OUT this round (with actual evidence, not guesses)
- flutter_animate restarting the per-emoji entrance animation every frame —
  confirmed via the package's own README this is NOT the default behavior
  (there's an explicit opt-in `restartOnHotReload` flag specifically because
  restarting on every rebuild is NOT what normally happens).
- The background painter (_GameBackground / _StarfieldPainter) — confirmed
  it's gated by level, not rebuilt every frame, and its shouldRepaint is
  correctly implemented.
- Tap effects (_EffectLayer) — confirmed they run off their own separate
  ValueNotifier, not the 60fps render loop.
- LeaderboardScreen's timers — confirmed LeaderboardScreen is dead code,
  never actually navigated to anywhere in the app. Not a live issue.

## Found, but deliberately NOT touched: Impeller is disabled
android/app/src/main/AndroidManifest.xml forces the older Skia renderer
instead of Impeller. This was NOT a careless leftover — there's a real
comment explaining it was done because Impeller caused confirmed visual
corruption with LinearGradient + CustomPaint on some Android GPU/driver
combos, which is exactly what this game's background uses. Impeller would
help with shader-compile jank (a plausible cause of a hitch "at the
start"), but re-enabling it risks bringing back a worse, confirmed bug
(broken visuals, not just a stutter). Not something to flip without testing
on the actual affected device(s) first, so I left it as-is.

## The one thing I can't check from here, and genuinely might be the answer
I don't have a device or emulator in this environment, so I cannot rule out
that you're testing via `flutter run` in **debug mode**. Debug builds carry
real, unavoidable overhead — JIT compilation, enabled assertions, no
tree-shaking — that can produce exactly this kind of stepping/stuttering
regardless of how optimized the underlying code is. If you haven't already,
testing a profile or release build would be the single most informative
next step:

    flutter run --profile

or install a release APK directly on the device. If it's smooth there and
choppy only via `flutter run` debug, the remaining stepping isn't a bug in
the code at all — it's expected debug-mode cost.
