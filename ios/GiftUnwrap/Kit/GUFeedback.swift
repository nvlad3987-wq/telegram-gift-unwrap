import UIKit
import AVFoundation

/// Haptics for the unwrap. Fired on the same frame as the visual event they belong to.
final class GUHaptics {
    private let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private let soft = UIImpactFeedbackGenerator(style: .soft)
    private let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private let medium = UIImpactFeedbackGenerator(style: .medium)
    private let selection = UISelectionFeedbackGenerator()
    private let notification = UINotificationFeedbackGenerator()
    var isEnabled = true

    func prepare() {
        self.rigid.prepare()
        self.heavy.prepare()
        self.soft.prepare()
    }

    /// Satin creaks while the ribbon is pulled; stronger as the tension grows.
    func tension(_ intensity: CGFloat) {
        guard self.isEnabled else { return }
        self.rigid.impactOccurred(intensity: GUMotion.clamp(0.25 + intensity * 0.75))
        self.rigid.prepare()
    }

    func crackle() {
        guard self.isEnabled else { return }
        self.soft.impactOccurred(intensity: 1.0)
    }

    func shatter() {
        guard self.isEnabled else { return }
        self.heavy.impactOccurred(intensity: 1.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            self?.notification.notificationOccurred(.success)
        }
    }

    func tick() {
        guard self.isEnabled else { return }
        self.selection.selectionChanged()
    }

    func tap() {
        guard self.isEnabled else { return }
        self.medium.impactOccurred(intensity: 0.6)
    }

    func land() {
        guard self.isEnabled else { return }
        self.medium.impactOccurred(intensity: 0.9)
    }
}

/// Sound design, synthesised at start-up (no audio files to ship). Uses the `.ambient`
/// session category, so it obeys the silent switch and never interrupts the user's music.
final class GUSounds {
    enum Kind: CaseIterable {
        case arrive, creak, crackle, shatter, shimmer, patternTick, rollTick, tap, whoosh, land, swell, toast
    }

    private let engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []
    private var nextPlayer = 0
    private var buffers: [Kind: AVAudioPCMBuffer] = [:]
    private let sampleRate: Double = 44100.0
    private var isReady = false
    var isEnabled = true

    /// Samples are synthesised once per process, off the main thread, and shared by every
    /// GUSounds (the demo builds a new one on each replay).
    private static var cache: [Kind: [Float]]?
    private static var waiting: [() -> Void] = []
    private static var synthesising = false

    private static func withSamples(sampleRate: Double, _ body: @escaping () -> Void) {
        if GUSounds.cache != nil {
            body()
            return
        }
        GUSounds.waiting.append(body)
        guard !GUSounds.synthesising else {
            return
        }
        GUSounds.synthesising = true
        DispatchQueue.global(qos: .userInitiated).async {
            var out: [Kind: [Float]] = [:]
            for kind in Kind.allCases {
                out[kind] = GUSounds.synthesize(kind, sampleRate: sampleRate)
            }
            DispatchQueue.main.async {
                GUSounds.cache = out
                GUSounds.synthesising = false
                let pending = GUSounds.waiting
                GUSounds.waiting = []
                pending.forEach { $0() }
            }
        }
    }

    func prepare() {
        guard !self.isReady, self.players.isEmpty, let format = AVAudioFormat(standardFormatWithSampleRate: self.sampleRate, channels: 1) else {
            return
        }
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        } catch {
        }
        for _ in 0 ..< 8 {
            let p = AVAudioPlayerNode()
            self.engine.attach(p)
            self.engine.connect(p, to: self.engine.mainMixerNode, format: format)
            self.players.append(p)
        }
        GUSounds.withSamples(sampleRate: self.sampleRate) { [weak self] in
            guard let self = self, let cache = GUSounds.cache else {
                return
            }
            for kind in Kind.allCases {
                if let samples = cache[kind], let b = GUSounds.makeBuffer(samples, format: format) {
                    self.buffers[kind] = b
                }
            }
            do {
                try self.engine.start()
                for p in self.players {
                    p.play()
                }
                self.isReady = true
            } catch {
                self.isReady = false
            }
        }
    }

    func play(_ kind: Kind, gain: Float = 1.0) {
        guard self.isEnabled, self.isReady, let buffer = self.buffers[kind] else {
            return
        }
        let p = self.players[self.nextPlayer]
        self.nextPlayer = (self.nextPlayer + 1) % self.players.count
        p.volume = gain
        p.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        if !p.isPlaying {
            p.play()
        }
    }

    func stop() {
        self.engine.stop()
        self.isReady = false
    }

    // MARK: - Synthesis

    private static func makeBuffer(_ samples: [Float], format: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)), let data = buffer.floatChannelData else {
            return nil
        }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { src in
            data[0].update(from: src.baseAddress!, count: samples.count)
        }
        return buffer
    }

    private static func synthesize(_ kind: Kind, sampleRate: Double) -> [Float] {
        var s = Synth(sampleRate: Float(sampleRate))
        switch kind {
        case .arrive:
            s.sweep(at: 0.0, from: 700.0, to: 180.0, duration: 0.35, decay: 0.06, gain: 0.35)
            s.ping(at: 0.06, frequency: 1568.0, decay: 0.35, gain: 0.08)
            s.ping(at: 0.14, frequency: 2093.0, decay: 0.4, gain: 0.07)
        case .creak:
            s.noise(at: 0.0, duration: 0.05, low: 2500.0, high: 9000.0, attack: 0.001, decay: 0.01, gain: 0.25)
        case .crackle:
            for k in 0 ..< 10 {
                let jitter = s.random() * 0.01
                s.noise(at: Float(k) * 0.025 + jitter, duration: 0.015, low: 3000.0, high: 12000.0, attack: 0.0005, decay: 0.003, gain: 0.25 + 0.04 * Float(k))
            }
        case .shatter:
            s.sweep(at: 0.0, from: 130.0, to: 70.0, duration: 1.2, decay: 0.18, gain: 0.55)
            s.noise(at: 0.0, duration: 1.0, low: 1500.0, high: 14000.0, attack: 0.001, decay: 0.09, gain: 0.45)
            for _ in 0 ..< 60 {
                let r0 = s.random(), r1 = s.random(), r2 = s.random(), r3 = s.random()
                let t = -log(max(0.001, r0)) * 0.12
                s.ping(at: t, frequency: 2200.0 + r1 * 7300.0, decay: 0.03 + r2 * 0.09, gain: (0.02 + r3 * 0.05) * exp(-t * 2.0))
            }
        case .shimmer:
            let notes: [Float] = [784, 988, 1175, 1568, 1976, 2349, 3136]
            for (i, f) in notes.enumerated() {
                s.ping(at: Float(i) * 0.055, frequency: f, decay: 0.9, gain: 0.05)
            }
        case .patternTick:
            for k in 0 ..< 14 {
                let r0 = s.random(), r1 = s.random()
                s.ping(at: Float(k) * 0.03 + r0 * 0.02, frequency: 3400.0 + r1 * 2800.0, decay: 0.03, gain: 0.03)
            }
        case .rollTick:
            for k in 0 ..< 18 {
                let t = 0.6 * pow(Float(k) / 18.0, 1.6)
                s.noise(at: t, duration: 0.01, low: 3000.0, high: 9000.0, attack: 0.0005, decay: 0.002, gain: 0.12)
            }
        case .tap:
            s.noise(at: 0.0, duration: 0.05, low: 1800.0, high: 7000.0, attack: 0.0005, decay: 0.004, gain: 0.3)
            s.ping(at: 0.0, frequency: 420.0, decay: 0.012, gain: 0.25)
        case .whoosh:
            s.noise(at: 0.0, duration: 1.1, low: 400.0, high: 7000.0, attack: 0.45, decay: 0.35, gain: 0.18)
            for k in 0 ..< 12 {
                s.ping(at: 0.1 + Float(k) * 0.07, frequency: 2600.0 + 180.0 * Float(k), decay: 0.08, gain: 0.03)
            }
        case .land:
            s.sweep(at: 0.0, from: 300.0, to: 1200.0, duration: 0.3, decay: 0.05, gain: 0.3)
            s.ping(at: 0.03, frequency: 2637.0, decay: 0.5, gain: 0.07)
            s.ping(at: 0.1, frequency: 3951.0, decay: 0.45, gain: 0.05)
        case .swell:
            s.noise(at: 0.0, duration: 0.9, low: 2500.0, high: 11000.0, attack: 0.45, decay: 0.4, gain: 0.06)
            let notes: [Float] = [1568, 2349, 3136, 3951]
            for (i, f) in notes.enumerated() {
                s.ping(at: 0.12 + Float(i) * 0.06, frequency: f, decay: 0.6, gain: 0.03)
            }
        case .toast:
            s.ping(at: 0.0, frequency: 1760.0, decay: 0.12, gain: 0.05)
        }
        return s.output()
    }
}

/// Tiny additive synthesiser: pings (sine + inharmonic partial), pitch sweeps and
/// band-passed noise, mixed into one mono buffer.
private struct Synth {
    let sampleRate: Float
    private var buffer: [Float] = []
    private var seed: UInt32 = 7

    init(sampleRate: Float) {
        self.sampleRate = sampleRate
    }

    mutating func random() -> Float {
        self.seed = self.seed &* 1664525 &+ 1013904223
        return Float(self.seed) / 4294967296.0
    }

    private mutating func ensure(_ count: Int) {
        if self.buffer.count < count {
            self.buffer += [Float](repeating: 0.0, count: count - self.buffer.count)
        }
    }

    mutating func ping(at t0: Float, frequency f: Float, decay: Float, gain: Float) {
        let n = Int((decay * 6.0 + 0.02) * self.sampleRate)
        let start = Int(t0 * self.sampleRate)
        self.ensure(start + n)
        for i in 0 ..< n {
            let t = Float(i) / self.sampleRate
            let attack = min(1.0, t / 0.002)
            let v = sin(2.0 * .pi * f * t) + 0.35 * sin(2.0 * .pi * f * 2.76 * t + 1.0) * exp(-t / (decay * 0.5))
            self.buffer[start + i] += v * exp(-t / decay) * attack * gain
        }
    }

    mutating func sweep(at t0: Float, from f0: Float, to f1: Float, duration: Float, decay: Float, gain: Float) {
        let n = Int(duration * self.sampleRate)
        let start = Int(t0 * self.sampleRate)
        self.ensure(start + n)
        var phase: Float = 0.0
        for i in 0 ..< n {
            let t = Float(i) / self.sampleRate
            let f = f1 + (f0 - f1) * exp(-t * 20.0)
            phase += 2.0 * .pi * f / self.sampleRate
            let attack = min(1.0, t / 0.002)
            self.buffer[start + i] += sin(phase) * exp(-t / decay) * attack * gain
        }
    }

    mutating func noise(at t0: Float, duration: Float, low: Float, high: Float, attack: Float, decay: Float, gain: Float) {
        let n = Int(duration * self.sampleRate)
        let start = Int(t0 * self.sampleRate)
        self.ensure(start + n)
        // RBJ band-pass biquad centred between low and high.
        let f0 = sqrt(low * high)
        let q = f0 / max(1.0, high - low)
        let w0 = 2.0 * Float.pi * f0 / self.sampleRate
        let alpha = sin(w0) / (2.0 * q)
        let a0 = 1.0 + alpha
        let b0 = alpha / a0, b2 = -alpha / a0
        let a1 = -2.0 * cos(w0) / a0, a2 = (1.0 - alpha) / a0
        var x1: Float = 0.0, x2: Float = 0.0, y1: Float = 0.0, y2: Float = 0.0
        for i in 0 ..< n {
            let t = Float(i) / self.sampleRate
            let x = self.random() * 2.0 - 1.0
            let y = b0 * x + b2 * x2 - a1 * y1 - a2 * y2
            x2 = x1
            x1 = x
            y2 = y1
            y1 = y
            let env = min(1.0, t / max(0.0001, attack)) * exp(-max(0.0, t - attack) / decay)
            self.buffer[start + i] += y * env * gain * 2.5
        }
    }

    func output() -> [Float] {
        let peak = self.buffer.reduce(Float(0.0)) { max($0, abs($1)) }
        if peak > 0.95 {
            let k = 0.95 / peak
            return self.buffer.map { $0 * k }
        }
        return self.buffer
    }
}
