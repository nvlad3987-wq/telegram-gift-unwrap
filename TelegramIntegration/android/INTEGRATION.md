# Gift Unwrap → Telegram-Android

Checked against `DrKLO/Telegram` at `3de37c8` (25 Oct 2026).

## What it does in Telegram

The first time an incoming collectible gift message (`TLRPC.TL_messageActionStarGiftUnique`) is
tapped, `GiftUnwrapOverlay` plays over the whole window instead of `StarGiftSheet`:

1. the sphere lifts out of the tapped cell (`getLocationInWindow` centre) into the middle of the
   screen; the hint **Pull the ribbon to unwrap** appears and a finger shows the pull;
2. you pull the ribbon and the glass breaks into shards;
3. the gift's backdrop (`center_color` / `edge_color` / `pattern_color`) floods the screen and the
   real symbol (`AnimatedEmojiDrawable.SwapAnimatedEmojiDrawable`, like `StarGiftSheet`) fills it
   in an even pattern around the real model (`ImageReceiver` + `StarsIntroActivity.setGiftImage`);
4. the sheet shows the title, `#num`, Model / Symbol / Backdrop with rarity, Availability and From;
5. **Show on Profile** sends `TL_stars.saveStarGift` and shows the same bulletin `StarGiftSheet`
   shows (`Gift2MadePublicTitle`, with a link to your profile gifts). Closing keeps the gift
   private ("Only you can see this gift for now."); it can be shown later from `StarGiftSheet`.

Later taps on the same message open `StarGiftSheet` as before.

## Install (one command)

```sh
python install.py C:\path\to\Telegram
```

| Step | File |
| --- | --- |
| Library | `TMessagesProj/src/main/java/com/designers/giftunwrap/*.java` (same code as the demo) |
| Adapter | `TMessagesProj/src/main/java/org/telegram/ui/Gifts/GiftUnwrapOverlay.java` |
| Hook | `org/telegram/ui/Cells/ChatActionCell.java` — 11 lines before `new StarGiftSheet(…)` in the `TL_messageActionStarGiftUnique` branch |

No Gradle changes: everything is plain Java in the app module.

## Status

- The library and the demo app build in Android Studio (AGP 8.7, compileSdk 35, minSdk 24); the
  debug APK installs on any Android 7+ phone.
- `FlowRenderTest` (in the demo) plays the whole flow on the real views with real touches —
  tap the gift message, wait through the hint, pull the ribbon, break the glass, tap **Show on Profile** — and renders every frame with
  Android's own graphics stack (Robolectric native graphics). It asserts that a flick past the
  end breaks the glass and that the profile opens; the frames are the Android video.
- The adapter (`GiftUnwrapOverlay`) uses Telegram's own classes, so it compiles only inside the
  Telegram project; the first Gradle build there will show whether a name has moved.
