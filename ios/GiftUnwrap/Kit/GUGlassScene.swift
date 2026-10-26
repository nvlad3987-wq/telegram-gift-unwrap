import UIKit
import SceneKit
import simd

/// The glass wrapping: a sphere of glass, two satin bands crossing at a knot, a bow,
/// and — at the snap — the same sphere broken into shards.
///
/// SceneKit (the framework Telegram already uses for the Premium star) renders it into a
/// transparent `SCNView` laid over the gift. The gift itself is a normal UIKit view behind
/// the glass, so it can be any view: an image here, Telegram's animated sticker in the app.
///
/// Coordinates: the camera is placed so that the z = 0 plane maps 1:1 to the view's points.
/// `world(_:)` converts a view point to that plane.
final class GUGlassScene {
    let view: SCNView
    private let scene = SCNScene()
    private let cameraNode = SCNNode()
    private let fieldOfView: CGFloat = 30.0
    private var viewSize: CGSize = .zero

    let radius: CGFloat
    /// Sphere-local direction of the knot (where the ribbon is tied).
    var knotDirection: SIMD3<Float> { return GUGlassScene.knotDir }
    /// Direction the finger pulls the ribbon in (sphere-local). The morph target is
    /// the sphere stretched this way.
    var pullDirection: SIMD3<Float> { return GUGlassScene.pullDir }

    private let group = SCNNode()
    private let sphere: SCNNode
    private let bands: SCNNode
    private let bow = SCNNode()
    private let loopLeft: SCNNode
    private let loopRight: SCNNode
    private let shardRoot = SCNNode()
    private var shards: [Shard] = []

    private(set) var tension: CGFloat = 0.0

    private struct Shard {
        let node: SCNNode
        let center: SIMD3<Float>
        let velocity: SIMD3<Float>
        let axis: SIMD3<Float>
        let spin: Float
        let delay: Float
        let life: Float
    }

    static let knotDir = simd_normalize(SIMD3<Float>(0.36, -0.46, 0.81))
    static let pullDir = simd_normalize(SIMD3<Float>(0.35, -0.82, 0.45))

    init(radius: CGFloat = 74.0) {
        self.radius = radius
        let r = Float(radius)
        let pull = GUGlassScene.pullDir
        let kd = GUGlassScene.knotDir
        let deform: (SIMD3<Float>) -> SIMD3<Float> = { p in
            return GUGlassScene.stretched(p, radius: r, pull: pull)
        }

        // Glass sphere with a morph target for the pull.
        let base = GUMesh.uvSphere(radius: r, rings: 48, segments: 72)
        let sphereGeometry = base.geometry()
        sphereGeometry.materials = [GUGlassScene.glassMaterial(alpha: 0.06, doubleSided: false)]
        let sphereNode = SCNNode(geometry: sphereGeometry)
        let morpher = SCNMorpher()
        morpher.targets = [base.mapped(deform).geometry()]
        morpher.calculationMode = .normalized
        sphereNode.morpher = morpher
        sphereNode.renderingOrder = 10
        self.sphere = sphereNode

        // Two satin bands that cross at the knot.
        let up = SIMD3<Float>(0.0, 1.0, 0.0)
        let p1 = simd_normalize(up - kd * simd_dot(kd, up))
        let p2 = simd_normalize(simd_cross(kd, p1))
        let bandMesh = GUMesh.band(radius: r + 0.9, a: kd, b: p1, halfWidth: 10.5, segments: 160)
            .appending(GUMesh.band(radius: r + 1.2, a: kd, b: p2, halfWidth: 10.5, segments: 160))
        let bandGeometry = bandMesh.geometry()
        bandGeometry.materials = [GUGlassScene.satinMaterial()]
        let bandNode = SCNNode(geometry: bandGeometry)
        let bandMorpher = SCNMorpher()
        bandMorpher.targets = [bandMesh.mapped(deform).geometry()]
        bandMorpher.calculationMode = .normalized
        bandNode.morpher = bandMorpher
        bandNode.renderingOrder = 12
        self.bands = bandNode

        // Bow: two flattened loops and a knot.
        self.loopLeft = GUGlassScene.makeLoop()
        self.loopRight = GUGlassScene.makeLoop()

        self.view = SCNView(frame: .zero, options: nil)

        // All stored properties are set from here on.
        self.view.backgroundColor = .clear
        self.view.isOpaque = false
        self.view.isUserInteractionEnabled = false
        self.view.antialiasingMode = .multisampling4X
        self.view.preferredFramesPerSecond = 120
        self.view.rendersContinuously = true
        self.view.scene = self.scene

        self.scene.lightingEnvironment.contents = GUImages.glassEnvironment()
        self.scene.lightingEnvironment.intensity = 1.7

        let camera = SCNCamera()
        camera.fieldOfView = self.fieldOfView
        camera.projectionDirection = .vertical
        camera.zNear = 1.0
        camera.zFar = 6000.0
        self.cameraNode.camera = camera
        self.scene.rootNode.addChildNode(self.cameraNode)

        let knot = SCNNode(geometry: {
            let s = SCNSphere(radius: 5.2)
            s.segmentCount = 24
            s.materials = [GUGlassScene.satinMaterial()]
            return s
        }())
        knot.renderingOrder = 14
        self.bow.addChildNode(self.loopLeft)
        self.bow.addChildNode(self.loopRight)
        self.bow.addChildNode(knot)
        // The bow faces out of the sphere at the knot.
        self.bow.simdOrientation = simd_quatf(from: SIMD3<Float>(0.0, 0.0, 1.0), to: kd)

        self.group.addChildNode(self.sphere)
        self.group.addChildNode(self.bands)
        self.group.addChildNode(self.bow)
        self.scene.rootNode.addChildNode(self.group)
        self.scene.rootNode.addChildNode(self.shardRoot)

        self.buildShards()
        self.setTension(0.0, untie: 0.0)

        // Compile the materials off the main thread before the view goes on screen; the first
        // render would otherwise block the main thread while Metal builds the shaders (seconds in
        // the simulator). The host adds `view` to its hierarchy once `isPrepared` is true.
        let started = CACurrentMediaTime()
        self.view.prepare([self.scene]) { [weak self] _ in
            DispatchQueue.main.async {
                self?.isPrepared = true
                GiftUnwrapView.debugLog?(String(format: "glass prepared in %.0f ms", (CACurrentMediaTime() - started) * 1000.0))
            }
        }
    }

    /// True once the scene's shaders are compiled and it can be shown without a hitch.
    private(set) var isPrepared = false

    private static func makeLoop() -> SCNNode {
        let torus = SCNTorus(ringRadius: 10.0, pipeRadius: 3.4)
        torus.ringSegmentCount = 48
        torus.pipeSegmentCount = 16
        torus.materials = [GUGlassScene.satinMaterial()]
        let node = SCNNode(geometry: torus)
        node.renderingOrder = 13
        return node
    }

    /// The ribbon (bands, bow, knot) wears the gift's backdrop colours.
    func setRibbonColor(base: UIColor, dark: UIColor) {
        let apply: (SCNNode) -> Void = { node in
            for m in node.geometry?.materials ?? [] {
                m.diffuse.contents = base
                m.emission.contents = dark.withAlphaComponent(0.6)
            }
        }
        apply(self.bands)
        self.bow.enumerateHierarchy { node, _ in
            apply(node)
        }
    }

    // MARK: - Layout and projection

    func layout(size: CGSize) {
        if size == self.viewSize {
            return
        }
        self.viewSize = size
        let distance = Float(size.height / (2.0 * tan(self.fieldOfView * .pi / 360.0)))
        self.cameraNode.simdPosition = SIMD3<Float>(0.0, 0.0, distance)
    }

    private var cameraDistance: Float {
        return self.cameraNode.simdPosition.z
    }

    /// View point → world point on the z = 0 plane (plus an optional depth).
    func world(_ p: CGPoint, z: Float = 0.0) -> SIMD3<Float> {
        return SIMD3<Float>(Float(p.x - self.viewSize.width / 2.0), Float(self.viewSize.height / 2.0 - p.y), z)
    }

    /// World point → view point (perspective).
    func project(_ w: SIMD3<Float>) -> CGPoint {
        let d = self.cameraDistance
        let k = CGFloat(d / max(1.0, d - w.z))
        return CGPoint(x: self.viewSize.width / 2.0 + CGFloat(w.x) * k, y: self.viewSize.height / 2.0 - CGFloat(w.y) * k)
    }

    // MARK: - Wrapped state

    /// Places the wrapped sphere. `wobble` squashes it (jelly), `tremble` shakes it near the snap.
    func setWrapped(center: CGPoint, scale: CGFloat, wobble: CGSize, tremble: CGPoint, alpha: CGFloat) {
        self.group.isHidden = alpha <= 0.001
        self.group.opacity = alpha
        self.group.simdPosition = self.world(center + tremble)
        self.group.simdScale = SIMD3<Float>(Float(scale * wobble.width), Float(scale * wobble.height), Float(scale))
    }

    /// 0 → 1 as the ribbon is pulled. Stretches the glass and the bands, and opens the bow.
    func setTension(_ tension: CGFloat, untie: CGFloat) {
        self.tension = tension
        let w = tension * tension * (3.0 - 2.0 * tension)
        self.sphere.morpher?.setWeight(w, forTargetAt: 0)
        self.bands.morpher?.setWeight(w, forTargetAt: 0)

        let knot = self.knotLocal()
        self.bow.simdPosition = knot + self.knotDirection * 2.0
        let u = Float(untie)
        let sl = 1.0 - 0.35 * u
        let sr = 1.0 - 0.7 * u
        self.loopLeft.simdPosition = SIMD3<Float>(-10.5 * sl, 1.5, 1.0)
        self.loopLeft.simdEulerAngles = SIMD3<Float>(.pi / 2.0, 0.0, 0.55)
        self.loopLeft.simdScale = SIMD3<Float>(sl, 1.0, 0.6 * sl)
        self.loopRight.simdPosition = SIMD3<Float>(10.5 * sr, 1.5, 1.0)
        self.loopRight.simdEulerAngles = SIMD3<Float>(.pi / 2.0, 0.0, -0.55)
        self.loopRight.simdScale = SIMD3<Float>(sr, 1.0, 0.6 * sr)
    }

    /// The knot in sphere-local coordinates, following the morph.
    private func knotLocal() -> SIMD3<Float> {
        let r = Float(self.radius) + 3.0
        let base = self.knotDirection * r
        let target = GUGlassScene.stretched(base, radius: Float(self.radius), pull: self.pullDirection)
        let t = Float(self.tension)
        let w = t * t * (3.0 - 2.0 * t)
        return base + (target - base) * w
    }

    /// The knot as a view point (the ribbon tail starts here).
    func knotPoint() -> CGPoint {
        let local = self.knotLocal()
        let worldPoint = self.group.simdConvertPosition(local, to: nil)
        return self.project(worldPoint)
    }

    /// The sphere's outline in view space (centre and radius), for the crack layer.
    func outline() -> (center: CGPoint, radius: CGFloat) {
        let c = self.project(self.group.simdWorldPosition)
        let edge = self.project(self.group.simdWorldPosition + SIMD3<Float>(Float(self.radius) * self.group.simdScale.x, 0.0, 0.0))
        return (c, abs(edge.x - c.x))
    }

    /// Bands fly apart and fade right after the snap.
    func setBandsReleased(age: CGFloat) {
        let a = max(0.0, age)
        let fade = 1.0 - GUMotion.clamp(a / 0.1)
        self.bands.opacity = fade
        self.bow.opacity = fade
        let s = Float(1.0 + a * 3.0)
        self.bands.simdScale = SIMD3<Float>(s, s, s)
        self.sphere.isHidden = age > 0.0
    }

    // MARK: - Shatter

    private func buildShards() {
        let r = Float(self.radius)
        let mesh = GUMesh.icosphere(radius: r, subdivisions: 3)
        var rng = GURandom(seed: 11)
        // Seeds: a jittered Fibonacci sphere, so the shards have similar sizes.
        let seedCount = 56
        var seeds: [SIMD3<Float>] = []
        let golden = Float.pi * (3.0 - sqrt(5.0))
        for i in 0 ..< seedCount {
            let y = 1.0 - (Float(i) + 0.5) / Float(seedCount) * 2.0
            let rr = sqrt(max(0.0, 1.0 - y * y))
            let phi = Float(i) * golden + Float(rng.range(-0.25, 0.25))
            seeds.append(simd_normalize(SIMD3<Float>(cos(phi) * rr, y + Float(rng.range(-0.05, 0.05)), sin(phi) * rr)))
        }
        var groups = Array(repeating: [Int](), count: seedCount)
        for t in 0 ..< mesh.indices.count / 3 {
            let a = mesh.positions[Int(mesh.indices[t * 3])]
            let b = mesh.positions[Int(mesh.indices[t * 3 + 1])]
            let c = mesh.positions[Int(mesh.indices[t * 3 + 2])]
            let centroid = simd_normalize((a + b + c) / 3.0)
            var best = 0
            var bestDot: Float = -2.0
            for (i, s) in seeds.enumerated() {
                let d = simd_dot(s, centroid)
                if d > bestDot {
                    bestDot = d
                    best = i
                }
            }
            groups[best].append(t)
        }
        let material = GUGlassScene.glassMaterial(alpha: 0.16, doubleSided: true)
        for (i, tris) in groups.enumerated() where !tris.isEmpty {
            var sum = SIMD3<Float>(repeating: 0.0)
            for t in tris {
                for k in 0 ..< 3 {
                    sum += mesh.positions[Int(mesh.indices[t * 3 + k])]
                }
            }
            let center = sum / Float(tris.count * 3)
            var piece = GUMesh()
            for t in tris {
                for k in 0 ..< 3 {
                    let p = mesh.positions[Int(mesh.indices[t * 3 + k])]
                    piece.positions.append(p - center)
                    piece.normals.append(simd_normalize(p))
                    piece.indices.append(UInt32(piece.positions.count - 1))
                }
            }
            let geometry = piece.geometry()
            geometry.materials = [material]
            let node = SCNNode(geometry: geometry)
            node.renderingOrder = 20
            node.isHidden = true
            self.shardRoot.addChildNode(node)

            let n = simd_normalize(center)
            let speed = Float(rng.range(320.0, 620.0)) * Float(rng.range(0.35, 1.2))
            var velocity = n * speed
            velocity.z += Float(rng.range(60.0, 220.0))
            let axis = simd_normalize(SIMD3<Float>(Float(rng.range(-1.0, 1.0)), Float(rng.range(-1.0, 1.0)), Float(rng.range(-1.0, 1.0))) + SIMD3<Float>(0.0, 0.0, 0.001))
            let fromKnot = (1.0 - simd_dot(n, self.knotDirection)) * 0.5
            self.shards.append(Shard(
                node: node,
                center: center,
                velocity: velocity,
                axis: axis,
                spin: Float(rng.range(4.0, 10.0)) * (i % 2 == 0 ? 1.0 : -1.0),
                delay: fromKnot * 0.06,
                life: Float(rng.range(0.7, 1.4))
            ))
        }
    }

    /// Moves the shards. `age` is seconds since the snap (negative → hidden).
    /// Returns false once every shard has faded out.
    @discardableResult
    func updateShards(age: CGFloat, origin: CGPoint, scale: CGFloat) -> Bool {
        var anyVisible = false
        let o = self.world(origin)
        let s = Float(scale)
        for shard in self.shards {
            let a = Float(age) - shard.delay
            if age < 0.0 {
                shard.node.isHidden = true
                continue
            }
            let t = max(0.0, a)
            let alpha = 1.0 - min(1.0, max(0.0, (t - shard.life * 0.55) / (shard.life * 0.45)))
            if alpha <= 0.0 {
                shard.node.isHidden = true
                continue
            }
            anyVisible = true
            shard.node.isHidden = false
            let drag: Float = 2.4
            let travel = (1.0 - exp(-drag * t)) / drag
            var p = o + shard.center * s + shard.velocity * travel
            p.y -= 170.0 * t * t
            shard.node.simdPosition = p
            let angle = shard.spin * (1.0 - exp(-1.6 * t)) / 1.6
            shard.node.simdOrientation = simd_quatf(angle: angle, axis: shard.axis)
            let shrink = 1.0 - 0.35 * min(1.0, max(0.0, (t - shard.life * 0.5) / (shard.life * 0.6)))
            shard.node.simdScale = SIMD3<Float>(repeating: s * shrink)
            shard.node.opacity = CGFloat(alpha)
        }
        return anyVisible
    }

    // MARK: - Materials and geometry helpers

    /// The pull deformation: the side being pulled bulges out, the sides pinch in.
    static func stretched(_ p: SIMD3<Float>, radius r: Float, pull: SIMD3<Float>) -> SIMD3<Float> {
        let len = simd_length(p)
        if len < 0.0001 {
            return p
        }
        let n = p / len
        let d = simd_dot(n, pull)
        let x = min(1.0, max(0.0, (d + 0.1) / 1.1))
        let k = x * x * (3.0 - 2.0 * x)
        var q = p
        q += pull * (k * k * 0.30 * r)
        q -= (n - pull * d) * (k * 0.10 * r)
        q -= n * ((1.0 - k) * 0.04 * r)
        return q
    }

    static func glassMaterial(alpha: CGFloat, doubleSided: Bool) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents = UIColor(white: 1.0, alpha: alpha)
        m.metalness.contents = 0.0
        m.roughness.contents = 0.06
        m.transparencyMode = .dualLayer
        m.blendMode = .alpha
        m.writesToDepthBuffer = false
        m.isDoubleSided = doubleSided
        return m
    }

    static func satinMaterial() -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents = UIColor(guRGB: 0xff4f93)
        m.metalness.contents = 0.15
        m.roughness.contents = 0.38
        m.emission.contents = UIColor(guRGB: 0x5a0a2c)
        return m
    }
}

/// A plain triangle mesh (positions, normals, indices) that converts to `SCNGeometry`.
struct GUMesh {
    var positions: [SIMD3<Float>] = []
    var normals: [SIMD3<Float>] = []
    var indices: [UInt32] = []

    func geometry() -> SCNGeometry {
        let v = SCNGeometrySource(vertices: self.positions.map { SCNVector3($0.x, $0.y, $0.z) })
        let n = SCNGeometrySource(normals: self.normals.map { SCNVector3($0.x, $0.y, $0.z) })
        let e = SCNGeometryElement(indices: self.indices, primitiveType: .triangles)
        return SCNGeometry(sources: [v, n], elements: [e])
    }

    func mapped(_ f: (SIMD3<Float>) -> SIMD3<Float>) -> GUMesh {
        var out = self
        out.positions = self.positions.map(f)
        return out
    }

    func appending(_ other: GUMesh) -> GUMesh {
        var out = self
        let base = UInt32(self.positions.count)
        out.positions += other.positions
        out.normals += other.normals
        out.indices += other.indices.map { $0 + base }
        return out
    }

    static func uvSphere(radius r: Float, rings: Int, segments: Int) -> GUMesh {
        var m = GUMesh()
        for i in 0 ... rings {
            let v = Float(i) / Float(rings)
            let theta = v * .pi
            for j in 0 ... segments {
                let u = Float(j) / Float(segments)
                let phi = u * 2.0 * .pi
                let n = SIMD3<Float>(sin(theta) * cos(phi), cos(theta), sin(theta) * sin(phi))
                m.positions.append(n * r)
                m.normals.append(n)
            }
        }
        let row = segments + 1
        for i in 0 ..< rings {
            for j in 0 ..< segments {
                let a = UInt32(i * row + j)
                let b = UInt32((i + 1) * row + j)
                m.indices += [a, a + 1, b, b, a + 1, b + 1]
            }
        }
        return m
    }

    /// A strip around the sphere on the great circle spanned by `a` and `b`.
    static func band(radius r: Float, a: SIMD3<Float>, b: SIMD3<Float>, halfWidth: Float, segments: Int) -> GUMesh {
        var m = GUMesh()
        let axis = simd_normalize(simd_cross(a, b))
        let phi = halfWidth / r
        for i in 0 ... segments {
            let t = Float(i) / Float(segments) * 2.0 * .pi
            let dir = a * cos(t) + b * sin(t)
            for s: Float in [-1.0, 1.0] {
                let n = simd_normalize(dir * cos(phi) + axis * sin(phi) * s)
                m.positions.append(n * r)
                m.normals.append(n)
            }
        }
        for i in 0 ..< segments {
            let k = UInt32(i * 2)
            m.indices += [k, k + 2, k + 1, k + 1, k + 2, k + 3]
        }
        return m
    }

    static func icosphere(radius r: Float, subdivisions: Int) -> GUMesh {
        let t = (1.0 + sqrt(Float(5.0))) / 2.0
        let raw: [SIMD3<Float>] = [
            SIMD3<Float>(-1, t, 0), SIMD3<Float>(1, t, 0), SIMD3<Float>(-1, -t, 0), SIMD3<Float>(1, -t, 0),
            SIMD3<Float>(0, -1, t), SIMD3<Float>(0, 1, t), SIMD3<Float>(0, -1, -t), SIMD3<Float>(0, 1, -t),
            SIMD3<Float>(t, 0, -1), SIMD3<Float>(t, 0, 1), SIMD3<Float>(-t, 0, -1), SIMD3<Float>(-t, 0, 1),
        ]
        var verts: [SIMD3<Float>] = raw.map { simd_normalize($0) }
        var faces: [(Int, Int, Int)] = [
            (0, 11, 5), (0, 5, 1), (0, 1, 7), (0, 7, 10), (0, 10, 11),
            (1, 5, 9), (5, 11, 4), (11, 10, 2), (10, 7, 6), (7, 1, 8),
            (3, 9, 4), (3, 4, 2), (3, 2, 6), (3, 6, 8), (3, 8, 9),
            (4, 9, 5), (2, 4, 11), (6, 2, 10), (8, 6, 7), (9, 8, 1),
        ]
        for _ in 0 ..< subdivisions {
            var cache: [Int: Int] = [:]
            func midpoint(_ a: Int, _ b: Int) -> Int {
                let key = min(a, b) * 100_000 + max(a, b)
                if let found = cache[key] {
                    return found
                }
                verts.append(simd_normalize((verts[a] + verts[b]) * 0.5))
                cache[key] = verts.count - 1
                return verts.count - 1
            }
            var next: [(Int, Int, Int)] = []
            for (a, b, c) in faces {
                let ab = midpoint(a, b)
                let bc = midpoint(b, c)
                let ca = midpoint(c, a)
                next += [(a, ab, ca), (b, bc, ab), (c, ca, bc), (ab, bc, ca)]
            }
            faces = next
        }
        var m = GUMesh()
        m.positions = verts.map { $0 * r }
        m.normals = verts
        for (a, b, c) in faces {
            m.indices += [UInt32(a), UInt32(b), UInt32(c)]
        }
        return m
    }
}
