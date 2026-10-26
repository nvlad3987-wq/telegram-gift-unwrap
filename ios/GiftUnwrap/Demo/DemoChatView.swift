import UIKit

/// The chat with Mia, from the Telegram iOS 26 kit: wallpaper, glass header, bubbles, input
/// bar. A gift message arrives (older messages slide up 260 pt on Telegram's insertion spring,
/// the card rises in); tapping the card opens the gift.
final class DemoChatView: UIView {
    private let base = UIImageView(image: DemoContent.kit("chat_base"))
    private let messages = UIImageView(image: DemoContent.kit("chat_msgs"))
    private let card = UIImageView(image: DemoContent.kit("gift_card"))
    private let cardHighlight = UIView()
    private var pressed = false
    private var releaseTime: CFTimeInterval?
    var onGiftTapped: (() -> Void)?

    /// Card frame and sticker slot on the kit screen (pt).
    private static let cardFrame = CGRect(x: 86.0, y: 544.0, width: 230.0, height: 242.0)
    private static let slot = CGPoint(x: 201.5, y: 617.0)
    private static let slotRadius: CGFloat = 42.0

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = .black
        for v in [self.base, self.messages] {
            v.contentMode = .scaleToFill
            self.addSubview(v)
        }
        self.card.isUserInteractionEnabled = true
        self.cardHighlight.backgroundColor = UIColor.black.withAlphaComponent(0.14)
        self.cardHighlight.layer.cornerRadius = 26.0
        self.cardHighlight.alpha = 0.0
        self.card.addSubview(self.cardHighlight)
        self.addSubview(self.card)
        let press = UILongPressGestureRecognizer(target: self, action: #selector(self.handlePress(_:)))
        press.minimumPressDuration = 0.0
        self.card.addGestureRecognizer(press)
        self.card.alpha = 0.0
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Points per kit point.
    var k: CGFloat {
        return self.bounds.width / DemoContent.kitWidth
    }

    var slotCenter: CGPoint {
        return CGPoint(x: DemoChatView.slot.x * self.k, y: DemoChatView.slot.y * self.k)
    }

    var slotRadius: CGFloat {
        return DemoChatView.slotRadius * self.k
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let k = self.k
        let h = 874.0 * k
        self.base.frame = CGRect(x: 0.0, y: 0.0, width: self.bounds.width, height: h)
        self.messages.bounds = CGRect(x: 0.0, y: 0.0, width: self.bounds.width, height: h)
        self.messages.center = CGPoint(x: self.bounds.midX, y: h / 2.0)
        let f = DemoChatView.cardFrame
        self.card.bounds = CGRect(x: 0.0, y: 0.0, width: f.width * k, height: f.height * k)
        // anchored at the bottom centre, like a message that rises in
        self.card.layer.anchorPoint = CGPoint(x: 0.5, y: 1.0)
        self.card.center = CGPoint(x: f.midX * k, y: f.maxY * k)
        self.cardHighlight.frame = self.card.bounds
    }

    @objc private func handlePress(_ g: UILongPressGestureRecognizer) {
        switch g.state {
        case .began:
            self.pressed = true
            self.releaseTime = nil
        case .ended:
            self.pressed = false
            self.releaseTime = CACurrentMediaTime()
            if self.card.bounds.contains(g.location(in: self.card)) {
                self.onGiftTapped?()
            }
        case .cancelled, .failed:
            self.pressed = false
            self.releaseTime = CACurrentMediaTime()
        default:
            break
        }
    }

    /// `t` = seconds since the gift message started arriving.
    func update(arrival t: CGFloat, time: CFTimeInterval) {
        let k = self.k
        let ins = GUMotion.spring(t, GUMotion.menu)
        let cin = GUMotion.spring(t - 0.04, GUMotion.menu)
        var press: CGFloat = 1.0
        var hi: CGFloat = 0.0
        if self.pressed {
            press = 0.965
            hi = 1.0
        } else if let r = self.releaseTime {
            let a = CGFloat(time - r)
            press = GUMotion.lerp(0.965, 1.0, GUMotion.spring(a, GUMotion.bounce))
            hi = 1.0 - GUMotion.clamp(a / 0.25)
        }
        guWithoutAnimation {
            self.messages.transform = CGAffineTransform(translationX: 0.0, y: -260.0 * k * ins)
            let s = (0.86 + 0.14 * GUMotion.clamp(cin)) * press
            self.card.transform = CGAffineTransform(translationX: 0.0, y: (1.0 - cin) * 260.0 * k).scaledBy(x: s, y: s)
            self.card.alpha = GUMotion.clamp(cin * 1.4)
            self.cardHighlight.alpha = hi
        }
    }
}
