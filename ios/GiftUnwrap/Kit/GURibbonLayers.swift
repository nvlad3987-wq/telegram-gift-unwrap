import UIKit

/// The two ribbon tails hanging from the knot. The right one is the pull tab: it follows the
/// finger 1:1 while the ribbon is pulled. Drawn in 2D over the SceneKit glass.
final class GURibbonTailLayer: CALayer {
    private let rightBody = CAShapeLayer()
    private let rightShine = CAShapeLayer()
    private let leftBody = CAShapeLayer()
    private let leftShine = CAShapeLayer()
    private let hint = CAShapeLayer()

    override init() {
        super.init()
        for body in [self.leftBody, self.rightBody] {
            body.fillColor = nil
            body.strokeColor = UIColor(guRGB: 0xff4f93).cgColor
            body.lineWidth = 11.0
            body.lineCap = .round
            body.shadowColor = UIColor(guRGB: 0x7a0f3e).cgColor
            body.shadowOpacity = 0.35
            body.shadowRadius = 3.0
            body.shadowOffset = CGSize(width: 0.0, height: 2.0)
        }
        for shine in [self.leftShine, self.rightShine] {
            shine.fillColor = nil
            shine.strokeColor = UIColor(guRGB: 0xffb3d1, alpha: 0.85).cgColor
            shine.lineWidth = 3.0
            shine.lineCap = .round
        }
        self.hint.fillColor = nil
        self.hint.strokeColor = UIColor.white.withAlphaComponent(0.9).cgColor
        self.hint.lineWidth = 1.5
        self.addSublayer(self.leftBody)
        self.addSublayer(self.leftShine)
        self.addSublayer(self.rightBody)
        self.addSublayer(self.rightShine)
        self.addSublayer(self.hint)
    }

    override init(layer: Any) {
        super.init(layer: layer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// The tails wear the gift's backdrop colours.
    func setColors(base: UIColor, light: UIColor, dark: UIColor) {
        for body in [self.leftBody, self.rightBody] {
            body.strokeColor = base.cgColor
            body.shadowColor = dark.cgColor
        }
        for shine in [self.leftShine, self.rightShine] {
            shine.strokeColor = light.withAlphaComponent(0.85).cgColor
        }
    }

    /// - Parameters:
    ///   - knot: where both tails start.
    ///   - end: the right tail's end (under the finger while pulling).
    ///   - leftEnd: the left tail's end.
    ///   - sag: how much the right tail bows sideways (0 when taut).
    ///   - hintPhase: 0...1 pulsing ring around the tab, `nil` hides it.
    func update(knot: CGPoint, end: CGPoint, leftEnd: CGPoint, sag: CGFloat, alpha: CGFloat, hintPhase: CGFloat?) {
        guWithoutAnimation {
            self.opacity = Float(alpha)
            let rightPath = GURibbonTailLayer.curve(from: knot, to: end, sag: sag)
            self.rightBody.path = rightPath
            self.rightShine.path = GURibbonTailLayer.curve(from: knot + CGPoint(x: -2.0, y: -1.0), to: end + CGPoint(x: -2.5, y: -1.0), sag: sag)
            self.leftBody.path = GURibbonTailLayer.curve(from: knot, to: leftEnd, sag: -12.0)
            self.leftShine.path = GURibbonTailLayer.curve(from: knot + CGPoint(x: -2.0, y: -1.0), to: leftEnd + CGPoint(x: -2.5, y: -1.0), sag: -12.0)
            if let phase = hintPhase {
                let r = 14.0 + 16.0 * phase
                self.hint.path = UIBezierPath(ovalIn: CGRect(x: end.x - r, y: end.y - r, width: r * 2.0, height: r * 2.0)).cgPath
                self.hint.opacity = Float(0.8 * (1.0 - phase))
            } else {
                self.hint.opacity = 0.0
            }
        }
    }

    private static func curve(from a: CGPoint, to b: CGPoint, sag: CGFloat) -> CGPath {
        let mid = GUMotion.lerp(a, b, 0.5)
        let d = b - a
        let len = max(0.001, d.length)
        let normal = CGPoint(x: -d.y / len, y: d.x / len)
        let control = mid + normal * sag
        let path = UIBezierPath()
        path.move(to: a)
        path.addQuadCurve(to: b, controlPoint: control)
        return path.cgPath
    }
}

/// Hairline cracks that race across the glass just before it breaks.
/// Generated once (seeded) in unit-sphere coordinates, drawn with `strokeEnd` = progress.
final class GUCrackLayer: CALayer {
    private let lines = CAShapeLayer()
    private let glow = CAShapeLayer()
    private let clip = CAShapeLayer()
    private var unitPath = CGMutablePath()

    override init() {
        super.init()
        self.glow.fillColor = nil
        self.glow.strokeColor = UIColor(guRGB: 0xcfe6ff, alpha: 0.55).cgColor
        self.glow.lineWidth = 4.0
        self.glow.lineJoin = .round
        self.lines.fillColor = nil
        self.lines.strokeColor = UIColor.white.cgColor
        self.lines.lineWidth = 1.2
        self.lines.lineJoin = .round
        self.addSublayer(self.glow)
        self.addSublayer(self.lines)
        self.mask = self.clip
    }

    override init(layer: Any) {
        super.init(layer: layer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Builds the crack pattern starting from `origin` (in unit-disc coordinates, y down).
    func generate(origin: CGPoint, seed: UInt32 = 5) {
        var rng = GURandom(seed: seed)
        let path = CGMutablePath()
        func branch(from start: CGPoint, angle: CGFloat, steps: Int, depth: Int) {
            var p = start
            var a = angle
            path.move(to: p)
            for _ in 0 ..< steps {
                a += rng.range(-0.55, 0.55)
                let len = rng.range(0.07, 0.15)
                let q = CGPoint(x: p.x + cos(a) * len, y: p.y + sin(a) * len)
                path.addLine(to: q)
                p = q
                if p.length > 1.05 {
                    break
                }
                if depth < 2 && rng.next() < 0.28 {
                    let saved = p
                    branch(from: saved, angle: a + (rng.next() < 0.5 ? -1.0 : 1.0) * rng.range(0.5, 1.1), steps: 3 + Int(rng.next() * 4.0), depth: depth + 1)
                    path.move(to: saved)
                }
            }
        }
        let count = 7
        for i in 0 ..< count {
            let a = CGFloat(i) / CGFloat(count) * 2.0 * .pi + rng.range(-0.3, 0.3)
            branch(from: origin, angle: a, steps: 9 + Int(rng.next() * 5.0), depth: 0)
        }
        self.unitPath = path
    }

    func update(center: CGPoint, radius: CGFloat, progress: CGFloat, alpha: CGFloat) {
        guWithoutAnimation {
            self.opacity = Float(alpha)
            var t = CGAffineTransform(translationX: center.x, y: center.y).scaledBy(x: radius, y: radius)
            let path = self.unitPath.copy(using: &t)
            self.lines.path = path
            self.glow.path = path
            self.lines.strokeEnd = progress
            self.glow.strokeEnd = progress
            self.clip.path = UIBezierPath(ovalIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2.0, height: radius * 2.0)).cgPath
        }
    }
}
