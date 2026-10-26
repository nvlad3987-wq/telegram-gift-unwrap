import UIKit

/// Demo assets: screens exported from the Telegram iOS 26 UI kit (Figma, @3x of a 402 × 874 pt
/// screen), the gift models as frame atlases rendered from the original Telegram Lottie files
/// (30 fps loops, 10 frames per row), and symbol silhouettes. All in `DemoAssets/`.
enum DemoContent {
    /// Kit screens are laid out on a 402 pt wide iPhone screen.
    static let kitWidth: CGFloat = 402.0

    static func image(_ name: String, scale: CGFloat = 3.0) -> UIImage? {
        guard let url = Bundle.main.url(forResource: name, withExtension: nil), let data = try? Data(contentsOf: url) else {
            return nil
        }
        return UIImage(data: data, scale: scale)
    }

    static func kit(_ name: String) -> UIImage? {
        return image("kit_\(name)@3x.webp")
    }

    static func symbol(_ name: String) -> UIImage? {
        return image("sym_\(name).png", scale: 1.0)
    }

    /// Frames of a model: `<name>_<count>x<size>.webp`, 10 frames per row.
    static func frames(_ name: String) -> [UIImage] {
        guard let urls = Bundle.main.urls(forResourcesWithExtension: "webp", subdirectory: nil),
              let url = urls.first(where: { $0.lastPathComponent.hasPrefix(name + "_") }),
              let data = try? Data(contentsOf: url), let encoded = UIImage(data: data)?.cgImage,
              let atlas = decoded(encoded) else {
            return []
        }
        let spec = url.deletingPathExtension().lastPathComponent.dropFirst(name.count + 1).split(separator: "x")
        guard spec.count == 2, let count = Int(spec[0]), let size = Int(spec[1]) else {
            return []
        }
        var out: [UIImage] = []
        for i in 0 ..< count {
            let rect = CGRect(x: (i % 10) * size, y: (i / 10) * size, width: size, height: size)
            if let cell = atlas.cropping(to: rect) {
                out.append(UIImage(cgImage: cell, scale: 3.0, orientation: .up))
            }
        }
        return out
    }

    /// Decodes an image into a bitmap once. Frames cropped from a still-encoded atlas would each
    /// decode the whole atlas again when first drawn (seconds of main-thread work for 90 frames).
    static func decoded(_ image: CGImage) -> CGImage? {
        let w = image.width, h = image.height
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else {
            return nil
        }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        return ctx.makeImage()
    }

    /// The gift from the film: Jingle Bells #18 082 — model Ice Chime, symbol Snowflake,
    /// backdrop Cobalt Blue (real attributes and rarities).
    static func jingleBells() -> GiftUnwrapContent {
        var c = GiftUnwrapContent(
            title: "Jingle Bells",
            number: 18082,
            giftImage: nil,
            symbolImage: symbol("snowflake"),
            backdrop: .cobaltBlue,
            rows: [
                .init(title: "Model", value: "Ice Chime", badge: GiftUnwrapContent.formatRarity(permille: 5)),
                .init(title: "Symbol", value: "Snowflake", badge: GiftUnwrapContent.formatRarity(permille: 16)),
                .init(title: "Backdrop", value: "Cobalt Blue", badge: GiftUnwrapContent.formatRarity(permille: 18)),
                .init(title: "Availability", value: "69 724/99 920 issued"),
                .init(title: "From", value: "Mia Carter"),
            ]
        )
        c.giftFrames = frames("ice_chime")
        c.message = "Happy birthday, Alex! ✨"
        return c
    }

    static func backdrop(_ center: UInt32, _ edge: UInt32, _ pattern: UInt32, _ text: UInt32) -> GiftUnwrapContent.Backdrop {
        return .init(inner: UIColor(guRGB: center), outer: UIColor(guRGB: edge), pattern: UIColor(guRGB: pattern), text: UIColor(guRGB: text))
    }

    /// Five collectibles already on Alex's profile (real models / backdrops / symbols).
    static func profileCollectibles() -> [GUCollectible] {
        return [
            GUCollectible(name: "Plush Pepe", frames: frames("plush_pepe"), backdrop: backdrop(0x78c585, 0x42a171, 0x006532, 0xb9f9d9), symbol: symbol("clover")),
            GUCollectible(name: "Durov's Cap", frames: frames("durovs_cap"), backdrop: backdrop(0x363738, 0x0e0f0f, 0x6c6868, 0x8c8f91), symbol: symbol("star")),
            GUCollectible(name: "Heart Locket", frames: frames("heart_locket"), backdrop: backdrop(0xf05f4f, 0xc43949, 0x690009, 0xffb7a6), symbol: symbol("heart")),
            GUCollectible(name: "Precious Peach", frames: frames("precious_peach"), backdrop: backdrop(0xe36692, 0xc9497c, 0x750230, 0xffd6e6), symbol: symbol("cherry")),
            GUCollectible(name: "Toy Bear", frames: frames("toy_bear"), backdrop: backdrop(0xdab345, 0xb1802a, 0x7a3100, 0xffedc7), symbol: symbol("moon")),
        ]
    }
}
