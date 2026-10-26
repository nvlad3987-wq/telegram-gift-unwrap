package com.designers.giftunwrap;

import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.Path;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * The broken glass: an icosphere split into ~56 shards (triangles grouped by the nearest of
 * 56 seeds), each flying out on a closed-form trajectory with drag, gravity and spin.
 * Projected with a perspective camera so shards coming towards the viewer grow.
 * Same seeds and constants as the iOS SceneKit version.
 */
final class GlassShards {
    private static final class Shard {
        float[] center;          // unit-radius sphere space
        float[][] tris;          // vertices relative to center, unit radius, 3 per triangle
        int[] rim;               // outline edges: pairs of indices into tris
        float[] sx, sy;          // projected vertices (scratch)
        float[] velocity;        // dp/s
        float[] axis;
        float spin, delay, life;
    }

    private final List<Shard> shards = new ArrayList<>();
    private final Paint fill = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint edge = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Path path = new Path();
    private final Path rimPath = new Path();

    GlassShards() {
        edge.setStyle(Paint.Style.STROKE);
        edge.setStrokeWidth(GUMotion.dp(1.1f));
        edge.setStrokeCap(Paint.Cap.ROUND);
        edge.setStrokeJoin(Paint.Join.ROUND);
        build();
    }

    private void build() {
        List<float[]> verts = new ArrayList<>();
        List<int[]> faces = new ArrayList<>();
        icosphere(3, verts, faces);
        GUMotion.Rand rng = new GUMotion.Rand(11);
        int seedCount = 56;
        float[][] seeds = new float[seedCount][];
        double golden = Math.PI * (3.0 - Math.sqrt(5.0));
        for (int i = 0; i < seedCount; i++) {
            float y = 1f - (i + 0.5f) / seedCount * 2f;
            float rr = (float) Math.sqrt(Math.max(0f, 1f - y * y));
            float phi = (float) (i * golden) + rng.range(-0.25f, 0.25f);
            seeds[i] = GlassSphere.normalize(new float[]{(float) Math.cos(phi) * rr, y + rng.range(-0.05f, 0.05f), (float) Math.sin(phi) * rr});
        }
        List<List<int[]>> groups = new ArrayList<>();
        for (int i = 0; i < seedCount; i++) {
            groups.add(new ArrayList<>());
        }
        for (int[] f : faces) {
            float[] a = verts.get(f[0]), b = verts.get(f[1]), c = verts.get(f[2]);
            float[] centroid = GlassSphere.normalize(new float[]{(a[0] + b[0] + c[0]) / 3f, (a[1] + b[1] + c[1]) / 3f, (a[2] + b[2] + c[2]) / 3f});
            int best = 0;
            float bestDot = -2f;
            for (int i = 0; i < seedCount; i++) {
                float d = GlassSphere.dot(seeds[i], centroid);
                if (d > bestDot) {
                    bestDot = d;
                    best = i;
                }
            }
            groups.get(best).add(f);
        }
        for (int i = 0; i < seedCount; i++) {
            List<int[]> tris = groups.get(i);
            if (tris.isEmpty()) {
                continue;
            }
            float[] sum = new float[3];
            for (int[] f : tris) {
                for (int k = 0; k < 3; k++) {
                    float[] v = verts.get(f[k]);
                    sum[0] += v[0];
                    sum[1] += v[1];
                    sum[2] += v[2];
                }
            }
            float count = tris.size() * 3f;
            Shard s = new Shard();
            s.center = new float[]{sum[0] / count, sum[1] / count, sum[2] / count};
            s.tris = new float[tris.size() * 3][];
            s.sx = new float[s.tris.length];
            s.sy = new float[s.tris.length];
            int j = 0;
            // Outline = edges used by one triangle of the shard only (the inner ones are hidden).
            Map<Long, Integer> edgeUse = new HashMap<>();
            Map<Long, int[]> edgeAt = new HashMap<>();
            for (int[] f : tris) {
                for (int k = 0; k < 3; k++) {
                    float[] v = verts.get(f[k]);
                    s.tris[j + k] = new float[]{v[0] - s.center[0], v[1] - s.center[1], v[2] - s.center[2]};
                    int a = f[k], b = f[(k + 1) % 3];
                    long key = (long) Math.min(a, b) * 100000L + Math.max(a, b);
                    edgeUse.merge(key, 1, Integer::sum);
                    edgeAt.put(key, new int[]{j + k, j + (k + 1) % 3});
                }
                j += 3;
            }
            List<Integer> rim = new ArrayList<>();
            for (Map.Entry<Long, Integer> e : edgeUse.entrySet()) {
                if (e.getValue() == 1) {
                    int[] at = edgeAt.get(e.getKey());
                    rim.add(at[0]);
                    rim.add(at[1]);
                }
            }
            s.rim = new int[rim.size()];
            for (int r = 0; r < s.rim.length; r++) {
                s.rim[r] = rim.get(r);
            }
            float[] n = GlassSphere.normalize(s.center);
            float speed = rng.range(320f, 620f) * rng.range(0.35f, 1.2f);
            s.velocity = new float[]{n[0] * speed, n[1] * speed, n[2] * speed + rng.range(60f, 220f)};
            s.axis = GlassSphere.normalize(new float[]{rng.range(-1f, 1f), rng.range(-1f, 1f), rng.range(-1f, 1f) + 0.001f});
            s.spin = rng.range(4f, 10f) * (i % 2 == 0 ? 1f : -1f);
            s.delay = (1f - GlassSphere.dot(n, GlassSphere.KNOT)) * 0.5f * 0.06f;
            s.life = rng.range(0.7f, 1.4f);
            shards.add(s);
        }
    }

    /**
     * Draws the shards {@code age} seconds after the snap.
     * @param originX origin of the sphere on screen (px)
     * @param radiusPx sphere radius at the snap (px)
     * @param cameraDistance perspective distance in px (larger = flatter)
     * @return false once every shard has faded
     */
    boolean draw(Canvas canvas, float age, float originX, float originY, float radiusPx, float cameraDistance) {
        if (age < 0f) {
            return true;
        }
        boolean any = false;
        float dp = GUMotion.dp(1f);
        for (Shard s : shards) {
            float t = Math.max(0f, age - s.delay);
            float alpha = 1f - GUMotion.clamp((t - s.life * 0.55f) / (s.life * 0.45f));
            if (alpha <= 0f) {
                continue;
            }
            any = true;
            float travel = (float) ((1.0 - Math.exp(-2.4 * t)) / 2.4);
            float px = s.center[0] * radiusPx + s.velocity[0] * dp * travel;
            float py = s.center[1] * radiusPx + s.velocity[1] * dp * travel - 170f * dp * t * t;
            float pz = s.center[2] * radiusPx + s.velocity[2] * dp * travel;
            float angle = (float) (s.spin * (1.0 - Math.exp(-1.6 * t)) / 1.6);
            float shrink = 1f - 0.35f * GUMotion.clamp((t - s.life * 0.5f) / (s.life * 0.6f));
            float[] rot = rotation(s.axis, angle);
            path.rewind();
            float facingSum = 0f;
            for (int i = 0; i < s.tris.length; i += 3) {
                for (int k = 0; k < 3; k++) {
                    float[] v = s.tris[i + k];
                    float x = (rot[0] * v[0] + rot[1] * v[1] + rot[2] * v[2]) * radiusPx * shrink + px;
                    float y = (rot[3] * v[0] + rot[4] * v[1] + rot[5] * v[2]) * radiusPx * shrink + py;
                    float z = (rot[6] * v[0] + rot[7] * v[1] + rot[8] * v[2]) * radiusPx * shrink + pz;
                    float persp = cameraDistance / Math.max(1f, cameraDistance - z);
                    float sx = originX + x * persp;
                    float sy = originY - y * persp;
                    s.sx[i + k] = sx;
                    s.sy[i + k] = sy;
                    if (k == 0) {
                        path.moveTo(sx, sy);
                    } else {
                        path.lineTo(sx, sy);
                    }
                }
                path.close();
            }
            // Shards facing the viewer catch more light.
            float[] n = GlassSphere.normalize(s.center);
            facingSum = Math.abs(rot[6] * n[0] + rot[7] * n[1] + rot[8] * n[2]);
            int fillAlpha = (int) (255 * alpha * (0.10f + 0.22f * facingSum));
            fill.setColor(GUMotion.mix(0xffffffff, 0xffcfe6ff, 0.4f));
            fill.setAlpha(fillAlpha);
            canvas.drawPath(path, fill);
            rimPath.rewind();
            for (int r = 0; r < s.rim.length; r += 2) {
                rimPath.moveTo(s.sx[s.rim[r]], s.sy[s.rim[r]]);
                rimPath.lineTo(s.sx[s.rim[r + 1]], s.sy[s.rim[r + 1]]);
            }
            edge.setColor(0xffffffff);
            edge.setAlpha((int) (255 * alpha * (0.45f + 0.4f * facingSum)));
            canvas.drawPath(rimPath, edge);
        }
        return any;
    }

    /** Row-major 3×3 rotation matrix around a unit axis. */
    private static float[] rotation(float[] a, float angle) {
        float c = (float) Math.cos(angle), s = (float) Math.sin(angle), t = 1f - c;
        float x = a[0], y = a[1], z = a[2];
        return new float[]{
                t * x * x + c, t * x * y - s * z, t * x * z + s * y,
                t * x * y + s * z, t * y * y + c, t * y * z - s * x,
                t * x * z - s * y, t * y * z + s * x, t * z * z + c};
    }

    private static void icosphere(int subdivisions, List<float[]> verts, List<int[]> faces) {
        float t = (float) ((1.0 + Math.sqrt(5.0)) / 2.0);
        float[][] raw = {
                {-1, t, 0}, {1, t, 0}, {-1, -t, 0}, {1, -t, 0},
                {0, -1, t}, {0, 1, t}, {0, -1, -t}, {0, 1, -t},
                {t, 0, -1}, {t, 0, 1}, {-t, 0, -1}, {-t, 0, 1}};
        for (float[] v : raw) {
            verts.add(GlassSphere.normalize(v));
        }
        int[][] base = {
                {0, 11, 5}, {0, 5, 1}, {0, 1, 7}, {0, 7, 10}, {0, 10, 11},
                {1, 5, 9}, {5, 11, 4}, {11, 10, 2}, {10, 7, 6}, {7, 1, 8},
                {3, 9, 4}, {3, 4, 2}, {3, 2, 6}, {3, 6, 8}, {3, 8, 9},
                {4, 9, 5}, {2, 4, 11}, {6, 2, 10}, {8, 6, 7}, {9, 8, 1}};
        List<int[]> current = new ArrayList<>();
        for (int[] f : base) {
            current.add(f);
        }
        for (int s = 0; s < subdivisions; s++) {
            Map<Long, Integer> cache = new HashMap<>();
            List<int[]> next = new ArrayList<>();
            for (int[] f : current) {
                int ab = midpoint(f[0], f[1], verts, cache);
                int bc = midpoint(f[1], f[2], verts, cache);
                int ca = midpoint(f[2], f[0], verts, cache);
                next.add(new int[]{f[0], ab, ca});
                next.add(new int[]{f[1], bc, ab});
                next.add(new int[]{f[2], ca, bc});
                next.add(new int[]{ab, bc, ca});
            }
            current = next;
        }
        faces.addAll(current);
    }

    private static int midpoint(int a, int b, List<float[]> verts, Map<Long, Integer> cache) {
        long key = (long) Math.min(a, b) * 100000L + Math.max(a, b);
        Integer found = cache.get(key);
        if (found != null) {
            return found;
        }
        float[] va = verts.get(a), vb = verts.get(b);
        verts.add(GlassSphere.normalize(new float[]{(va[0] + vb[0]) * 0.5f, (va[1] + vb[1]) * 0.5f, (va[2] + vb[2]) * 0.5f}));
        cache.put(key, verts.size() - 1);
        return verts.size() - 1;
    }
}
