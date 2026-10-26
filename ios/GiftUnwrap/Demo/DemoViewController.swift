import UIKit

/// The concept end to end, as in the film: a gift message arrives → tap it → the wrapped gift
/// comes forward with a hint (a ghost finger shows the pull) → pull the ribbon → the glass
/// breaks, the collectible's backdrop and pattern fill the screen → the reveal settles into the
/// gift sheet → Show on Profile → the gift flies into the ring of collectibles around the
/// avatar, the header takes its backdrop, a toast. Tap the profile to play again.
final class DemoViewController: UIViewController {
    private var chat: DemoChatView!
    private var unwrap: GiftUnwrapView!
    private var profile: DemoProfileView!
    private let chatDim = UIView()
    private let overlay = UIView()
    private let trail = GUEffectsLayer(tint: GiftUnwrapContent.Backdrop.cobaltBlue.inner)
    private let toast = DemoToastView()
    private var link: GUDisplayLink?
    private var arrivalTime: CFTimeInterval = 0.0
    private var navTime: CFTimeInterval?
    private var flight: GUGiftFlight?
    private let content = DemoLog.time("content") { DemoContent.jingleBells() }

    /// The kit screens carry their own status bar.
    override var prefersStatusBarHidden: Bool {
        return true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        DemoLog.watchMainThread()
        DemoLog.note("viewDidLoad")
        self.view.backgroundColor = .black
        DemoLog.time("build") { self.build() }
    }

    private func build() {
        for v in self.view.subviews {
            v.removeFromSuperview()
        }
        self.unwrap?.stop()
        self.navTime = nil
        self.flight = nil
        self.trail.removeFromSuperlayer()
        self.trail.reset()

        self.chat = DemoLog.time("chat init") { DemoChatView(frame: self.view.bounds) }
        self.chat.onGiftTapped = { [weak self] in
            self?.unwrap.open()
        }
        self.view.addSubview(self.chat)

        self.unwrap = DemoLog.time("unwrap init") { GiftUnwrapView(content: self.content) }
        self.view.addSubview(self.unwrap)

        self.chatDim.backgroundColor = .black
        self.chatDim.alpha = 0.0
        self.chatDim.isUserInteractionEnabled = false
        self.view.addSubview(self.chatDim)

        self.profile = DemoLog.time("profile init") { DemoProfileView(frame: self.view.bounds) }
        self.profile.isHidden = true
        self.profile.onReplay = { [weak self] in
            self?.restart()
        }
        self.view.addSubview(self.profile)

        self.overlay.isUserInteractionEnabled = false
        self.view.addSubview(self.overlay)
        self.overlay.layer.addSublayer(self.trail)
        self.view.addSubview(self.toast)

        self.unwrap.onPrimaryAction = { [weak self] in
            self?.showOnProfile()
        }
        self.unwrap.onSecondaryAction = { [weak self] in
            self?.unwrap.playExit(flyingTo: nil) {
                self?.restart()
            }
        }
    }

    private func restart() {
        self.build()
        self.view.setNeedsLayout()
        self.view.layoutIfNeeded()
        self.start()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let b = self.view.bounds
        self.chat.frame = b
        self.chat.layoutIfNeeded()
        self.unwrap.frame = b
        self.unwrap.safeInsets = self.view.safeAreaInsets
        let k = self.chat.k
        self.unwrap.sphereCenter = CGPoint(x: 201.0 * k, y: 392.0 * k)
        self.chatDim.frame = b
        self.profile.frame = b
        self.overlay.frame = b
        self.trail.frame = b
        self.toast.kitScale = k
        self.toast.bounds = CGRect(x: 0.0, y: 0.0, width: 370.0 * k, height: 56.0 * k)
        self.toast.center = CGPoint(x: 201.0 * k, y: (726.0 + 28.0) * k)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        DemoLog.note("viewDidAppear")
        if self.link == nil {
            self.start()
        }
    }

    private func start() {
        let now = CACurrentMediaTime()
        self.arrivalTime = now + 0.45
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.57) { [weak self] in
            guard let self = self else {
                return
            }
            let started = CACurrentMediaTime()
            self.unwrap.showInMessage(center: self.chat.slotCenter, scale: self.chat.slotRadius / GiftUnwrapView.sphereRadius, animated: true)
            DemoViewController.debugLog?(String(format: "showInMessage %.0f ms", (CACurrentMediaTime() - started) * 1000.0))
        }
        if CommandLine.arguments.contains("-autoplay") {
            self.autoplay()
        }
        if self.link == nil {
            self.link = GUDisplayLink(tick: { [weak self] t in
                self?.tick(t)
            })
        }
        self.link?.start()
    }

    /// Plays the flow by itself (launch argument `-autoplay`, off in the shared scheme):
    /// for recording the demo hands-free. Tap, the glass breaks after the hint, then Show on Profile.
    /// With `-captureDir <folder>` (simulator only) it also saves a snapshot of the screen 10 times a
    /// second and a timing log there.
    private func autoplay() {
        let t0 = CACurrentMediaTime()
        let captureDir = DemoLog.dir
        func note(_ s: String) {
            DemoLog.note(s)
        }
        GiftUnwrapView.debugLog = { note($0) }
        DemoViewController.debugLog = { note($0) }
        note("autoplay start")
        let steps: [(TimeInterval, String, () -> Void)] = [
            (2.0, "tap message", { [weak self] in self?.chat.onGiftTapped?() }),
            (6.5, "snap", { [weak self] in self?.unwrap.snap() }),
            (10.5, "show on profile", { [weak self] in self?.unwrap.performPrimaryAction() })
        ]
        for (delay, name, step) in steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                note(name)
                step()
            }
        }
        guard let dir = captureDir else {
            return
        }
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        var index = 0
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self = self, CACurrentMediaTime() - t0 < 18.0 else {
                timer.invalidate()
                note("capture end")
                return
            }
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1.0
            let image = UIGraphicsImageRenderer(bounds: self.view.bounds, format: format).image { _ in
                self.view.drawHierarchy(in: self.view.bounds, afterScreenUpdates: false)
            }
            if let data = image.jpegData(compressionQuality: 0.6) {
                try? data.write(to: URL(fileURLWithPath: String(format: "%@/f_%04d.jpg", dir, index)))
            }
            index += 1
        }
    }

    // MARK: - Show on Profile

    private func showOnProfile() {
        let now = CACurrentMediaTime()
        self.navTime = now + 0.1
        self.profile.isHidden = false
        self.profile.setNeedsLayout()
        self.profile.layoutIfNeeded()

        // The gift leaves the sheet and flies above everything.
        let taken = self.unwrap.takeGiftView()
        let frame = self.unwrap.convert(taken.frame, to: self.overlay)
        taken.view.removeFromSuperview()
        self.overlay.addSubview(taken.view)
        taken.view.transform = .identity
        taken.view.frame = frame

        let duration: CFTimeInterval = 1.13
        let arrival = now + duration
        let bells = GUCollectible(name: self.content.title, frames: self.content.giftFrames ?? [], backdrop: self.content.backdrop, symbol: self.content.symbolImage)
        self.profile.orbit.prepareNewcomer(bells, arrivingAt: arrival)
        let landing = self.profile.orbit.landingPoint(arrivingAt: arrival)
        self.profile.prepareRecolor(backdrop: self.content.backdrop, symbol: self.content.symbolImage, at: arrival, from: landing.point)

        let flight = GUGiftFlight(view: taken.view, from: frame, duration: duration, target: { [weak self] t in
            guard let self = self else {
                return (CGPoint.zero, GUOrbitView.modelSize)
            }
            // The profile has the same frame as the overlay; it is only translated while sliding in.
            let landing = self.profile.orbit.landingPoint(arrivingAt: arrival)
            return (CGPoint(x: landing.point.x + self.profileOffset(t), y: landing.point.y), GUOrbitView.modelSize * landing.scale)
        }, onFrame: { [weak self] p in
            self?.trail.setTrail(at: p)
        }, completion: { [weak self, weak giftView = taken.view] in
            giftView?.removeFromSuperview()
            self?.trail.setTrail(at: nil)
        })
        self.flight = flight
        flight.start()

        let sounds = GUSounds()
        sounds.prepare()
        sounds.play(.whoosh)
        let icon = self.content.giftFrames
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            sounds.play(.land)
            sounds.play(.swell, gain: 0.8)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                sounds.play(.toast)
                self?.toast.show(frames: icon ?? [])
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                sounds.stop()
            }
        }
    }

    /// Profile slides in from the right (Telegram push: 0.62 s on the tg curve).
    private func profileOffset(_ t: CFTimeInterval) -> CGFloat {
        guard let nt = self.navTime else {
            return self.view.bounds.width
        }
        let u = GUMotion.tg(CGFloat(t - nt) / 0.62)
        return GUMotion.lerp(self.view.bounds.width, 0.0, u)
    }

    static var debugLog: ((String) -> Void)?

    private func tick(_ t: CFTimeInterval) {
        let started = CACurrentMediaTime()
        defer {
            let spent = CACurrentMediaTime() - started
            if spent > 0.05 {
                DemoViewController.debugLog?(String(format: "demo tick %.0f ms", spent * 1000.0))
            }
        }
        self.chat.update(arrival: CGFloat(t - self.arrivalTime), time: t)
        let w = self.view.bounds.width
        let px = self.profileOffset(t)
        let back = -(w - px) * 0.3
        self.chat.transform = CGAffineTransform(translationX: back, y: 0.0)
        self.unwrap.transform = CGAffineTransform(translationX: back, y: 0.0)
        self.chatDim.alpha = (1.0 - px / w) * 0.2
        self.profile.transform = CGAffineTransform(translationX: px, y: 0.0)
        self.profile.update(time: t)
        self.toast.update(time: t)
    }
}

/// Telegram's undo-overlay toast from the kit ("Jingle Bells #18 082 is now on your profile.
/// View"), above the tab bar, rising on the menu spring, with the gift's animated model as icon.
final class DemoToastView: UIView {
    private let image = UIImageView(image: DemoContent.kit("toast"))
    private let icon = UIImageView()
    private var shownAt: CFTimeInterval?
    var kitScale: CGFloat = 1.0

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.addSubview(self.image)
        self.icon.contentMode = .scaleAspectFit
        self.addSubview(self.icon)
        self.alpha = 0.0
        self.isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.image.frame = self.bounds
        let k = self.kitScale
        self.icon.frame = CGRect(x: 10.0 * k, y: 10.0 * k, width: 36.0 * k, height: 36.0 * k)
    }

    func show(frames: [UIImage]) {
        self.icon.image = frames.first
        self.icon.animationImages = frames
        self.icon.animationDuration = Double(frames.count) / 30.0
        self.icon.startAnimating()
        self.shownAt = CACurrentMediaTime()
    }

    func update(time t: CFTimeInterval) {
        guard let s = self.shownAt else {
            self.alpha = 0.0
            return
        }
        let age = CGFloat(t - s)
        let k = GUMotion.spring(age, GUMotion.menu)
        let out = GUMotion.seg(age, 2.55, 0.32, GUMotion.easeIn)
        self.alpha = GUMotion.clamp(k * 1.6) * (1.0 - out)
        let sc = 0.92 + 0.08 * GUMotion.clamp(k)
        self.transform = CGAffineTransform(translationX: 0.0, y: ((1.0 - k) * 90.0 + out * 30.0) * self.kitScale).scaledBy(x: sc, y: sc)
    }
}


/// Timing log for the hands-free run (`-autoplay -captureDir <folder>`): notes, long main-thread
/// stalls and slow layout passes, written to `<folder>/log.txt`.
enum DemoLog {
    static let enabled = CommandLine.arguments.contains("-autoplay")
    static let dir = UserDefaults.standard.string(forKey: "captureDir")
    private static let t0 = CACurrentMediaTime()
    private static var text = ""
    private static var observer: CFRunLoopObserver?
    private static var busySince: CFTimeInterval = 0.0

    static func note(_ s: String) {
        guard enabled else {
            return
        }
        text += String(format: "%.3f %@\n", CACurrentMediaTime() - t0, s)
        if let dir = dir {
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            try? text.write(toFile: dir + "/log.txt", atomically: true, encoding: .utf8)
        }
    }

    static func time<T>(_ name: String, _ body: () -> T) -> T {
        let started = CACurrentMediaTime()
        let result = body()
        let spent = CACurrentMediaTime() - started
        if spent > 0.03 {
            note(String(format: "%@ %.0f ms", name, spent * 1000.0))
        }
        return result
    }

    /// Logs every run-loop pass on the main thread that keeps it busy for more than 200 ms.
    static func watchMainThread() {
        guard enabled, observer == nil else {
            return
        }
        let activities = CFRunLoopActivity.afterWaiting.rawValue | CFRunLoopActivity.beforeWaiting.rawValue
        observer = CFRunLoopObserverCreateWithHandler(nil, activities, true, 0) { _, activity in
            let now = CACurrentMediaTime()
            if activity == .afterWaiting {
                busySince = now
            } else if busySince > 0.0, now - busySince > 0.2 {
                note(String(format: "main thread busy %.0f ms", (now - busySince) * 1000.0))
            }
        }
        CFRunLoopAddObserver(CFRunLoopGetMain(), observer, .commonModes)
    }
}
