import UIKit

/// Everything the unwrap screen needs to know about the gift. Plain values only, so the
/// screen does not depend on Telegram's model types: the Telegram adapter fills this from
/// `StarGift.UniqueGift` (any collectible — model, symbol, backdrop, number, availability, see
/// `TelegramIntegration/`), the demo fills it by hand.
public struct GiftUnwrapContent {
    /// Colours of a collectible's backdrop. Telegram stores exactly these four
    /// (`StarGift.UniqueGift.Attribute.backdrop(innerColor:outerColor:patternColor:textColor:)`).
    public struct Backdrop {
        public var inner: UIColor
        public var outer: UIColor
        public var pattern: UIColor
        public var text: UIColor

        public init(inner: UIColor, outer: UIColor, pattern: UIColor, text: UIColor) {
            self.inner = inner
            self.outer = outer
            self.pattern = pattern
            self.text = text
        }

        /// "Cobalt Blue" (one of Telegram's 80 backdrops).
        public static let cobaltBlue = Backdrop(
            inner: UIColor(guRGB: 0x6088cf),
            outer: UIColor(guRGB: 0x5162b8),
            pattern: UIColor(guRGB: 0x13247c),
            text: UIColor(guRGB: 0xc2d3f5)
        )

        /// "Midnight Blue".
        public static let midnightBlue = Backdrop(
            inner: UIColor(guRGB: 0x5c6985),
            outer: UIColor(guRGB: 0x354057),
            pattern: UIColor(guRGB: 0x030a18),
            text: UIColor(guRGB: 0xbfcce0)
        )

        /// The ribbon on the wrapped gift wears the backdrop's colours.
        var ribbon: (base: UIColor, light: UIColor, dark: UIColor) {
            let base = self.outer.mixed(with: self.inner, 0.35)
            return (base, self.inner.mixed(with: .white, 0.55), self.pattern.mixed(with: base, 0.35))
        }
    }

    /// One row of Telegram's attribute table ("Model — Ice Chime 0.5%").
    public struct Row {
        public var title: String
        public var value: String
        /// Rarity capsule shown after the value, e.g. "0.5%".
        public var badge: String?

        public init(title: String, value: String, badge: String? = nil) {
            self.title = title
            self.value = value
            self.badge = badge
        }
    }

    public var title: String
    /// Collectible number. `nil` hides the "Collectible #" line.
    public var number: Int?
    /// The model as a still image (used when there is no animation).
    public var giftImage: UIImage?
    /// The model's animation frames (the demo bundles frames rendered from the original
    /// Telegram Lottie file) and their rate.
    public var giftFrames: [UIImage]?
    public var giftFramesPerSecond: Double = 30.0
    /// The pattern symbol. Drawn tinted with `backdrop.pattern`. `nil` → built-in snowflake.
    public var symbolImage: UIImage?
    public var backdrop: Backdrop
    /// Model / Symbol / Backdrop (with rarity), Availability, From — Telegram's table.
    public var rows: [Row]
    /// The sender's message, shown as the last, full-width row.
    public var message: String?
    public var caption: String = "Only you can see this gift for now."
    public var primaryActionTitle: String
    public var hint: String = "Pull the ribbon to unwrap"
    public var chips: [String] = ["transfer", "wear", "sell"]
    /// Optional: builds the gift view instead of an image view (Telegram passes its animated
    /// sticker view here). The view is resized through `bounds`, so it should lay its
    /// content out to fill its bounds.
    public var makeGiftView: (() -> UIView)?
    /// Optional: builds one symbol of the pattern (already coloured). Overrides `symbolImage`.
    public var makeSymbolLayer: (() -> CALayer)?

    public init(
        title: String,
        number: Int?,
        giftImage: UIImage?,
        symbolImage: UIImage?,
        backdrop: Backdrop,
        rows: [Row],
        primaryActionTitle: String = "Show on Profile"
    ) {
        self.title = title
        self.number = number
        self.giftImage = giftImage
        self.symbolImage = symbolImage
        self.backdrop = backdrop
        self.rows = rows
        self.primaryActionTitle = primaryActionTitle
    }

    /// Builds the view that shows the model (animated when frames or a factory are given).
    func makeModelView() -> UIView {
        if let make = self.makeGiftView {
            return make()
        }
        let imageView = UIImageView(image: self.giftFrames?.first ?? self.giftImage)
        imageView.contentMode = .scaleAspectFit
        if let frames = self.giftFrames, frames.count > 1 {
            imageView.animationImages = frames
            imageView.animationDuration = Double(frames.count) / self.giftFramesPerSecond
            imageView.startAnimating()
        }
        return imageView
    }

    /// "18 082" — Telegram groups collectible numbers with a space.
    public static func formatNumber(_ number: Int) -> String {
        let digits = String(number)
        var out = ""
        for (i, ch) in digits.enumerated() {
            if i > 0 && (digits.count - i) % 3 == 0 {
                out.append(" ")
            }
            out.append(ch)
        }
        return out
    }

    /// Rarity per mille → "1.2%" (Telegram sends rarity as permille).
    public static func formatRarity(permille: Int) -> String {
        let value = Double(permille) / 10.0
        if value == value.rounded() {
            return "\(Int(value))%"
        }
        return String(format: "%.1f%%", value)
    }
}

/// A collectible as the profile shows it: the animated model on its own backdrop with the
/// symbol pattern. Any Telegram collectible maps to this from its three attributes.
public struct GUCollectible {
    public var name: String
    public var frames: [UIImage]
    public var framesPerSecond: Double
    public var backdrop: GiftUnwrapContent.Backdrop
    public var symbol: UIImage?

    public init(name: String, frames: [UIImage], framesPerSecond: Double = 30.0, backdrop: GiftUnwrapContent.Backdrop, symbol: UIImage?) {
        self.name = name
        self.frames = frames
        self.framesPerSecond = framesPerSecond
        self.backdrop = backdrop
        self.symbol = symbol
    }
}

enum GUImages {
    /// A six-arm snowflake, used when the gift has no symbol image.
    static func snowflake(size: CGFloat = 96.0) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { ctx in
            let c = ctx.cgContext
            let k = size / 24.0
            c.translateBy(x: size / 2.0, y: size / 2.0)
            c.setStrokeColor(UIColor.white.cgColor)
            c.setLineWidth(1.7 * k)
            c.setLineCap(.round)
            for i in 0 ..< 6 {
                c.saveGState()
                c.rotate(by: CGFloat(i) * .pi / 3.0)
                c.move(to: .zero)
                c.addLine(to: CGPoint(x: 0.0, y: -9.8 * k))
                c.move(to: CGPoint(x: 0.0, y: -6.6 * k))
                c.addLine(to: CGPoint(x: -2.6 * k, y: -8.8 * k))
                c.move(to: CGPoint(x: 0.0, y: -6.6 * k))
                c.addLine(to: CGPoint(x: 2.6 * k, y: -8.8 * k))
                c.move(to: CGPoint(x: 0.0, y: -3.4 * k))
                c.addLine(to: CGPoint(x: -2.1 * k, y: -5.0 * k))
                c.move(to: CGPoint(x: 0.0, y: -3.4 * k))
                c.addLine(to: CGPoint(x: 2.1 * k, y: -5.0 * k))
                c.strokePath()
                c.restoreGState()
            }
            c.setFillColor(UIColor.white.cgColor)
            c.fillEllipse(in: CGRect(x: -1.9 * k, y: -1.9 * k, width: 3.8 * k, height: 3.8 * k))
        }
    }

    /// `image` recoloured to `color` (keeps the alpha).
    static func tinted(_ image: UIImage, _ color: UIColor) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: image.size, format: {
            let f = UIGraphicsImageRendererFormat.preferred()
            f.scale = image.scale
            return f
        }())
        return renderer.image { _ in
            let rect = CGRect(origin: .zero, size: image.size)
            image.draw(in: rect)
            color.setFill()
            UIRectFillUsingBlendMode(rect, .sourceIn)
        }
    }

    /// A four-pointed sparkle for the particle emitters.
    static func sparkle(size: CGFloat = 32.0) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { ctx in
            let c = ctx.cgContext
            let r = size / 2.0
            let colors = [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0.0).cgColor] as CFArray
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0.0, 1.0]) {
                c.drawRadialGradient(g, startCenter: CGPoint(x: r, y: r), startRadius: 0.0, endCenter: CGPoint(x: r, y: r), endRadius: r * 0.45, options: [])
            }
            let p = UIBezierPath()
            p.move(to: CGPoint(x: r, y: 0.0))
            p.addQuadCurve(to: CGPoint(x: size, y: r), controlPoint: CGPoint(x: r * 1.08, y: r * 0.92))
            p.addQuadCurve(to: CGPoint(x: r, y: size), controlPoint: CGPoint(x: r * 1.08, y: r * 1.08))
            p.addQuadCurve(to: CGPoint(x: 0.0, y: r), controlPoint: CGPoint(x: r * 0.92, y: r * 1.08))
            p.addQuadCurve(to: CGPoint(x: r, y: 0.0), controlPoint: CGPoint(x: r * 0.92, y: r * 0.92))
            UIColor.white.setFill()
            p.fill()
        }
    }

    /// Equirectangular "studio" environment for the glass: dark room, two soft boxes,
    /// a pink and a cyan bounce near the horizon (gives the iridescent rim).
    static func glassEnvironment() -> UIImage {
        let size = CGSize(width: 512.0, height: 256.0)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let c = ctx.cgContext
            let space = CGColorSpaceCreateDeviceRGB()
            let sky = [UIColor(white: 0.30, alpha: 1.0).cgColor, UIColor(white: 0.06, alpha: 1.0).cgColor, UIColor(white: 0.02, alpha: 1.0).cgColor] as CFArray
            if let g = CGGradient(colorsSpace: space, colors: sky, locations: [0.0, 0.5, 1.0]) {
                c.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0.0, y: size.height), options: [])
            }
            func blob(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat, _ color: UIColor) {
                let colors = [color.cgColor, color.withAlphaComponent(0.0).cgColor] as CFArray
                if let g = CGGradient(colorsSpace: space, colors: colors, locations: [0.0, 1.0]) {
                    c.drawRadialGradient(g, startCenter: CGPoint(x: x, y: y), startRadius: 0.0, endCenter: CGPoint(x: x, y: y), endRadius: r, options: [])
                }
            }
            blob(150.0, 60.0, 70.0, UIColor(white: 1.0, alpha: 1.0))
            blob(390.0, 80.0, 50.0, UIColor(white: 1.0, alpha: 0.75))
            blob(60.0, 128.0, 90.0, UIColor(red: 1.0, green: 0.55, blue: 0.85, alpha: 0.85))
            blob(300.0, 132.0, 90.0, UIColor(red: 0.45, green: 0.85, blue: 1.0, alpha: 0.85))
            blob(470.0, 128.0, 80.0, UIColor(red: 0.75, green: 0.6, blue: 1.0, alpha: 0.7))
        }
    }
}
