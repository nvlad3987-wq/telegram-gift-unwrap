# Gift Unwrap → Telegram-iOS

Checked against `TelegramMessenger/Telegram-iOS` at `fb0e62b` (22 Oct 2026).

## What it does in Telegram

The first time an incoming **collectible** gift message (`TelegramMediaAction.starGiftUnique`) is
opened, `GiftUnwrapScreen` plays instead of the gift sheet:

1. the sphere lifts from the lower part of the chat into the middle of the screen (set
   `sourcePoint` to the message bubble's centre to lift it out of the exact message); the hint **Pull the ribbon to unwrap** appears and a finger shows the pull;
2. you pull the ribbon and the glass breaks;
3. the gift's real backdrop (`innerColor` / `outerColor` / `patternColor`) floods the screen and its
   real symbol (the pattern sticker) fills it in an even pattern around the model (the animated
   model sticker);
4. the sheet shows the title, `#number`, Model / Symbol / Backdrop with rarity and Availability;
5. **Show on Profile** (`Gift_View_Display`) calls
   `engine.payments.updateStarGiftAddedToProfile(…, added: true)` and shows Telegram's own sticker
   toast with **View** (opens your profile's gifts). Closing keeps the gift private, with
   Telegram's own caption `Gift_View_HiddenInfo`; it can be shown later from `GiftViewScreen`.

Later opens of the same message go straight to `GiftViewScreen` (remembered in `UserDefaults`).

## Install (one command)

```sh
python3 TelegramIntegration/ios/install.py /path/to/Telegram-iOS
```

The script is idempotent. It:

| Step | File |
| --- | --- |
| Adds the module | `submodules/TelegramUI/Components/Gifts/GiftUnwrapScreen/` (`BUILD`, `Sources/GiftUnwrapScreen.swift`, `Sources/Kit/*.swift` — the same Kit as the demo app) |
| Adds the dependency | `submodules/TelegramUI/BUILD` → `//submodules/TelegramUI/Components/Gifts/GiftUnwrapScreen` |
| Hooks the chat | `submodules/TelegramUI/Sources/ChatController.swift`, `case .starGift, .starGiftUnique:` — `import GiftUnwrapScreen` + 14 lines before `makeGiftViewScreen(...)` |

Then build as usual (`Make.py build … --configuration=debug_sim_arm64`).

## Module dependencies

`AsyncDisplayKit`, `Display`, `SwiftSignalKit`, `TelegramCore`, `AccountContext`,
`TelegramPresentationData`, `UndoUI`, `TextFormat`, `EmojiTextAttachmentView`. The Kit itself uses
only UIKit, SceneKit (as `PremiumStarComponent` does) and AVFoundation.

## Where things map

| Concept | Telegram |
| --- | --- |
| Gift model | `.model(name, file, rarity, _)` → `InlineStickerItemLayer` (animated) |
| Symbol | `.pattern(name, file, rarity)` → `InlineStickerItemLayer` tinted with `patternColor` |
| Backdrop | `.backdrop(name, _, innerColor, outerColor, patternColor, textColor, rarity)` |
| Rarity | `.permille(x)` → `x / 10 %`; `.rare/.epic/.legendary/.uncommon` → the word |
| Number | `StarGift.UniqueGift.number` |
| Availability | `availability.issued / total` → `Gift_Unique_Issued` |

## Not done in Telegram (only in the demo)

The orbit of gifts around the avatar and the header recolor are in the demo app. Telegram already
has its own version of both: pinned gifts float around the avatar (`PeerInfoGiftsCoverComponent`)
and a worn collectible recolors the header (`PeerInfoCoverComponent`). The adapter saves the gift to
the profile and offers **View**. Pinning it (`ProfileGiftsContext.updateStarGiftPinnedToTop`) is a
one-line follow-up if the team wants it.

## Status

The Kit is the same code as the demo app, which builds and runs in Xcode 27 (iPhone simulator,
iOS 27) with the whole flow played through. `GiftUnwrapScreen.swift` uses Telegram's own types, so
it compiles only inside Telegram-iOS and has not been built there yet; expect the first
`Make.py build` to point at small fixes, which stay inside `GiftUnwrapScreen/`.
