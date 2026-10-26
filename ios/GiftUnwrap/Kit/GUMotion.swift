import UIKit

/// Motion tokens taken from Telegram-iOS (Display / ContainedViewLayoutTransition) and the film.
///
/// The whole unwrap choreography is evaluated as closed-form functions of time
/// (`GUMotion.spring`, `GUMotion.bezier`), the same way the concept film was rendered.
/// That keeps every frame deterministic, makes the sequence interruptible at any moment
/// and lets the iOS and Android versions share one set of numbers.
public enum GUMotion {
    public struct Spring {
        public let mass: CGFloat
        public let stiffness: CGFloat
        public let damping: CGFloat
    }

    /// Telegram's springs: `.bounce` for things that pop, `.menu` for menus/toasts, `.sheet` for sheets.
    public static let bounce = Spring(mass: 5.0, stiffness: 900.0, damping: 88.0)
    public static let menu = Spring(mass: 5.0, stiffness: 900.0, damping: 104.0)
    public static let sheet = Spring(mass: 5.0, stiffness: 900.0, damping: 124.0)

    /// Normalised spring response 0 → 1 at time `t` (seconds). Returns 0 for t <= 0.
    public static func spring(_ t: CGFloat, _ s: Spring) -> CGFloat {
        if t <= 0.0 {
            return 0.0
        }
        let w = sqrt(s.stiffness / s.mass)
        let z = s.damping / (2.0 * sqrt(s.stiffness * s.mass))
        if z < 1.0 {
            let wd = w * sqrt(1.0 - z * z)
            return 1.0 - exp(-z * w * t) * (cos(wd * t) + z * w / wd * sin(wd * t))
        } else {
            return 1.0 - exp(-w * t) * (1.0 + w * t)
        }
    }

    /// Cubic bezier easing (CSS / CAMediaTimingFunction semantics), x in 0...1.
    public static func bezier(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat, _ x: CGFloat) -> CGFloat {
        let x = clamp(x)
        var lo: CGFloat = 0.0
        var hi: CGFloat = 1.0
        var u = x
        for _ in 0 ..< 24 {
            u = (lo + hi) * 0.5
            let bx = 3.0 * (1.0 - u) * (1.0 - u) * u * x1 + 3.0 * (1.0 - u) * u * u * x2 + u * u * u
            if bx < x {
                lo = u
            } else {
                hi = u
            }
        }
        return 3.0 * (1.0 - u) * (1.0 - u) * u * y1 + 3.0 * (1.0 - u) * u * u * y2 + u * u * u
    }

    /// Telegram's default transition curve (`ContainedViewLayoutTransitionCurve.spring` as a bezier).
    public static func tg(_ u: CGFloat) -> CGFloat { return bezier(0.38, 0.7, 0.125, 1.0, u) }
    public static func easeOut(_ u: CGFloat) -> CGFloat { return bezier(0.2, 0.9, 0.3, 1.0, u) }
    public static func easeInOut(_ u: CGFloat) -> CGFloat { return bezier(0.42, 0.0, 0.58, 1.0, u) }
    public static func easeIn(_ u: CGFloat) -> CGFloat { return bezier(0.5, 0.0, 0.9, 0.6, u) }

    public static func clamp(_ x: CGFloat, _ a: CGFloat = 0.0, _ b: CGFloat = 1.0) -> CGFloat {
        return min(b, max(a, x))
    }

    public static func lerp(_ a: CGFloat, _ b: CGFloat, _ u: CGFloat) -> CGFloat {
        return a + (b - a) * u
    }

    public static func lerp(_ a: CGPoint, _ b: CGPoint, _ u: CGFloat) -> CGPoint {
        return CGPoint(x: lerp(a.x, b.x, u), y: lerp(a.y, b.y, u))
    }

    /// Progress of a segment that starts at `t0` and lasts `d`, eased.
    public static func seg(_ t: CGFloat, _ t0: CGFloat, _ d: CGFloat, _ ease: (CGFloat) -> CGFloat = { $0 }) -> CGFloat {
        return ease(clamp((t - t0) / d))
    }

    /// Apple's rubber-band function for soft limits.
    public static func rubberBand(_ overshoot: CGFloat, dimension: CGFloat, constant: CGFloat = 0.55) -> CGFloat {
        return (overshoot * dimension * constant) / (dimension + constant * abs(overshoot))
    }

    /// Small deterministic hash 0..<1 (same as the film renderer).
    public static func hash(_ n: CGFloat) -> CGFloat {
        let s = sin(n * 127.1 + 311.7) * 43758.5453
        return s - floor(s)
    }

    /// Timing function for UIKit/CA animations that should match `tg`.
    public static let tgTimingFunction = CAMediaTimingFunction(controlPoints: 0.38, 0.7, 0.125, 1.0)
}

/// Deterministic pseudo random numbers (LCG), so the shatter looks the same every time.
public struct GURandom {
    private var state: UInt32

    public init(seed: UInt32) {
        self.state = seed
    }

    public mutating func next() -> CGFloat {
        self.state = self.state &* 1664525 &+ 1013904223
        return CGFloat(self.state) / 4294967296.0
    }

    public mutating func range(_ a: CGFloat, _ b: CGFloat) -> CGFloat {
        return a + (b - a) * self.next()
    }
}

/// A CADisplayLink wrapper that calls `tick` with the media time on every frame.
public final class GUDisplayLink: NSObject {
    private var link: CADisplayLink?
    private let tick: (CFTimeInterval) -> Void

    public init(tick: @escaping (CFTimeInterval) -> Void) {
        self.tick = tick
        super.init()
    }

    public var isRunning: Bool {
        return self.link != nil
    }

    public func start() {
        if self.link != nil {
            return
        }
        let link = CADisplayLink(target: self, selector: #selector(self.step(_:)))
        if #available(iOS 15.0, *) {
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 60.0, maximum: 120.0, preferred: 120.0)
        }
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    public func stop() {
        self.link?.invalidate()
        self.link = nil
    }

    @objc private func step(_ link: CADisplayLink) {
        self.tick(link.targetTimestamp)
    }

    deinit {
        self.link?.invalidate()
    }
}

extension UIColor {
    convenience init(guRGB rgb: UInt32, alpha: CGFloat = 1.0) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xff) / 255.0,
            green: CGFloat((rgb >> 8) & 0xff) / 255.0,
            blue: CGFloat(rgb & 0xff) / 255.0,
            alpha: alpha
        )
    }

    func mixed(with other: UIColor, _ u: CGFloat) -> UIColor {
        var r1: CGFloat = 0.0, g1: CGFloat = 0.0, b1: CGFloat = 0.0, a1: CGFloat = 0.0
        var r2: CGFloat = 0.0, g2: CGFloat = 0.0, b2: CGFloat = 0.0, a2: CGFloat = 0.0
        self.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return UIColor(red: r1 + (r2 - r1) * u, green: g1 + (g2 - g1) * u, blue: b1 + (b2 - b1) * u, alpha: a1 + (a2 - a1) * u)
    }
}

extension CGPoint {
    static func + (a: CGPoint, b: CGPoint) -> CGPoint { return CGPoint(x: a.x + b.x, y: a.y + b.y) }
    static func - (a: CGPoint, b: CGPoint) -> CGPoint { return CGPoint(x: a.x - b.x, y: a.y - b.y) }
    static func * (a: CGPoint, k: CGFloat) -> CGPoint { return CGPoint(x: a.x * k, y: a.y * k) }
    var length: CGFloat { return sqrt(self.x * self.x + self.y * self.y) }
}

/// Runs `body` with implicit Core Animation actions disabled.
func guWithoutAnimation(_ body: () -> Void) {
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    body()
    CATransaction.commit()
}
