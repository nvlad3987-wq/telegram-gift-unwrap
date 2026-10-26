# Gift Unwrap: a concept for Telegram collectible gifts

[Русская версия](README.ru.md)

A new collectible arrives in the chat as an ordinary gift message, but its preview is a small
glass sphere tied with a ribbon in the gift's colours. Tap the message: the sphere lifts into the
middle of the screen and a hint appears, **Pull the ribbon to unwrap**. A finger shows the
gesture once: press the ribbon tab and pull it down. Pull it yourself and the glass stretches,
trembles, cracks and bursts. The gift's own backdrop floods the screen, its symbol fills the whole
field in an even pattern that pops in from the gift outwards, and the regular Telegram gift sheet
rises with the real attributes and their rarity.

- **Show on Profile** makes the gift public. It flies to your profile, joins the ring of
  collectibles orbiting your avatar like Saturn's rings, and the profile header takes on its
  backdrop and symbol. Telegram's own toast confirms it.
- **Keep Private** is what happens when you just close the sheet. The gift stays yours, but only
  you can see it ("Only you can see this gift for now"). You can show it on your profile later
  from the gift's page.

The effect is not tied to one gift. It takes any collectible's data: the model animation, the
symbol, the backdrop colours (`center / edge / pattern / text`), the number, the rarity of each
attribute and availability. The demos use real collectibles (Jingle Bells "Ice Chime" on Cobalt
Blue, plus Plush Pepe, Durov's Cap, Heart Locket, Precious Peach and Toy Bear on the orbit).

| | |
| --- | --- |
| Film for the submission (phone on a live background, sound) | `media/Gift_Unwrap_Telegram.mp4` |
| The same flow full-screen, 1206 × 2622 | `media/Gift_Unwrap_screen.mp4` |
| Android, rendered from the real code | `media/GiftUnwrap_Android_render.mp4` |
| Android demo app | `media/GiftUnwrap_demo.apk` (Android 7+) |
| Figma (screens and components) | https://www.figma.com/design/DrjvrVVzSh0kXpSdIzvAqJ?node-id=121-20479 |

## What's inside

```
ios/                    Xcode project (iOS 16+): demo app + Kit
  GiftUnwrap/Kit/       the effect itself (UIKit + SceneKit + AVFoundation), no dependencies
  GiftUnwrap/Demo/      chat → unwrap → profile, as in the film
android/                Android Studio project (minSdk 24, Java)
  giftunwrap/           the effect as a library (Views + Canvas), no dependencies
  app/                  demo app + FlowRenderTest
TelegramIntegration/
  ios/                  GiftUnwrapScreen module + install.py for Telegram-iOS
  android/              GiftUnwrapOverlay + install.py for Telegram-Android
```

## Run the demos

**iOS:** open `ios/GiftUnwrap.xcodeproj`, pick an iPhone simulator or device and press Run.

**Android:** open the `android/` folder in Android Studio and run `app`, or install
`media/GiftUnwrap_demo.apk`. To re-render the Android video, run the **Render flow (test)**
configuration. Frames go to `android/frames/`.

In both demos, tap the profile to play the flow again.

## The API in one screen

Android:

```java
GiftUnwrapContent c = new GiftUnwrapContent();
c.title = "Jingle Bells"; c.number = 18082;
c.art = GiftArt.frames(modelFrames, 30);          // or GiftArt.of(drawable)
c.symbolBitmap = symbol;                           // white silhouette, tinted by the backdrop
c.backdrop = new GiftUnwrapContent.Backdrop(0xff6088cf, 0xff5162b8, 0xff13247c, 0xffc2d3f5);
c.addRow("Model", "Ice Chime", "0.5%", null);
GiftUnwrapView view = new GiftUnwrapView(context, c);
view.startFrom(slotX, slotY, slotScale);           // lifts the sphere out of the message
```

iOS:

```swift
var c = GiftUnwrapContent(title: "Jingle Bells", number: 18082, giftImage: nil,
                          symbolImage: symbol, backdrop: .cobaltBlue,
                          rows: [.init(title: "Model", value: "Ice Chime", badge: "0.5%")])
c.giftFrames = modelFrames
let view = GiftUnwrapView(content: c)
view.start(from: slotCenter, scale: slotScale)     // lifts the sphere out of the message
```

`GiftOrbitView` / `GUOrbitView` take a list of collectibles (art, backdrop, symbol) and draw the
ring around the avatar; `prepareNewcomer` reserves the slot the new gift flies into.

## Put it into Telegram

Each platform takes one command and touches three places in the Telegram code. Details, the data
mapping and file lists are in `TelegramIntegration/*/INTEGRATION.md`.

```sh
python3 TelegramIntegration/ios/install.py     /path/to/Telegram-iOS
python3 TelegramIntegration/android/install.py /path/to/Telegram-Android
```

- **iOS:** adds the `GiftUnwrapScreen` module and hooks `ChatController`
  (`case .starGift, .starGiftUnique`). The first time a received collectible message is opened,
  the sphere lifts into the middle of the screen instead of the gift sheet opening.
- **Android:** adds the library and the overlay and hooks `ChatActionCell`
  (`TL_messageActionStarGiftUnique`). The first tap lifts the sphere out of the cell instead of
  opening `StarGiftSheet`.

**Show on Profile** calls the real save request (`updateStarGiftAddedToProfile` /
`saveStarGift`) and shows Telegram's own toast. Closing keeps the gift private. Later taps open
the usual gift sheet.

## Motion

- Every animation is a closed-form function of time on the display clock, so it can be
  interrupted and replays identically. The springs and curves are Telegram's own: bounce
  5/900/88, menu 5/900/104, sheet 5/900/124, and the `tg` curve bezier(0.38, 0.7, 0.125, 1).
- The hint finger presses, pulls 74 pt and lets go with a spring, every 4.2 s, until you touch
  the ribbon yourself.
- The pull is 1:1 with the finger, with rubber-banding off the axis. On release, Apple's momentum
  projection (deceleration 0.99) decides the outcome: a flick that would carry past the end breaks
  the glass, anything less springs back.
- The pattern is an even hex grid of the gift's symbol over the whole backdrop, with a soft hole
  around the gift. It pops in as a wave from the gift outwards at 900 pt/s, each symbol on the
  bounce spring.
- Haptics come in steps as the tension rises. The sounds are synthesised in code, so there are no
  audio assets, and they respect the silent switch (`.ambient`).

## What was verified

- **Android:** the project builds in Android Studio and the debug APK is produced.
  `FlowRenderTest` drives the demo with real touch events: it taps the gift message, waits through
  the hint, pulls the tab, flicks it, then taps **Show on Profile**. Every frame is rendered by
  Android's own graphics stack (Robolectric native graphics), and the test checks that the glass
  breaks and the profile opens. `media/GiftUnwrap_Android_render.mp4` is made from those frames.
- **iOS:** the project builds and runs in Xcode 27 on the iPhone 18 Pro simulator (iOS 27). The
  whole flow was played in the simulator: gift message, hint and ghost finger, the glass breaking,
  the backdrop and the sheet, **Show on Profile**, the flight into the orbit, the header recolour
  and the toast. To play it hands-free, enable the `-autoplay` launch argument in the scheme
  (Product → Scheme → Edit Scheme → Run → Arguments).
- **Telegram adapters:** the installers were run against current Telegram-iOS and
  Telegram-Android checkouts, and both are idempotent. The adapters themselves compile only inside
  the Telegram projects, so they have not been built yet.
