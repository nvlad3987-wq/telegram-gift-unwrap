import UIKit
import SceneKit

/// The whole unwrap in one full-screen, transparent view (same behaviour as the Android
/// `GiftUnwrapView`):
///
/// 1. **In the message** — `showInMessage(center:scale:)` puts the wrapped gift (a glass sphere
///    tied with a ribbon in the backdrop's colours, the animated model inside) into the gift
///    message's sticker slot. Touches go to the chat.
/// 2. **Open** — the message was tapped: `open()` brings the gift forward, the chat dims.
/// 3. **Hint** — "Pull the ribbon to unwrap", a pulse on the tab and a ghost finger that shows
///    the gesture until the person touches it.
/// 4. **Pull** — the tail follows the finger 1:1; the glass stretches, trembles, cracks. Let go
///    early and it springs back; a flick that would carry past the end breaks it.
/// 5. **Snap** — shards, flash, the backdrop floods the screen and its pattern fills it, the
///    model springs out.
/// 6. **Sheet** — the reveal condenses into Telegram's gift sheet (header on the backdrop,
///    attribute table, "Show on Profile").
///
/// The view does not navigate anywhere itself: `onPrimaryAction` / `onSecondaryAction` tell
/// the host, and `takeGiftView()` hands the gift over for a flight to the profile.
public final class GiftUnwrapView: UIView, UIGestureRecognizerDelegate {
    public enum Phase {
        case wrapped
        case pulling
        case snapped
        case leaving
    }

    public static let sphereRadius: CGFloat = 88.0
    /// Seconds after the snap when the reveal condenses into the sheet.
    static let condenseDelay: CGFloat = 1.2

    public let content: GiftUnwrapContent
    public private(set) var phase: Phase = .wrapped

    /// Centre of the sphere once it is in front of the chat, in this view's coordinates.
    public var sphereCenter: CGPoint = CGPoint(x: 201.0, y: 392.0)
    /// Safe area of the screen this view covers.
    public var safeInsets: UIEdgeInsets = .zero {
        didSet { self.setNeedsLayout() }
    }

    /// "Show on Profile".
    /// Optional timing log (the demo's autoplay uses it to find slow frames).
    public static var debugLog: ((String) -> Void)?

    public var onPrimaryAction: (() -> Void)?
    /// The sheet's close button: keep the gift private.
    public var onSecondaryAction: (() -> Void)?
    /// Called once, on the frame the glass breaks.
    public var onSnap: (() -> Void)?

    public var soundsEnabled: Bool = true {
        didSet { self.sounds.isEnabled = self.soundsEnabled }
    }
    public var hapticsEnabled: Bool = true {
        didSet { self.haptics.isEnabled = self.hapticsEnabled }
    }

    // MARK: Subviews

    private let scrim = UIView()
    private let backdrop: GUPatternView
    private let effects: GUEffectsLayer
    private let effectsBackView = UIView()
    private let effectsFrontView = UIView()
    private let giftContainer = UIView()
    private let haze = CAGradientLayer()
    public let giftView: UIView
    private let glass: GUGlassScene
    private let ribbonView = UIView()
    private let ribbon = GURibbonTailLayer()
    private let cracks = GUCrackLayer()
    private let sheet: GUGiftSheetView
    private let hintView = UIView()
    private let hintCapsule = UILabel()
    private let hintRing = CAShapeLayer()
    private let ghost = UIView()
    private let guide = CAShapeLayer()
    private let haptics = GUHaptics()
    private let sounds = GUSounds()
    private var displayLink: GUDisplayLink?

    // MARK: Timeline state

    private var started = false
    private var openTime: CFTimeInterval = .greatestFiniteMagnitude
    private var origin: CGPoint = .zero
    private var originScale: CGFloat = 1.0
    private var arrivalTime: CFTimeInterval = 0.0
    private var jellyTime: CFTimeInterval = -100.0
    private var now: CFTimeInterval = 0.0
    private var touchedOnce = false

    private var tension: CGFloat = 0.0
    private var tailOffset: CGPoint = .zero
    private var grabOffset: CGPoint = .zero
    private var lastHapticStep = 0
    private var crackStarted = false

    private var releaseTime: CFTimeInterval?
    private var releaseTension: CGFloat = 0.0
    private var releaseTailOffset: CGPoint = .zero
    private var autoSnapFrom: (time: CFTimeInterval, tension: CGFloat, offset: CGPoint)?

    private var snapTime: CFTimeInterval = 0.0
    private var snapCenter: CGPoint = .zero
    private var snapScale: CGFloat = 1.0
    private var snapKnot: CGPoint = .zero
    private var snapTail: CGPoint = .zero
    private var snapLeftTail: CGPoint = .zero
    private var leaveTime: CFTimeInterval?
    private var giftTaken = false
    private var exit: (time: CFTimeInterval, target: CGPoint?, completion: () -> Void)?
    private var exitCompleted = false
    private var firedEvents = Set<String>()
    private var sheetFrame: CGRect = .zero

    /// Pull geometry (points, at sphere scale 1): where the tab rests and which way it is
    /// pulled until the glass breaks.
    private let k = GiftUnwrapView.sphereRadius / 74.0
    private var tailRestOffset: CGPoint { return CGPoint(x: 45.0, y: 102.0) * self.k }
    private var pullVector: CGPoint { return CGPoint(x: 16.0, y: 122.0) * self.k }
    /// The second tail hangs down and to the left, clear of the glass, so both tails of the bow
    /// read as ribbon ends (not one disappearing into the sphere).
    private var leftRestOffset: CGPoint { return CGPoint(x: -25.0, y: 143.0) * self.k }
    private let ghostDistance: CGFloat = 74.0
    private let ghostStart: CGFloat = 0.95
    private let ghostCycle: CGFloat = 4.2

    public init(content: GiftUnwrapContent) {
        self.content = content
        self.backdrop = GUPatternView(backdrop: content.backdrop, symbol: content.symbolImage, makeSymbolLayer: content.makeSymbolLayer)
        self.effects = GUEffectsLayer(tint: content.backdrop.inner)
        self.giftView = content.makeModelView()
        self.glass = GUGlassScene(radius: GiftUnwrapView.sphereRadius)
        self.sheet = GUGiftSheetView(content: content)
        super.init(frame: .zero)

        self.backgroundColor = .clear
        self.scrim.backgroundColor = .black
        self.scrim.alpha = 0.0
        self.scrim.isUserInteractionEnabled = false
        self.addSubview(self.scrim)
        self.addSubview(self.backdrop)
        self.effectsBackView.isUserInteractionEnabled = false
        self.effectsBackView.layer.addSublayer(self.effects.backLayer)
        self.addSubview(self.effectsBackView)
        self.giftContainer.isUserInteractionEnabled = false
        self.haze.type = .radial
        self.haze.colors = [content.backdrop.inner.withAlphaComponent(0.6).cgColor, content.backdrop.outer.withAlphaComponent(0.0).cgColor]
        self.haze.startPoint = CGPoint(x: 0.5, y: 0.5)
        self.haze.endPoint = CGPoint(x: 1.0, y: 1.0)
        self.giftContainer.layer.addSublayer(self.haze)
        self.giftContainer.addSubview(self.giftView)
        self.addSubview(self.giftContainer)
        self.addSubview(self.sheet)
        self.glassHost.isUserInteractionEnabled = false
        self.addSubview(self.glassHost)
        self.ribbonView.isUserInteractionEnabled = false
        self.ribbonView.layer.addSublayer(self.cracks)
        self.ribbonView.layer.addSublayer(self.ribbon)
        self.addSubview(self.ribbonView)
        self.effectsFrontView.isUserInteractionEnabled = false
        self.effectsFrontView.layer.addSublayer(self.effects)
        self.addSubview(self.effectsFrontView)

        // Hint: capsule, pulse ring on the tab, ghost finger and its dotted guide.
        self.hintView.isUserInteractionEnabled = false
        self.hintCapsule.text = content.hint
        self.hintCapsule.font = UIFont.systemFont(ofSize: 15.0, weight: .medium)
        self.hintCapsule.textColor = .white
        self.hintCapsule.textAlignment = .center
        self.hintCapsule.backgroundColor = UIColor.black.withAlphaComponent(0.32)
        self.hintCapsule.layer.cornerRadius = 18.0
        self.hintCapsule.clipsToBounds = true
        self.hintView.addSubview(self.hintCapsule)
        self.hintRing.fillColor = nil
        self.hintRing.strokeColor = UIColor.white.cgColor
        self.hintRing.lineWidth = 2.0
        self.hintView.layer.addSublayer(self.hintRing)
        self.guide.fillColor = nil
        self.guide.strokeColor = UIColor.white.withAlphaComponent(0.85).cgColor
        self.guide.lineWidth = 2.2
        self.guide.lineCap = .round
        self.guide.lineJoin = .round
        self.hintView.layer.addSublayer(self.guide)
        self.ghost.backgroundColor = UIColor.white.withAlphaComponent(0.34)
        self.ghost.layer.borderColor = UIColor.white.withAlphaComponent(0.55).cgColor
        self.ghost.layer.borderWidth = 1.0
        self.ghost.layer.cornerRadius = 21.0
        self.ghost.bounds = CGRect(x: 0.0, y: 0.0, width: 42.0, height: 42.0)
        self.hintView.addSubview(self.ghost)
        self.addSubview(self.hintView)

        // Nothing shows until showInMessage / start.
        self.sheet.isHidden = true
        self.hintView.isHidden = true
        self.giftView.alpha = 0.0
        self.haze.opacity = 0.0

        let rib = content.backdrop.ribbon
        self.glass.setRibbonColor(base: rib.base, dark: rib.dark)
        self.ribbon.setColors(base: rib.base, light: rib.light, dark: rib.dark)

        // Cracks start at the knot: its direction projected on the screen (y down).
        let kd = self.glass.knotDirection
        self.cracks.generate(origin: CGPoint(x: CGFloat(kd.x), y: CGFloat(-kd.y)))

        let pan = UIPanGestureRecognizer(target: self, action: #selector(self.handlePan(_:)))
        pan.delegate = self
        pan.maximumNumberOfTouches = 1
        self.addGestureRecognizer(pan)
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.handleTap(_:)))
        tap.delegate = self
        self.addGestureRecognizer(tap)

        self.sheet.primaryButton.onTap = { [weak self] in
            self?.primaryTapped()
        }
        self.sheet.onClose = { [weak self] in
            self?.secondaryTapped()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.displayLink?.stop()
    }

    // MARK: - Public

    /// Puts the wrapped gift into the gift message: `center` = centre of the message's sticker
    /// slot, `scale` = slot sphere radius / `sphereRadius`. Touches pass through until `open()`.
    public func showInMessage(center: CGPoint, scale: CGFloat, animated: Bool = true) {
        self.prepare()
        let t = CACurrentMediaTime()
        self.origin = center
        self.originScale = scale
        self.openTime = .greatestFiniteMagnitude
        self.arrivalTime = animated ? t : t - 10.0
        self.phase = .wrapped
        if animated {
            self.sounds.play(.arrive)
        }
        self.tick(t)
    }

    /// The gift message was tapped: the gift comes forward, the chat dims, the hint starts.
    public func open() {
        guard !self.isOpen else {
            return
        }
        self.openTime = CACurrentMediaTime()
        self.haptics.tap()
        self.sounds.play(.whoosh, gain: 0.5)
    }

    /// `showInMessage` + `open` in one go (the Telegram adapter: the message was just tapped).
    public func start(from center: CGPoint, scale: CGFloat) {
        self.showInMessage(center: center, scale: scale, animated: false)
        self.open()
    }

    public var isOpen: Bool {
        return self.openTime < .greatestFiniteMagnitude / 2.0
    }

    /// Breaks the glass without a gesture (e.g. for an accessibility action or a demo autoplay).
    public func snap() {
        guard self.phase == .wrapped || self.phase == .pulling else {
            return
        }
        self.performSnap(at: CACurrentMediaTime())
    }

    /// Presses Show on Profile without a touch (accessibility action, demo autoplay).
    public func performPrimaryAction() {
        self.primaryTapped()
    }

    /// Hands the gift view to the host (for a flight to the profile) with its current frame in
    /// this view's coordinates; the sheet drops away.
    public func takeGiftView() -> (view: UIView, frame: CGRect) {
        self.giftTaken = true
        if self.leaveTime == nil {
            self.leaveTime = CACurrentMediaTime()
        }
        let frame = self.giftContainer.convert(self.giftView.frame, to: self)
        return (self.giftView, frame)
    }

    /// Drops the sheet and flies the gift to `target` (or lets it shrink away), then `completion`.
    public func playExit(flyingTo target: CGPoint?, completion: @escaping () -> Void) {
        if self.leaveTime == nil {
            self.leaveTime = CACurrentMediaTime()
        }
        self.phase = .leaving
        self.exit = (CACurrentMediaTime(), target, completion)
    }

    /// Stops the display link (call when the screen goes away).
    public func stop() {
        self.displayLink?.stop()
        self.sounds.stop()
    }

    /// Holds the glass's SCNView in the view order; the view joins once its shaders are built.
    private let glassHost = UIView()

    private func installGlassIfReady() {
        if self.glass.view.superview == nil && self.glass.isPrepared {
            self.glass.view.frame = self.glassHost.bounds
            self.glassHost.addSubview(self.glass.view)
        }
    }

    private func prepare() {
        let started = CACurrentMediaTime()
        defer {
            GiftUnwrapView.debugLog?(String(format: "unwrap prepare %.0f ms", (CACurrentMediaTime() - started) * 1000.0))
        }
        self.haptics.prepare()
        if self.soundsEnabled {
            self.sounds.prepare()
        }
        self.started = true
        if self.displayLink == nil {
            self.displayLink = GUDisplayLink(tick: { [weak self] time in
                self?.tick(time)
            })
        }
        self.displayLink?.start()
    }

    // MARK: - Layout

    public override func layoutSubviews() {
        super.layoutSubviews()
        let b = self.bounds
        for v in [self.scrim, self.backdrop, self.effectsBackView, self.effectsFrontView, self.giftContainer, self.glassHost, self.glass.view, self.ribbonView, self.hintView] {
            v.frame = b
        }
        self.glass.layout(size: b.size)
        let bodyH = self.sheet.bodyHeight
        let bottom = b.height - 6.0   // iOS 26 sheets float 6 pt above the bottom edge
        let headerH = max(250.0, min(GUGiftSheetView.headerHeight, bottom - bodyH - self.safeInsets.top - 40.0))
        self.sheetFrame = CGRect(x: 6.0, y: bottom - bodyH - headerH, width: b.width - 12.0, height: headerH + bodyH)
        self.sheet.bounds = CGRect(origin: .zero, size: self.sheetFrame.size)
        self.sheet.center = CGPoint(x: self.sheetFrame.midX, y: self.sheetFrame.midY)
        self.tick(self.now > 0.0 ? self.now : CACurrentMediaTime())
    }

    // MARK: - Hit testing

    public override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        switch self.phase {
        case .wrapped, .pulling:
            return self.isOpen   // in the message the chat gets the touches; opened, the dimmed chat is not interactive
        case .snapped:
            return true
        case .leaving:
            return false
        }
    }

    public override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard self.isOpen, self.openK(self.now) > 0.85 else {
            return false
        }
        if gestureRecognizer is UIPanGestureRecognizer {
            guard self.phase == .wrapped else {
                return false
            }
            let p = gestureRecognizer.location(in: self)
            return (p - self.currentTailEnd()).length < 48.0
        }
        if gestureRecognizer is UITapGestureRecognizer {
            return self.phase == .wrapped
        }
        return true
    }

    // MARK: - Gestures

    @objc private func handleTap(_ g: UITapGestureRecognizer) {
        let p = g.location(in: self)
        if (p - self.sphereCenter).length < GiftUnwrapView.sphereRadius + 8.0 {
            self.jellyTime = CACurrentMediaTime()
            self.haptics.tick()
        }
    }

    @objc private func handlePan(_ g: UIPanGestureRecognizer) {
        let t = CACurrentMediaTime()
        let p = g.location(in: self)
        let s = self.currentSphereScale()
        let rest = self.currentCenter() + self.tailRestOffset * s
        let pullLength = self.pullVector.length * s
        let pullUnit = self.pullVector * (1.0 / self.pullVector.length)

        switch g.state {
        case .began:
            self.touchedOnce = true
            self.phase = .pulling
            self.releaseTime = nil
            self.grabOffset = self.currentTailEnd() - p
            self.lastHapticStep = Int(self.tension * 10.0)
            self.haptics.prepare()
            self.haptics.tick()
        case .changed:
            let target = p + self.grabOffset
            let v = target - rest
            var along = v.x * pullUnit.x + v.y * pullUnit.y
            let perp = v - pullUnit * along
            let perpLength = perp.length
            let perpDir = perpLength > 0.001 ? perp * (1.0 / perpLength) : .zero
            let softPerp = GUMotion.rubberBand(perpLength, dimension: 90.0)
            if along < 0.0 {
                along = -GUMotion.rubberBand(-along, dimension: 60.0)
            }
            self.tailOffset = pullUnit * along + perpDir * softPerp
            self.setTension(max(0.0, along / pullLength), at: t)
        case .ended, .cancelled, .failed:
            let velocity = g.velocity(in: self)
            let vAlong = velocity.x * pullUnit.x + velocity.y * pullUnit.y
            // Apple's momentum projection: where would the tab come to rest?
            let projected = (vAlong / 1000.0) * 0.99 / (1.0 - 0.99)
            let along = self.tailOffset.x * pullUnit.x + self.tailOffset.y * pullUnit.y
            if g.state == .ended && (along + projected) / pullLength >= 1.0 && self.phase == .pulling {
                self.autoSnapFrom = (t, self.tension, self.tailOffset)
            } else if self.phase == .pulling {
                self.phase = .wrapped
                self.releaseTime = t
                self.releaseTension = self.tension
                self.releaseTailOffset = self.tailOffset
                self.jellyTime = t
                self.crackStarted = false
            }
        default:
            break
        }
    }

    private func setTension(_ value: CGFloat, at t: CFTimeInterval) {
        self.tension = min(1.0, value)
        let step = Int(self.tension * 10.0)
        if step > self.lastHapticStep {
            self.haptics.tension(self.tension)
            self.sounds.play(.creak, gain: Float(0.3 + 0.7 * self.tension))
        }
        self.lastHapticStep = step
        if self.tension >= 0.86 && !self.crackStarted {
            self.crackStarted = true
            self.haptics.crackle()
            self.sounds.play(.crackle)
        }
        if value >= 1.0 {
            self.performSnap(at: t)
        }
    }

    private func primaryTapped() {
        guard self.phase == .snapped else {
            return
        }
        self.haptics.tap()
        self.sounds.play(.tap)
        self.phase = .leaving
        self.onPrimaryAction?()
    }

    private func secondaryTapped() {
        guard self.phase == .snapped else {
            return
        }
        self.haptics.tap()
        self.onSecondaryAction?()
    }

    // MARK: - Snap

    private func performSnap(at t: CFTimeInterval) {
        guard self.phase != .snapped && self.phase != .leaving else {
            return
        }
        self.phase = .snapped
        self.snapTime = t
        self.snapScale = self.currentSphereScale()
        self.snapCenter = self.currentCenter()
        self.snapKnot = self.glass.knotPoint()
        self.snapTail = self.currentTailEnd()
        self.snapLeftTail = self.snapCenter + (self.leftRestOffset + CGPoint(x: 0.0, y: 10.0)) * self.snapScale
        self.autoSnapFrom = nil
        self.haptics.shatter()
        self.sounds.play(.shatter)
        self.onSnap?()
    }

    // MARK: - Frame

    private func openK(_ time: CFTimeInterval) -> CGFloat {
        guard self.isOpen else {
            return 0.0
        }
        return GUMotion.spring(CGFloat(time - self.openTime), GUMotion.menu)
    }

    private func currentSphereScale() -> CGFloat {
        let pop = GUMotion.lerp(0.25, 1.0, GUMotion.spring(CGFloat(self.now - self.arrivalTime), GUMotion.bounce))
        return GUMotion.lerp(self.originScale, 1.0, self.openK(self.now)) * pop
    }

    private func currentCenter() -> CGPoint {
        return GUMotion.lerp(self.origin, self.sphereCenter, self.openK(self.now))
    }

    private func currentTailEnd() -> CGPoint {
        return self.currentCenter() + self.tailRestOffset * self.currentSphereScale() + self.tailOffset
    }

    /// Ghost pull distance (≥ 0), or nil when no ghost is shown.
    private func ghostPull(_ t: CGFloat) -> CGFloat? {
        guard !self.touchedOnce, self.phase == .wrapped, self.releaseTime == nil, self.isOpen else {
            return nil
        }
        let idle = t - CGFloat(self.openTime) - self.ghostStart
        guard idle >= 0.0 else {
            return nil
        }
        let c = idle.truncatingRemainder(dividingBy: self.ghostCycle)
        guard c <= 1.25 else {
            return nil
        }
        return self.ghostDistance * GUMotion.easeInOut(GUMotion.clamp((c - 0.22) / 0.5))
    }

    private func ghostRelease(_ t: CGFloat) -> CGFloat {
        guard !self.touchedOnce, self.phase == .wrapped, self.isOpen else {
            return 0.0
        }
        let idle = t - CGFloat(self.openTime) - self.ghostStart
        guard idle >= 0.0 else {
            return 0.0
        }
        let c = idle.truncatingRemainder(dividingBy: self.ghostCycle)
        return c < 0.9 ? 0.0 : self.ghostDistance * (1.0 - GUMotion.spring(c - 0.9, GUMotion.bounce))
    }

    private func once(_ id: String, _ condition: Bool, _ body: () -> Void) {
        if condition && !self.firedEvents.contains(id) {
            self.firedEvents.insert(id)
            body()
        }
    }

    private func tick(_ time: CFTimeInterval) {
        let started = CACurrentMediaTime()
        defer {
            let spent = CACurrentMediaTime() - started
            if spent > 0.05 {
                GiftUnwrapView.debugLog?(String(format: "unwrap tick %.0f ms phase %@", spent * 1000.0, String(describing: self.phase)))
            }
        }
        self.now = time
        let t = CGFloat(time)
        if self.bounds.width <= 0.0 || !self.started {
            return
        }
        if let rt = self.releaseTime, self.phase == .wrapped {
            let k = GUMotion.spring(CGFloat(time - rt), GUMotion.bounce)
            self.tension = max(0.0, self.releaseTension * (1.0 - k))
            self.tailOffset = self.releaseTailOffset * (1.0 - k)
            if time - rt > 1.2 {
                self.releaseTime = nil
                self.tension = 0.0
                self.tailOffset = .zero
            }
            self.lastHapticStep = Int(self.tension * 10.0)
        }
        if let from = self.autoSnapFrom, self.phase == .pulling {
            let u = GUMotion.clamp(CGFloat(time - from.time) / 0.12)
            let pullUnit = self.pullVector * (1.0 / self.pullVector.length)
            let targetOffset = pullUnit * (self.pullVector.length * self.currentSphereScale())
            self.tailOffset = GUMotion.lerp(from.offset, targetOffset, u)
            self.setTension(GUMotion.lerp(from.tension, 1.0001, u), at: time)
        }

        switch self.phase {
        case .wrapped, .pulling:
            self.renderWrapped(t)
        case .snapped, .leaving:
            self.renderSnapped(t)
        }
    }

    private func leaveK() -> CGFloat {
        guard let lt = self.leaveTime else {
            return 0.0
        }
        return GUMotion.easeIn(GUMotion.clamp(CGFloat(self.now - lt) / 0.42))
    }

    private func renderWrapped(_ t: CGFloat) {
        let ta = t - CGFloat(self.arrivalTime)
        let alpha = GUMotion.clamp(ta / 0.12)
        let scale = self.currentSphereScale()
        let center = self.currentCenter()
        let open = self.isOpen ? GUMotion.easeInOut(GUMotion.clamp((t - CGFloat(self.openTime)) / 0.45)) : 0.0
        self.scrim.alpha = 0.42 * open

        // Jelly: on arrival, when it comes forward, on a tap, when the ribbon is let go.
        var wob: CGFloat = 0.0
        let ua = ta - 0.12
        if ua > 0.0 {
            wob += 0.075 * exp(-ua * 4.2) * sin(ua * 2.0 * .pi * 3.1)
        }
        if self.isOpen {
            let uo = t - CGFloat(self.openTime) - 0.25
            if uo > 0.0 && uo < 2.0 {
                wob += 0.05 * exp(-uo * 4.5) * sin(uo * 2.0 * .pi * 2.8)
            }
        }
        let uj = t - CGFloat(self.jellyTime)
        if uj > 0.0 && uj < 2.0 {
            wob += 0.06 * exp(-uj * 4.2) * sin(uj * 2.0 * .pi * 3.1)
        }
        let breath = self.phase == .wrapped ? 0.012 * sin(t * 2.6) : 0.0
        let wobble = CGSize(width: 1.0 + wob - breath, height: 1.0 - wob + breath)
        let trembleAmp = 2.2 * pow(GUMotion.clamp((self.tension - 0.55) / 0.45), 2.5)
        let tremble = CGPoint(x: sin(t * 83.0) * trembleAmp, y: cos(t * 97.0) * trembleAmp)

        // The ghost finger moves the tail (drawing only).
        let pullUnit = self.pullVector * (1.0 / self.pullVector.length)
        let ghost = self.ghostPull(t)
        let ghostOffset = ghost ?? self.ghostRelease(t)
        let ten = max(self.tension, ghostOffset / (self.pullVector.length * scale) * 0.6)

        self.installGlassIfReady()
        if self.glass.isPrepared {
            self.glass.setWrapped(center: center, scale: max(0.001, scale), wobble: wobble, tremble: tremble, alpha: alpha)
            self.glass.setTension(ten, untie: ten)
            self.glass.setBandsReleased(age: -1.0)
            self.glass.updateShards(age: -1.0, origin: center, scale: scale)
        }

        // The model inside the glass, in a haze of its backdrop.
        let giftCenter = center + CGPoint(x: 0.0, y: -4.0) * scale + pullUnit * (ten * 6.0) + tremble
        let giftSize = 112.0 * self.k * scale
        guWithoutAnimation {
            self.giftView.bounds = CGRect(x: 0.0, y: 0.0, width: giftSize, height: giftSize)
            self.giftView.center = giftCenter
            self.giftView.transform = CGAffineTransform(rotationAngle: sin(t * 1.5) * 0.07)
            self.giftView.alpha = alpha * 0.92
            let hr = GiftUnwrapView.sphereRadius * scale * 0.85
            self.haze.frame = CGRect(x: center.x - hr, y: center.y - hr, width: hr * 2.0, height: hr * 2.0)
            self.haze.opacity = Float(alpha)
        }

        // Ribbon tails.
        let knot = self.glass.knotPoint()
        let sway = self.phase == .wrapped ? CGPoint(x: sin(t * 2.1) * 2.0, y: sin(t * 1.6) * 1.5) : .zero
        let end = center + self.tailRestOffset * scale + self.tailOffset + sway + pullUnit * ghostOffset
        let leftEnd = center + (self.leftRestOffset + CGPoint(x: sin(t * 1.7) * 1.5, y: ten * 10.0)) * scale
        self.ribbon.update(knot: knot, end: end, leftEnd: leftEnd, sag: 10.0 * (1.0 - ten), alpha: alpha, hintPhase: nil)

        let outline = self.glass.outline()
        let crack = GUMotion.clamp((self.tension - 0.86) / 0.14)
        self.cracks.update(center: outline.center, radius: outline.radius, progress: crack, alpha: crack > 0.0 ? 1.0 : 0.0)

        self.backdrop.setReveal(path: nil)
        self.sheet.isHidden = true
        self.effects.update(age: -1.0, center: center, giftCenter: giftCenter, giftSize: giftSize, idleAlpha: 0.0, time: t)
        self.renderHint(t, center: center, scale: scale, pullUnit: pullUnit, ghost: ghost)
    }

    /// "Pull the ribbon to unwrap", the pulse on the tab and the ghost finger with its guide.
    private func renderHint(_ t: CGFloat, center: CGPoint, scale: CGFloat, pullUnit: CGPoint, ghost: CGFloat?) {
        guWithoutAnimation {
            let shown = self.isOpen ? GUMotion.tg(GUMotion.clamp((t - CGFloat(self.openTime) - 0.55) / 0.3)) : 0.0
            let a = shown * (self.touchedOnce ? 0.0 : 1.0)
            self.hintView.isHidden = a <= 0.003
            if self.hintView.isHidden {
                return
            }
            let rest = center + self.tailRestOffset * scale
            let size = self.hintCapsule.sizeThatFits(CGSize(width: 400.0, height: 36.0))
            self.hintCapsule.bounds = CGRect(x: 0.0, y: 0.0, width: size.width + 32.0, height: 36.0)
            self.hintCapsule.center = CGPoint(x: center.x, y: center.y - GiftUnwrapView.sphereRadius * scale - 52.0 + (1.0 - shown) * 10.0)
            self.hintCapsule.alpha = a
            // pulse on the tab
            let idle = t - CGFloat(self.openTime) - 0.65
            let ghostNear = ghost != nil || self.ghostRelease(t) > 1.0
            if idle > 0.0 && !ghostNear {
                let p = idle.truncatingRemainder(dividingBy: 1.3) / 0.9
                let r = 20.0 * (0.7 + 0.6 * min(1.0, p))
                self.hintRing.path = UIBezierPath(ovalIn: CGRect(x: rest.x - r, y: rest.y - r, width: r * 2.0, height: r * 2.0)).cgPath
                self.hintRing.opacity = p <= 1.0 ? Float(0.85 * sin(.pi * p) * a) : 0.0
            } else {
                self.hintRing.opacity = 0.0
            }
            // ghost finger + dotted guide with an arrow head
            if let g = ghost {
                let c = (t - CGFloat(self.openTime) - self.ghostStart).truncatingRemainder(dividingBy: self.ghostCycle)
                let fa = min(GUMotion.clamp(c / 0.12), 1.0 - GUMotion.clamp((c - 0.95) / 0.2)) * a
                let ga = GUMotion.clamp((c - 0.15) / 0.15) * (1.0 - GUMotion.clamp((c - 0.9) / 0.2)) * a
                let start = rest + pullUnit * 26.0
                let tip = rest + pullUnit * (self.ghostDistance + 26.0)
                let side = CGPoint(x: -pullUnit.y, y: pullUnit.x)
                let path = UIBezierPath()
                path.move(to: start)
                path.addLine(to: tip)
                let arrow = UIBezierPath()
                arrow.move(to: tip - pullUnit * 6.5 + side * 6.5)
                arrow.addLine(to: tip)
                arrow.addLine(to: tip - pullUnit * 6.5 - side * 6.5)
                path.append(arrow)
                self.guide.path = path.cgPath
                self.guide.lineDashPattern = [0.1, 7.0]
                self.guide.opacity = Float(ga)
                let press = GUMotion.clamp(c / 0.12)
                self.ghost.center = rest + pullUnit * g
                self.ghost.transform = CGAffineTransform(scaleX: 1.2 - 0.2 * press, y: 1.2 - 0.2 * press)
                self.ghost.alpha = fa
            } else {
                self.guide.opacity = 0.0
                self.ghost.alpha = 0.0
            }
        }
    }

    private func renderSnapped(_ t: CGFloat) {
        let st = t - CGFloat(self.snapTime)
        let b = self.bounds
        let leave = self.leaveK()
        let drop = 760.0 * leave
        var exitU: CGFloat = 0.0
        if let exit = self.exit {
            exitU = GUMotion.clamp(CGFloat(self.now - exit.time) / 0.55)
        }
        let k = GUMotion.spring(st - GiftUnwrapView.condenseDelay, GUMotion.sheet)   // reveal → sheet
        self.hintView.isHidden = true
        self.scrim.alpha = GUMotion.lerp(0.42, 0.36, k) * (1.0 - leave)

        // Glass: bands snap off, the sphere is gone, shards fly.
        self.glass.setBandsReleased(age: st)
        let shardsVisible = self.glass.updateShards(age: st, origin: self.snapCenter, scale: self.snapScale)
        self.installGlassIfReady()
        self.glass.view.isHidden = !shardsVisible && st > 0.3

        // Tails fall away.
        let fall = CGPoint(x: 0.0, y: st * st * 900.0)
        self.ribbon.update(knot: self.snapKnot + fall * 0.6, end: self.snapTail + fall + CGPoint(x: 8.0 * GUMotion.easeOut(st / 0.3), y: 26.0 * GUMotion.easeOut(st / 0.3)), leftEnd: self.snapLeftTail + fall, sag: 14.0, alpha: 1.0 - GUMotion.clamp(st / 0.22), hintPhase: nil)
        self.cracks.update(center: self.snapCenter, radius: GiftUnwrapView.sphereRadius * self.snapScale, progress: 1.0, alpha: 1.0 - GUMotion.clamp(st / 0.1))

        // The model pops out, then settles in the sheet header.
        let headerH = self.sheetFrame.height - self.sheet.bodyHeight
        let hk = headerH / GUGiftSheetView.headerHeight
        let pop = GUMotion.spring(st - 0.02, GUMotion.bounce)
        let revealSize = 172.0 * b.width / 402.0
        var giftCenter = GUMotion.lerp(self.snapCenter + CGPoint(x: 0.0, y: sin(st * 2.0) * 2.5 * GUMotion.clamp(st)), CGPoint(x: b.midX, y: self.sheetFrame.minY + 100.0 * hk), k)
        if !self.giftTaken {
            giftCenter.y += drop
        }
        let giftSize = GUMotion.lerp(GUMotion.lerp(GiftUnwrapView.sphereRadius * 1.1 * self.snapScale, revealSize, pop), 128.0 * min(1.0, hk * 1.05), k)
        let rz = -0.3 * exp(-st * 3.6) * cos(st * 12.0)

        // Backdrop: floods from the glass, then condenses into the sheet header (runs under the body).
        let corners = [CGPoint(x: 0.0, y: 0.0), CGPoint(x: b.width, y: 0.0), CGPoint(x: 0.0, y: b.height), CGPoint(x: b.width, y: b.height)]
        let maxR = corners.map { ($0 - self.snapCenter).length }.max() ?? 1000.0
        let revealR = (maxR + 40.0) * GUMotion.bezier(0.25, 0.75, 0.3, 1.0, (st - 0.02) / 0.9)
        if exitU >= 1.0 || st <= 0.0 {
            self.backdrop.setReveal(path: nil)
        } else if k <= 0.001 {
            self.backdrop.setReveal(center: self.snapCenter, radius: revealR)
        } else {
            let f = self.sheetFrame
            let rect = CGRect(x: GUMotion.lerp(-2.0, f.minX, k), y: GUMotion.lerp(-2.0, f.minY, k) + drop,
                              width: GUMotion.lerp(b.width + 4.0, f.width, k), height: GUMotion.lerp(b.height + 4.0, headerH + 60.0, k))
            let r = 38.0 * k
            self.backdrop.setReveal(path: UIBezierPath(roundedRect: rect, byRoundingCorners: [.topLeft, .topRight], cornerRadii: CGSize(width: r, height: r)).cgPath)
        }
        self.backdrop.patternCenter = self.giftTaken ? giftCenter + CGPoint(x: 0.0, y: drop) : giftCenter
        self.backdrop.gradientRadius = GUMotion.lerp(470.0, 300.0, k)
        self.backdrop.patternScale = GUMotion.lerp(1.0, 0.82, k)
        self.backdrop.holeRadius = GUMotion.lerp(70.0, 58.0, k)
        let bl = GUMotion.seg(st, 0.05, 0.5, GUMotion.easeInOut) * (0.55 + 0.45 * exp(-st * 0.9))
        self.backdrop.update(age: st - 0.12, waveOrigin: self.snapCenter, backlight: bl * (1.0 - exitU))

        // Sheet: header texts, chips, body.
        self.sheet.isHidden = st < GiftUnwrapView.condenseDelay
        if !self.sheet.isHidden {
            self.sheet.setAppear(st - GiftUnwrapView.condenseDelay)
            self.sheet.transform = CGAffineTransform(translationX: 0.0, y: drop)
            self.sheet.isUserInteractionEnabled = self.phase == .snapped && st > GiftUnwrapView.condenseDelay + 0.3
        }

        if !self.giftTaken {
            var center = giftCenter
            var size = giftSize
            var alpha: CGFloat = 1.0
            if let exit = self.exit {
                let e = GUMotion.bezier(0.42, 0.0, 0.2, 1.0, exitU)
                center = GUMotion.lerp(giftCenter, exit.target ?? giftCenter, e)
                size = giftSize * GUMotion.lerp(1.0, 0.3, e)
                alpha = 1.0 - GUMotion.clamp((exitU - 0.7) / 0.3)
            }
            guWithoutAnimation {
                self.haze.opacity = 0.0
                self.giftView.bounds = CGRect(x: 0.0, y: 0.0, width: size, height: size)
                self.giftView.center = center
                self.giftView.transform = CGAffineTransform(rotationAngle: rz)
                self.giftView.alpha = alpha
            }
        }
        if let exit = self.exit, exitU >= 1.0, !self.exitCompleted {
            self.exitCompleted = true
            DispatchQueue.main.async {
                exit.completion()
            }
        }

        self.effects.update(age: st, center: self.snapCenter, giftCenter: giftCenter, giftSize: giftSize, idleAlpha: (1.0 - k) * (1.0 - leave), time: t)

        // Sound and haptics on their frames.
        self.once("shimmer", st > 0.05) { self.sounds.play(.shimmer) }
        self.once("pattern", st > 0.2) {
            self.sounds.play(.patternTick)
            self.haptics.tick()
        }
        self.once("pattern2", st > 0.45) { self.haptics.tick() }
        self.once("sheet", st > GiftUnwrapView.condenseDelay + 0.05) { self.sounds.play(.whoosh, gain: 0.35) }
    }
}
