import UIKit

/// Light effects of the snap: a flash, an expanding ring of light, slow rays behind the gift,
/// a burst of sparkles and idle twinkles. All plain Core Animation layers.
final class GUEffectsLayer: CALayer {
    /// Aura and rays: add this layer *behind* the gift; the effects layer itself goes in front.
    let backLayer = CALayer()
    private let flash = CAGradientLayer()
    private let ring = CAShapeLayer()
    private let rays = CAShapeLayer()
    private let raysMask = CAGradientLayer()
    private let aura = CAGradientLayer()
    private let burst = CAEmitterLayer()
    private let twinkles = CAEmitterLayer()
    private let trail = CAEmitterLayer()
    private var burstFired = false

    init(tint: UIColor) {
        super.init()
        let light = tint.mixed(with: .white, 0.7)

        self.aura.type = .radial
        self.aura.colors = [light.withAlphaComponent(0.55).cgColor, light.withAlphaComponent(0.0).cgColor]
        self.aura.startPoint = CGPoint(x: 0.5, y: 0.5)
        self.aura.endPoint = CGPoint(x: 1.0, y: 1.0)
        self.aura.opacity = 0.0
        self.backLayer.addSublayer(self.aura)

        self.rays.fillColor = UIColor.white.withAlphaComponent(0.10).cgColor
        self.rays.opacity = 0.0
        self.raysMask.type = .radial
        self.raysMask.colors = [UIColor.black.cgColor, UIColor.black.withAlphaComponent(0.0).cgColor]
        self.raysMask.startPoint = CGPoint(x: 0.5, y: 0.5)
        self.raysMask.endPoint = CGPoint(x: 1.0, y: 1.0)
        self.rays.mask = self.raysMask
        self.backLayer.addSublayer(self.rays)

        self.flash.type = .radial
        self.flash.colors = [UIColor.white.cgColor, light.withAlphaComponent(0.6).cgColor, light.withAlphaComponent(0.0).cgColor]
        self.flash.locations = [0.0, 0.25, 1.0]
        self.flash.startPoint = CGPoint(x: 0.5, y: 0.5)
        self.flash.endPoint = CGPoint(x: 1.0, y: 1.0)
        self.flash.opacity = 0.0
        self.addSublayer(self.flash)

        self.ring.fillColor = nil
        self.ring.strokeColor = UIColor.white.cgColor
        self.ring.lineWidth = 3.0
        self.ring.shadowColor = light.cgColor
        self.ring.shadowRadius = 8.0
        self.ring.shadowOpacity = 1.0
        self.ring.shadowOffset = .zero
        self.ring.opacity = 0.0
        self.addSublayer(self.ring)

        let sparkle = GUImages.sparkle().cgImage
        func cell(_ color: UIColor, birth: Float, velocity: CGFloat, life: Float, scale: CGFloat) -> CAEmitterCell {
            let c = CAEmitterCell()
            c.contents = sparkle
            c.color = color.cgColor
            c.birthRate = birth
            c.lifetime = life
            c.lifetimeRange = life * 0.5
            c.velocity = velocity
            c.velocityRange = velocity * 0.7
            c.emissionRange = 2.0 * .pi
            c.scale = scale
            c.scaleRange = scale * 0.6
            c.scaleSpeed = -scale * 0.4
            c.alphaSpeed = -1.0 / life
            c.spin = 2.0
            c.spinRange = 4.0
            return c
        }
        self.burst.emitterShape = .circle
        self.burst.emitterMode = .outline
        self.burst.renderMode = .additive
        self.burst.emitterCells = [
            cell(.white, birth: 900, velocity: 380, life: 1.0, scale: 0.32),
            cell(UIColor(guRGB: 0xcfe6ff), birth: 600, velocity: 300, life: 1.2, scale: 0.26),
            cell(UIColor(guRGB: 0x9fd0ff), birth: 400, velocity: 240, life: 1.1, scale: 0.22),
        ]
        for c in self.burst.emitterCells ?? [] {
            c.yAcceleration = 260.0
        }
        self.burst.birthRate = 0.0
        self.addSublayer(self.burst)

        self.twinkles.emitterShape = .circle
        self.twinkles.emitterMode = .surface
        self.twinkles.renderMode = .additive
        let tw = cell(.white, birth: 7, velocity: 6, life: 1.3, scale: 0.22)
        tw.alphaSpeed = 0.0
        tw.alphaRange = 0.0
        tw.scaleSpeed = -0.16
        self.twinkles.emitterCells = [tw]
        self.twinkles.birthRate = 0.0
        self.addSublayer(self.twinkles)

        self.trail.emitterShape = .point
        self.trail.renderMode = .additive
        let tr = cell(UIColor(guRGB: 0xcfe6ff), birth: 70, velocity: 24, life: 0.55, scale: 0.2)
        tr.yAcceleration = 60.0
        self.trail.emitterCells = [tr]
        self.trail.birthRate = 0.0
        self.addSublayer(self.trail)
    }

    override init(layer: Any) {
        super.init(layer: layer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// `age` = seconds since the snap. `center` = where the glass was. `giftCenter` = the gift now.
    func update(age: CGFloat, center: CGPoint, giftCenter: CGPoint, giftSize: CGFloat, idleAlpha: CGFloat, time: CGFloat) {
        guWithoutAnimation {
            // Flash: peaks in 20 ms, gone after ~0.3 s.
            let fl: CGFloat = age > -0.02 ? exp(-pow(max(0.0, age) / 0.13, 1.4)) * GUMotion.clamp((age + 0.02) / 0.02) : 0.0
            let fs = 260.0 + 220.0 * GUMotion.clamp(age / 0.3)
            self.flash.bounds = CGRect(x: 0.0, y: 0.0, width: fs, height: fs)
            self.flash.position = center
            self.flash.opacity = Float(fl)

            // Ring of light.
            let ringR = 60.0 + 450.0 * GUMotion.easeOut(GUMotion.clamp(age / 0.6))
            self.ring.path = UIBezierPath(arcCenter: center, radius: ringR, startAngle: 0.0, endAngle: 2.0 * .pi, clockwise: true).cgPath
            self.ring.opacity = age > 0.0 ? Float(0.55 * (1.0 - GUMotion.clamp(age / 0.6))) : 0.0

            // Aura and slow rays behind the gift.
            let auraI = age > 0.0 ? (0.35 + 0.65 * exp(-age * 1.5)) * idleAlpha : 0.0
            let auraSize = giftSize * 3.4
            self.aura.bounds = CGRect(x: 0.0, y: 0.0, width: auraSize, height: auraSize)
            self.aura.position = giftCenter
            self.aura.opacity = Float(auraI * 0.6)

            let raysAlpha: CGFloat = 0.0   // the backdrop's own light replaces the rays
            self.rays.opacity = Float(raysAlpha * 0.9)
            if raysAlpha > 0.0 {
                self.rays.path = GUEffectsLayer.raysPath(center: giftCenter, radius: 300.0, rotation: time * 0.12)
                self.raysMask.frame = CGRect(x: giftCenter.x - 300.0, y: giftCenter.y - 300.0, width: 600.0, height: 600.0)
            }

            // Sparkle burst, fired once.
            if age >= 0.0 && !self.burstFired {
                self.burstFired = true
                self.burst.emitterPosition = center
                self.burst.emitterSize = CGSize(width: 120.0, height: 120.0)
                self.burst.beginTime = CACurrentMediaTime()
                self.burst.birthRate = 1.0
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.07) { [weak self] in
                    self?.burst.birthRate = 0.0
                }
            }
            self.twinkles.emitterPosition = giftCenter
            self.twinkles.emitterSize = CGSize(width: giftSize * 1.5, height: giftSize * 1.2)
            self.twinkles.birthRate = age > 0.85 && idleAlpha > 0.5 ? 1.0 : 0.0
        }
    }

    /// Sparkle trail behind a flying gift.
    func setTrail(at point: CGPoint?) {
        guWithoutAnimation {
            if let point = point {
                if self.trail.birthRate == 0.0 {
                    self.trail.beginTime = CACurrentMediaTime()
                }
                self.trail.emitterPosition = point
                self.trail.birthRate = 1.0
            } else {
                self.trail.birthRate = 0.0
            }
        }
    }

    func reset() {
        self.burstFired = false
        self.burst.birthRate = 0.0
        self.twinkles.birthRate = 0.0
        self.trail.birthRate = 0.0
    }

    private static func raysPath(center: CGPoint, radius: CGFloat, rotation: CGFloat) -> CGPath {
        let path = UIBezierPath()
        let count = 12
        for i in 0 ..< count {
            let a = rotation + CGFloat(i) / CGFloat(count) * 2.0 * .pi
            let w: CGFloat = 0.07 + 0.04 * GUMotion.hash(CGFloat(i))
            path.move(to: center)
            path.addLine(to: CGPoint(x: center.x + cos(a - w) * radius, y: center.y + sin(a - w) * radius))
            path.addLine(to: CGPoint(x: center.x + cos(a + w) * radius, y: center.y + sin(a + w) * radius))
            path.close()
        }
        return path.cgPath
    }
}
