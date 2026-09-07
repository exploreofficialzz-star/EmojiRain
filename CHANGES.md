# Game screen audit — round 2: stepped/hanging motion

1 file touched: `lib/providers/game_provider.dart` (already contains the
round-1 spawn-cap fix too — this is the full current file, drop it in as-is).

## The bug
`GameProvider.emojis` (the getter GameScreen's render loop reads every
single frame to know where to paint each emoji) was doing:

    List<EmojiItem> get emojis => List.unmodifiable(_emojis);

`List.unmodifiable()` doesn't just wrap the list — it walks it and copies
every element into a brand-new list. GameScreen's AnimatedBuilder calls
this getter once per rendered frame (60+ times a second on most phones,
more on 90/120Hz screens), so that copy was happening on every frame,
whether 2 emojis were on screen or 40.

That's exactly the shape of what you described: at the very start there
are only a couple of emojis, so the copy is tiny but still there — worth
noting since two separate startup costs (banner ad load, background music
init) are already deliberately delayed by 1s/300ms in this codebase so
they don't collide with the opening frames; this copy wasn't one of the
things caught by that pass. As the level climbs, more emojis spawn (up to
40 on screen), the list being copied every frame gets bigger, and the copy
cost climbs with it — more work stealing time from the same 16ms frame
budget, which is what shows up as movement "stepping" instead of gliding.

## The fix
Swapped it for `UnmodifiableListView(_emojis)` (from `dart:collection`),
which wraps the existing list instead of copying it — same "can't be
mutated from outside" guarantee, no per-frame allocation. Confirmed safe:
the only place this list is read (`_EmojiLayer.build`) iterates it once,
synchronously, and never modifies `_emojis` while doing so.

## Honest caveat
I can't run the game on a device from here, so I can't fully rule out a
second, separate contributor to the "at the beginning" hang specifically —
things like first-time shader compilation for blur/shadow effects can
cause a one-off hitch the first time they're painted in a session, and
that's not something a code read can confirm or fix. If the hang at the
very start is still there after this fix, that's the next thing worth
chasing — profiling it on an actual device (Flutter DevTools' Performance
view) would show exactly where those frames are going.
