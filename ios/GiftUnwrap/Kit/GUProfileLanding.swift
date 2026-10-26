import UIKit

/// The owner's collectibles circling the profile avatar like a planet's ring. Each one is shown
/// as Telegram shows a collectible: its animated model on its own backdrop (center → edge
/// gradient with the symbol pattern) and a soft glow in the backdrop colour; they hover ±1.6 pt
/// and wiggle a little, like the gifts on Telegram's profile cover. Items on the far half of
/// the ring go to `backContainer`, the near half to `frontContainer`; put the avatar between
/// the two (`install(around:)`).
final class GUOrbitView {
    final class Item {
        let root = UIView()
        let glow = CAGradientLayer()
        let disc = UIView()
        let modelView = UIImageView()
        var appearTime: CFTimeInterval?

        init(collectible c: GUCollectible) {
            self.root.isUserInteractionEnabled = false
            let r: CGFloat = 19.0
            self.glow.type = .radial
            self.glow.colors = [c.backdrop.inner.withAlphaComponent(0.55).cgColor, c.backdrop.inner.withAlphaComponent(0.0).cgColor]
            self.glow.startPoint = CGPoint(x: 0.5, y: 0.5)
            self.glow.endPoint = CGPoint(x: 1.0, y: 1.0)
            self.glow.frame = CGRect(x: -r * 1.9, y: -r * 1.9, width: r * 3.8, height: r * 3.8)
            self.root.layer.addSublayer(self.glow)
            self.disc.frame = CGRect(x: -r, y: -r, width: r * 2.0, height: r * 2.0)
            self.disc.layer.cornerRadius = r
            self.disc.clipsToBounds = true
            self.disc.layer.borderWidth = 0.6
            self.disc.layer.borderColor = UIColor.white.withAlphaComponent(0.28).cgColor
            let g = CAGradientLayer()
            g.type = .radial
            g.colors = [c.backdrop.inner.cgColor, c.backdrop.outer.cgColor]
            g.startPoint = CGPoint(x: 0.5, y: 0.42)
            g.endPoint = CGPoint(x: 1.0, y: 1.0)
            g.frame = self.disc.bounds
            self.disc.layer.addSublayer(g)
            if let symbol = c.symbol {
                let image = GUImages.tinted(symbol, c.backdrop.pattern).cgImage
                for i in 0 ..< 7 {
                    let a = CGFloat(i) * 2.0 * .pi / 7.0 + 0.3
                    let s = CALayer()
                    s.contents = image
                    s.contentsGravity = .resizeAspect
                    s.opacity = 0.5
                    let h = r * 0.13
                    s.frame = CGRect(x: r + cos(a) * r * 0.78 - h, y: r + sin(a) * r * 0.78 - h, width: h * 2.0, height: h * 2.0)
                    self.disc.layer.addSublayer(s)
                }
            }
            self.root.addSubview(self.disc)
            self.modelView.image = c.frames.first
            if c.frames.count > 1 {
                self.modelView.animationImages = c.frames
                self.modelView.animationDuration = Double(c.frames.count) / c.framesPerSecond
                self.modelView.startAnimating()
            }
            self.modelView.contentMode = .scaleAspectFit
            self.modelView.frame = CGRect(x: -17.0, y: -17.0, width: 34.0, height: 34.0)
            self.root.addSubview(self.modelView)
        }
    }

    let backContainer = UIView()
    let frontContainer = UIView()
    var avatarCenter: CGPoint = .zero
    var radiusX: CGFloat = 150.0
    var radiusY: CGFloat = 30.0
    var depth: CGFloat = 80.0
    var tilt: CGFloat = -0.07
    let omega: CGFloat = 0.36
    static let modelSize: CGFloat = 34.0

    private var items: [Item] = []
    private var newcomer: Item?
    private var arrivalTime: CFTimeInterval?

    init(collectibles: [GUCollectible]) {
        self.backContainer.isUserInteractionEnabled = false
        self.frontContainer.isUserInteractionEnabled = false
        for c in collectibles {
            self.items.append(Item(collectible: c))
        }
    }

    func install(around avatar: UIView) {
        guard let parent = avatar.superview else {
            return
        }
        parent.insertSubview(self.backContainer, belowSubview: avatar)
        parent.insertSubview(self.frontContainer, aboveSubview: avatar)
    }

    func layout(frame: CGRect) {
        self.backContainer.frame = frame
        self.frontContainer.frame = frame
    }

    private func slotAngles(_ t: CFTimeInterval) -> (old: [CGFloat], new: CGFloat) {
        let n = CGFloat(self.items.count)
        var k: CGFloat = 0.0
        if let a = self.arrivalTime {
            k = GUMotion.seg(CGFloat(t), CGFloat(a) - 0.5, 0.9, GUMotion.tg)
        }
        let base = 1.15 + CGFloat(t) * self.omega
        var old: [CGFloat] = []
        for i in 0 ..< self.items.count {
            let before = CGFloat(i) * 2.0 * .pi / max(1.0, n)
            let after = CGFloat(i) * 2.0 * .pi / (n + 1.0)
            old.append(base + GUMotion.lerp(before, after, k))
        }
        return (old, base + n * 2.0 * .pi / (n + 1.0))
    }

    /// Point (in the containers' coordinates) and depth of an orbit angle.
    func position(angle phi: CGFloat) -> (point: CGPoint, z: CGFloat) {
        let x = cos(phi) * self.radiusX
        let y = sin(phi) * self.radiusY
        let z = sin(phi) * self.depth
        let c = cos(self.tilt), s = sin(self.tilt)
        return (CGPoint(x: self.avatarCenter.x + x * c - y * s, y: self.avatarCenter.y + 4.0 + x * s + y * c), z)
    }

    /// Where a newcomer arriving at `time` will sit at that moment.
    func landingPoint(arrivingAt time: CFTimeInterval) -> (point: CGPoint, scale: CGFloat) {
        let saved = self.arrivalTime
        self.arrivalTime = time
        let a = self.slotAngles(time).new
        self.arrivalTime = saved
        let p = self.position(angle: a)
        return (p.point, 1.0 + p.z / 400.0)
    }

    /// Reserves a slot for a collectible that lands at `time`; the others make room.
    func prepareNewcomer(_ collectible: GUCollectible, arrivingAt time: CFTimeInterval) {
        let item = Item(collectible: collectible)
        item.appearTime = time
        item.root.isHidden = true
        self.newcomer = item
        self.arrivalTime = time
    }

    func update(time t: CFTimeInterval) {
        let angles = self.slotAngles(t)
        for (i, item) in self.items.enumerated() {
            self.place(item, angle: angles.old[i], time: t, index: i, appear: 1.0)
        }
        if let item = self.newcomer, let a = item.appearTime {
            let age = CGFloat(t - a)
            item.root.isHidden = age < -0.02
            self.place(item, angle: angles.new, time: t, index: self.items.count, appear: max(0.001, GUMotion.spring(age + 0.02, GUMotion.bounce)))
        }
    }

    private func place(_ item: Item, angle: CGFloat, time: CFTimeInterval, index: Int, appear: CGFloat) {
        let p = self.position(angle: angle)
        let container = p.z < 0.0 ? self.backContainer : self.frontContainer
        if item.root.superview !== container {
            container.addSubview(item.root)
        }
        let t = CGFloat(time)
        let i = CGFloat(index)
        let s = (1.0 + p.z / 400.0) * appear
        let hover = sin(t * 2.0 * .pi / (3.8 + i * 0.35) + i) * 1.6
        item.root.center = CGPoint(x: p.point.x, y: p.point.y + hover)
        item.root.transform = CGAffineTransform(scaleX: s, y: s)
        item.modelView.transform = CGAffineTransform(rotationAngle: sin(t * 2.0 * .pi / (2.4 + i * 0.3) + i * 2.0) * 0.04)
    }
}

/// Flies a view along a curve from where it is to a (possibly moving) target, shrinking it,
/// with a sparkle trail. Time-driven like the rest of the sequence.
final class GUGiftFlight {
    private let view: UIView
    private let startCenter: CGPoint
    private let startSize: CGFloat
    private let target: (CFTimeInterval) -> (point: CGPoint, size: CGFloat)
    private let duration: CFTimeInterval
    private let startTime: CFTimeInterval
    private let onFrame: (CGPoint) -> Void
    private let completion: () -> Void
    private var link: GUDisplayLink?
    let arrivalTime: CFTimeInterval

    init(view: UIView, from frame: CGRect, duration: CFTimeInterval = 1.2, target: @escaping (CFTimeInterval) -> (point: CGPoint, size: CGFloat), onFrame: @escaping (CGPoint) -> Void, completion: @escaping () -> Void) {
        self.view = view
        self.startCenter = CGPoint(x: frame.midX, y: frame.midY)
        self.startSize = frame.width
        self.target = target
        self.duration = duration
        let now = CACurrentMediaTime()
        self.startTime = now
        self.arrivalTime = now + duration
        self.onFrame = onFrame
        self.completion = completion
    }

    func start() {
        let link = GUDisplayLink(tick: { [weak self] t in
            self?.tick(t)
        })
        self.link = link
        link.start()
        self.tick(CACurrentMediaTime())
    }

    private func tick(_ t: CFTimeInterval) {
        let u = GUMotion.clamp(CGFloat((t - self.startTime) / self.duration))
        let e = GUMotion.bezier(0.42, 0.0, 0.2, 1.0, u)
        let end = self.target(t)
        let p0 = self.startCenter
        let p1 = p0 + CGPoint(x: -10.0, y: -150.0)
        let p2 = end.point + CGPoint(x: -70.0, y: -110.0)
        let p3 = end.point
        func cubic(_ a: CGFloat, _ b: CGFloat, _ c: CGFloat, _ d: CGFloat) -> CGFloat {
            let v = 1.0 - e
            return v * v * v * a + 3.0 * v * v * e * b + 3.0 * v * e * e * c + e * e * e * d
        }
        let p = CGPoint(x: cubic(p0.x, p1.x, p2.x, p3.x), y: cubic(p0.y, p1.y, p2.y, p3.y))
        let size = GUMotion.lerp(self.startSize * 1.08, end.size, GUMotion.easeOut(GUMotion.clamp(u * 1.15)))
        let rz = sin(e * .pi) * -0.35
        let q = 0.06 * sin(e * .pi * 3.0) * (1.0 - e)
        guWithoutAnimation {
            self.view.bounds = CGRect(x: 0.0, y: 0.0, width: size, height: size)
            self.view.center = p
            self.view.transform = CGAffineTransform(rotationAngle: rz).scaledBy(x: 1.0 + q, y: 1.0 - q)
        }
        self.onFrame(p)
        if u >= 1.0 {
            self.link?.stop()
            self.link = nil
            self.completion()
        }
    }
}
