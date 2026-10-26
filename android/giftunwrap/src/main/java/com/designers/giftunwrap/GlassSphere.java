package com.designers.giftunwrap;

import android.graphics.Canvas;
import android.graphics.LinearGradient;
import android.graphics.Matrix;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.PointF;
import android.graphics.RadialGradient;
import android.graphics.RectF;
import android.graphics.Shader;
import android.graphics.SweepGradient;

/**
 * The wrapped glass sphere drawn on a Canvas: glass body with rim light and iridescent edge,
 * two satin bands crossing at the knot (real great circles, projected), and the bow.
 * Pulling the ribbon stretches the outline towards the pull direction.
 */
final class GlassSphere {
    static final float RADIUS_DP = 88f;
    /** Knot direction in sphere space (x right, y up, z towards the viewer) — same as iOS. */
    static final float[] KNOT = normalize(new float[]{0.36f, -0.46f, 0.81f});
    static final float[] PULL = normalize(new float[]{0.35f, -0.82f, 0.45f});

    private final Paint fill = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint rim = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint band = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint bow = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint bowStroke = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Path outline = new Path();
    private final Matrix matrix = new Matrix();
    private final float[][] bandA = new float[2][];
    private final float[][] bandB = new float[2][];

    /** Ribbon colours: the gift's backdrop (base, light, dark). */
    private int ribbonBase = 0xff5568bf, ribbonLight = 0xffc6d4f3, ribbonDark = 0xff2a3a8e;

    void setColors(int base, int light, int dark) {
        ribbonBase = base;
        ribbonLight = light;
        ribbonDark = dark;
        bowStroke.setColor(GUMotion.mix(dark, 0xff000000, 0.2f));
    }

    // State for the current frame.
    float cx, cy, radius, sx = 1f, sy = 1f, tension, untie, alpha = 1f;

    GlassSphere() {
        rim.setStyle(Paint.Style.STROKE);
        band.setStyle(Paint.Style.STROKE);
        band.setStrokeCap(Paint.Cap.BUTT);
        bowStroke.setStyle(Paint.Style.STROKE);
        bowStroke.setColor(0xff9e1450);
        bowStroke.setStrokeWidth(GUMotion.dp(0.8f));
        float[] up = {0f, 1f, 0f};
        float[] kd = KNOT;
        float[] p1 = normalize(sub(up, mul(kd, dot(kd, up))));
        float[] p2 = normalize(cross(kd, p1));
        bandA[0] = kd;
        bandA[1] = p1;
        bandB[0] = kd;
        bandB[1] = p2;
    }

    void set(float cx, float cy, float scale, float sx, float sy, float tension, float untie, float alpha) {
        this.cx = cx;
        this.cy = cy;
        this.radius = GUMotion.dp(RADIUS_DP) * scale;
        this.sx = sx;
        this.sy = sy;
        this.tension = tension;
        this.untie = untie;
        this.alpha = alpha;
    }

    private float weight() {
        float t = tension;
        return t * t * (3f - 2f * t);
    }

    /** Sphere point (unit, sphere space) → screen, with the pull deformation. Returns {x, y, z}. */
    float[] project(float[] n, float extra) {
        float w = weight();
        float d = dot(n, PULL);
        float x = GUMotion.clamp((d + 0.1f) / 1.1f);
        float k = x * x * (3f - 2f * x);
        float r = radius + extra;
        float px = n[0] * r, py = n[1] * r, pz = n[2] * r;
        // same deformation as iOS GUGlassScene.stretched, scaled by the morph weight
        float bulge = k * k * 0.30f * radius * w;
        float pinch = k * 0.10f * radius * w;
        float shrink = (1f - k) * 0.04f * radius * w;
        px += PULL[0] * bulge - (n[0] - PULL[0] * d) * pinch - n[0] * shrink;
        py += PULL[1] * bulge - (n[1] - PULL[1] * d) * pinch - n[1] * shrink;
        pz += PULL[2] * bulge - (n[2] - PULL[2] * d) * pinch - n[2] * shrink;
        return new float[]{cx + px * sx, cy - py * sy, pz};
    }

    PointF knotPoint() {
        float[] p = project(KNOT, GUMotion.dp(3f));
        return new PointF(p[0], p[1]);
    }

    private void buildOutline() {
        outline.rewind();
        int n = 96;
        for (int i = 0; i <= n; i++) {
            double a = i * 2.0 * Math.PI / n;
            // a point on the silhouette (z = 0 ring) of the sphere
            float[] p = project(new float[]{(float) Math.cos(a), (float) Math.sin(a), 0f}, 0f);
            if (i == 0) {
                outline.moveTo(p[0], p[1]);
            } else {
                outline.lineTo(p[0], p[1]);
            }
        }
        outline.close();
    }

    Path outline() {
        buildOutline();
        return outline;
    }

    /** Bands behind the gift (the far half, seen through the glass). */
    void drawBack(Canvas canvas) {
        drawBand(canvas, bandA, false);
        drawBand(canvas, bandB, false);
    }

    /** The glass itself. */
    void drawGlass(Canvas canvas) {
        buildOutline();
        float r = radius;
        int a = (int) (255 * alpha);

        fill.setShader(new RadialGradient(cx - 0.15f * r, cy - 0.2f * r, 1.2f * r,
                new int[]{0x08ffffff, 0x10ffffff, 0x38ffffff, 0x70ffffff},
                new float[]{0f, 0.6f, 0.9f, 1f}, Shader.TileMode.CLAMP));
        fill.setAlpha(a);
        canvas.drawPath(outline, fill);

        // iridescent bounce light near the bottom
        fill.setShader(new RadialGradient(cx + 0.35f * r, cy + 0.5f * r, 0.9f * r,
                new int[]{0x40ff8fd0, 0x00ff8fd0}, null, Shader.TileMode.CLAMP));
        fill.setAlpha(a);
        canvas.drawPath(outline, fill);
        fill.setShader(new RadialGradient(cx - 0.45f * r, cy + 0.25f * r, 0.8f * r,
                new int[]{0x3870dcff, 0x0070dcff}, null, Shader.TileMode.CLAMP));
        fill.setAlpha(a);
        canvas.drawPath(outline, fill);

        // rim light
        rim.setStrokeWidth(GUMotion.dp(1.6f));
        rim.setShader(new SweepGradient(cx, cy,
                new int[]{0xf2ffffff, 0x99ffb3e6, 0x9980dcff, 0x4dffffff, 0xf2ffffff}, null));
        rim.setAlpha(a);
        canvas.drawPath(outline, rim);

        // specular highlight
        canvas.save();
        canvas.rotate(-30f, cx - 0.38f * r, cy - 0.45f * r);
        RectF oval = new RectF(cx - 0.38f * r - 0.28f * r, cy - 0.45f * r - 0.15f * r, cx - 0.38f * r + 0.28f * r, cy - 0.45f * r + 0.15f * r);
        fill.setShader(new RadialGradient(oval.centerX(), oval.centerY(), 0.28f * r,
                new int[]{0xe6ffffff, 0x00ffffff}, null, Shader.TileMode.CLAMP));
        fill.setAlpha(a);
        canvas.drawOval(oval, fill);
        canvas.restore();
        fill.setShader(null);
    }

    /** Bands in front and the bow. */
    void drawFront(Canvas canvas) {
        drawBand(canvas, bandA, true);
        drawBand(canvas, bandB, true);
        drawBow(canvas);
    }

    private void drawBand(Canvas canvas, float[][] basis, boolean front) {
        float[] a = basis[0], b = basis[1];
        int n = 120;
        float width = GUMotion.dp(21f) * (radius / GUMotion.dp(RADIUS_DP));
        float[] prev = null;
        for (int i = 0; i <= n; i++) {
            double t = i * 2.0 * Math.PI / n;
            float[] dir = {
                    (float) (a[0] * Math.cos(t) + b[0] * Math.sin(t)),
                    (float) (a[1] * Math.cos(t) + b[1] * Math.sin(t)),
                    (float) (a[2] * Math.cos(t) + b[2] * Math.sin(t))};
            float[] p = project(dir, GUMotion.dp(1f));
            if (prev != null) {
                float zMid = (p[2] + prev[2]) * 0.5f / radius;
                boolean isFront = zMid >= 0f;
                if (isFront == front) {
                    float facing = Math.abs(zMid);
                    band.setStrokeWidth(width * (0.35f + 0.65f * facing));
                    int base = ribbonBase;
                    int lit = front ? GUMotion.mix(base, 0xffffffff, 0.28f * facing) : GUMotion.mix(base, ribbonDark, 0.4f);
                    band.setColor(lit);
                    band.setAlpha((int) (255 * alpha * (front ? 1f : 0.35f)));
                    canvas.drawLine(prev[0], prev[1], p[0], p[1], band);
                }
            }
            prev = p;
        }
    }

    private void drawBow(Canvas canvas) {
        PointF k = knotPoint();
        float s = radius / GUMotion.dp(RADIUS_DP);
        float sl = 1f - 0.35f * untie;
        float sr = 1f - 0.7f * untie;
        drawLoop(canvas, k.x, k.y, -1, sl * s);
        drawLoop(canvas, k.x, k.y, 1, sr * s);
        float kr = GUMotion.dp(5.5f) * s;
        bow.setShader(new RadialGradient(k.x - kr * 0.3f, k.y - kr * 0.3f, kr * 1.4f, new int[]{ribbonLight, ribbonBase}, null, Shader.TileMode.CLAMP));
        bow.setAlpha((int) (255 * alpha));
        canvas.drawCircle(k.x, k.y, kr, bow);
        bow.setShader(null);
    }

    private void drawLoop(Canvas canvas, float x, float y, int side, float s) {
        float len = GUMotion.dp(24f) * s;
        float half = GUMotion.dp(8f) * s;
        Path p = new Path();
        p.moveTo(0f, 0f);
        p.cubicTo(len * 0.35f, -half * 1.6f, len, -half * 1.3f, len, 0f);
        p.cubicTo(len, half * 1.3f, len * 0.35f, half * 1.6f, 0f, 0f);
        p.close();
        matrix.reset();
        matrix.postScale(side, 1f);
        matrix.postRotate(side * -28f);
        matrix.postTranslate(x, y);
        p.transform(matrix);
        bow.setShader(new LinearGradient(x, y - half, x + side * len, y + half, ribbonLight, GUMotion.mix(ribbonBase, ribbonDark, 0.3f), Shader.TileMode.CLAMP));
        bow.setAlpha((int) (255 * alpha));
        canvas.drawPath(p, bow);
        bowStroke.setAlpha((int) (200 * alpha));
        canvas.drawPath(p, bowStroke);
        bow.setShader(null);
    }

    // --- small vector helpers

    static float[] normalize(float[] v) {
        float l = (float) Math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]);
        return new float[]{v[0] / l, v[1] / l, v[2] / l};
    }

    static float dot(float[] a, float[] b) {
        return a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
    }

    static float[] cross(float[] a, float[] b) {
        return new float[]{a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]};
    }

    static float[] sub(float[] a, float[] b) {
        return new float[]{a[0] - b[0], a[1] - b[1], a[2] - b[2]};
    }

    static float[] mul(float[] a, float k) {
        return new float[]{a[0] * k, a[1] * k, a[2] * k};
    }
}
