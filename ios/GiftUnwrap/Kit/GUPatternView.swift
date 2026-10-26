import UIKit

/// A collectible's backdrop: Telegram's radial gradient (center → edge colour) and the symbol
/// pattern as an even field that fills the whole area — a hex grid anchored on the gift that
/// fades a little with distance and stays clear right behind the gift. The area is a mask
/// (a growing circle, the sheet header, …) and the symbols pop in as a wave spreads from a
/// point.
///
/// Used full-screen behind the unwrapped gift, in the gift sheet header and in the profile
/// header when the collectible lands there.
final class GUPatternView: UIView {
    struct Symbol {
        let layer: CALayer
        let offset: CGPoint
        let distance: CGFloat
        let jitter: CGFloat
    }

    private let gradient = CAGradientLayer()
    private let backlight = CAGradientLayer()
    private let symbolsContainer = CALayer()
    private let revealMask = CAShapeLayer()
    private(set) var symbols: [Symbol] = []

    /// Anchor of the pattern and centre of the gradient (the gift).
    var patternCenter: CGPoint = .zero
    /// Radius of the gradient (where it reaches the edge colour).
    var gradientRadius: CGFloat = 470.0
    /// Scale of the whole field (the sheet header uses a slightly tighter field).
    var patternScale: CGFloat = 1.0
    var symbolSize: CGFloat = 26.0
    var symbolAlpha: CGFloat = 0.62
    /// Radius kept clear around the anchor.
    var holeRadius: CGFloat = 70.0

    init(backdrop: GiftUnwrapContent.Backdrop, symbol: UIImage?, makeSymbolLayer: (() -> CALayer)? = nil, spacing: CGFloat = 52.0) {
        super.init(frame: .zero)
        self.isUserInteractionEnabled = false
        self.clipsToBounds = true

        self.gradient.type = .radial
        self.gradient.colors = [backdrop.inner.cgColor, backdrop.outer.cgColor]
        self.gradient.locations = [0.0, 1.0]
        self.layer.addSublayer(self.gradient)

        self.backlight.type = .radial
        self.backlight.colors = [
            UIColor(guRGB: 0xe2eeff, alpha: 0.55).cgColor,
            UIColor(guRGB: 0xbed4ff, alpha: 0.22).cgColor,
            UIColor(guRGB: 0xa0beff, alpha: 0.0).cgColor,
        ]
        self.backlight.locations = [0.0, 0.45, 1.0]
        self.backlight.startPoint = CGPoint(x: 0.5, y: 0.5)
        self.backlight.endPoint = CGPoint(x: 1.0, y: 1.0)
        self.backlight.opacity = 0.0
        self.layer.addSublayer(self.backlight)

        self.layer.addSublayer(self.symbolsContainer)
        let image = makeSymbolLayer == nil ? GUImages.tinted(symbol ?? GUImages.snowflake(), backdrop.pattern).cgImage : nil
        let rowHeight = spacing * 0.866
        // Live sticker layers (Telegram's animated symbol) are heavier: a smaller field.
        let rows = makeSymbolLayer == nil ? 14 : 10
        let cols = makeSymbolLayer == nil ? 6 : 5
        for j in -rows ... rows {
            for i in -cols ... cols {
                let offset = CGPoint(x: (CGFloat(i) + (j % 2 != 0 ? 0.5 : 0.0)) * spacing, y: CGFloat(j) * rowHeight)
                let l: CALayer
                if let make = makeSymbolLayer {
                    l = make()
                } else {
                    l = CALayer()
                    l.contents = image
                    l.contentsGravity = .resizeAspect
                }
                l.opacity = 0.0
                self.symbolsContainer.addSublayer(l)
                self.symbols.append(Symbol(layer: l, offset: offset, distance: offset.length, jitter: GUMotion.hash(CGFloat(i) * 31.7 + CGFloat(j) * 7.3)))
            }
        }
        self.revealMask.fillColor = UIColor.black.cgColor
        self.layer.mask = self.revealMask
        self.setReveal(path: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guWithoutAnimation {
            self.gradient.frame = self.bounds
            self.symbolsContainer.frame = self.bounds
        }
    }

    /// The backdrop is visible inside `path` (this view's coordinates); `nil` hides it.
    func setReveal(path: CGPath?) {
        guWithoutAnimation {
            self.isHidden = path == nil
            self.revealMask.path = path
        }
    }

    func setReveal(center: CGPoint, radius: CGFloat) {
        self.setReveal(path: radius > 0.5 ? UIBezierPath(arcCenter: center, radius: radius, startAngle: 0.0, endAngle: 2.0 * .pi, clockwise: true).cgPath : nil)
    }

    /// Places the gradient and the field for the current anchor, and pops the symbols in as a
    /// wave from `waveOrigin` (`age` = seconds since the wave started, `speed` in pt/s).
    func update(age: CGFloat, waveOrigin: CGPoint, speed: CGFloat = 900.0, backlight: CGFloat = 0.0) {
        guWithoutAnimation {
            let b = self.bounds
            let c = self.patternCenter
            if b.width > 0.0 && b.height > 0.0 {
                self.gradient.startPoint = CGPoint(x: c.x / b.width, y: c.y / b.height)
                self.gradient.endPoint = CGPoint(x: (c.x + self.gradientRadius) / b.width, y: (c.y + self.gradientRadius) / b.height)
            }
            let bs = 300.0 * self.patternScale
            self.backlight.bounds = CGRect(x: 0.0, y: 0.0, width: bs, height: bs)
            self.backlight.position = c
            self.backlight.opacity = Float(backlight)
            for s in self.symbols {
                let p = c + s.offset * self.patternScale
                let size = self.symbolSize * self.patternScale * (1.08 - 0.22 * GUMotion.clamp(s.distance / 520.0))
                if p.x < -size || p.x > b.width + size || p.y < -size || p.y > b.height + size {
                    s.layer.opacity = 0.0
                    continue
                }
                let a = age - (p - waveOrigin).length / speed - s.jitter * 0.06
                let k = max(0.0, GUMotion.spring(a, GUMotion.bounce))
                let d = s.distance * self.patternScale
                let hole = GUMotion.clamp((d - self.holeRadius * 0.62) / (self.holeRadius * 0.63))
                let alpha = a > 0.0 ? self.symbolAlpha * GUMotion.clamp(a / 0.1) * (1.0 - 0.4 * GUMotion.clamp(s.distance / 600.0)) * hole * hole * (3.0 - 2.0 * hole) : 0.0
                s.layer.bounds = CGRect(x: 0.0, y: 0.0, width: size, height: size)
                s.layer.position = p
                s.layer.opacity = Float(alpha)
                s.layer.setAffineTransform(CGAffineTransform(scaleX: max(0.0001, k), y: max(0.0001, k)))
            }
        }
    }
}
