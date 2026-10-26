import UIKit

/// Alex's own profile (Settings) from the Telegram iOS 26 kit. The header is live — profile
/// colour, the collectible backdrop that takes over, and the ring of collectibles around the
/// avatar — under the kit's foreground (QR / Edit glass buttons, name, list, tab bar).
final class DemoProfileView: UIView {
    private let header = UIView()
    private let headerGradient = CAGradientLayer()
    private var collectibleHeader: GUPatternView?
    private let avatar = UIImageView(image: DemoContent.kit("avatar_ar"))
    private let avatarRing = CAShapeLayer()
    private let foreground = UIImageView(image: DemoContent.kit("profile_fg"))
    let orbit = GUOrbitView(collectibles: DemoContent.profileCollectibles())
    private var recolorTime: CFTimeInterval?
    private var recolorOrigin: CGPoint = .zero
    var onReplay: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = UIColor(guRGB: 0xf2f2f7)
        self.clipsToBounds = true
        self.headerGradient.type = .radial
        self.headerGradient.colors = [UIColor(guRGB: 0xa98bff).cgColor, UIColor(guRGB: 0x6c4bd8).cgColor]
        self.header.layer.addSublayer(self.headerGradient)
        self.header.clipsToBounds = true
        self.addSubview(self.header)
        self.addSubview(self.avatar)
        self.avatarRing.fillColor = nil
        self.avatarRing.strokeColor = UIColor.white.cgColor
        self.avatarRing.lineWidth = 2.5
        self.avatarRing.opacity = 0.0
        self.layer.addSublayer(self.avatarRing)
        self.orbit.install(around: self.avatar)
        self.foreground.contentMode = .scaleToFill
        self.addSubview(self.foreground)
        self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.replay)))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func replay() {
        self.onReplay?()
    }

    var k: CGFloat {
        return self.bounds.width / DemoContent.kitWidth
    }

    var avatarCenter: CGPoint {
        return CGPoint(x: 201.0 * self.k, y: 142.0 * self.k)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let b = self.bounds
        let k = self.k
        let headerHeight = 268.0 * k
        self.header.frame = CGRect(x: 0.0, y: 0.0, width: b.width, height: headerHeight)
        let c = self.avatarCenter
        guWithoutAnimation {
            self.headerGradient.frame = self.header.bounds
            self.headerGradient.startPoint = CGPoint(x: c.x / b.width, y: c.y / headerHeight)
            self.headerGradient.endPoint = CGPoint(x: (c.x + 330.0 * k) / b.width, y: (c.y + 330.0 * k) / headerHeight)
        }
        self.collectibleHeader?.frame = self.header.bounds
        self.avatar.bounds = CGRect(x: 0.0, y: 0.0, width: 104.0 * k, height: 104.0 * k)
        self.avatar.center = c
        self.orbit.avatarCenter = c
        self.orbit.layout(frame: b)
        self.foreground.frame = CGRect(x: 0.0, y: 0.0, width: b.width, height: 874.0 * k)
    }

    /// The header takes the collectible's colours when it lands at `time`, spreading from where it lands.
    func prepareRecolor(backdrop: GiftUnwrapContent.Backdrop, symbol: UIImage?, at time: CFTimeInterval, from origin: CGPoint) {
        let view = GUPatternView(backdrop: backdrop, symbol: symbol)
        view.gradientRadius = 300.0
        view.patternScale = 0.78
        view.symbolAlpha = 0.5
        view.holeRadius = 92.0
        self.header.addSubview(view)
        self.collectibleHeader = view
        self.recolorTime = time
        self.recolorOrigin = origin
        self.setNeedsLayout()
        self.layoutIfNeeded()
    }

    func update(time t: CFTimeInterval) {
        self.orbit.update(time: t)
        guard let rt = self.recolorTime, let view = self.collectibleHeader else {
            return
        }
        let age = CGFloat(t - rt)
        let r = 620.0 * GUMotion.bezier(0.25, 0.75, 0.3, 1.0, (age + 0.03) / 0.85)
        view.patternCenter = self.avatarCenter
        view.setReveal(center: self.recolorOrigin, radius: age > -0.03 ? r : 0.0)
        view.update(age: age, waveOrigin: self.recolorOrigin, speed: 700.0)
        // Avatar pulse.
        let pulse: CGFloat = age > 0.0 ? exp(-age * 2.4) : 0.0
        let s = 1.0 + 0.035 * pulse
        self.avatar.transform = CGAffineTransform(scaleX: s, y: s)
        guWithoutAnimation {
            let rr = 52.0 * self.k + 6.0 + 16.0 * (1.0 - pulse)
            self.avatarRing.path = UIBezierPath(arcCenter: self.avatarCenter, radius: rr, startAngle: 0.0, endAngle: 2.0 * .pi, clockwise: true).cgPath
            self.avatarRing.opacity = Float(pulse * 0.6)
        }
    }
}
