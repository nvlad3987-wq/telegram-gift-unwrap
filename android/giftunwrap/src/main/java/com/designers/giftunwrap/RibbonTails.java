package com.designers.giftunwrap;

import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.PathMeasure;

/** The two ribbon tails (the right one is the pull tab), the "pull here" hint and the cracks. */
final class RibbonTails {
    private final Paint body = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint shine = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint hint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Path path = new Path();

    RibbonTails() {
        body.setStyle(Paint.Style.STROKE);
        body.setStrokeCap(Paint.Cap.ROUND);
        body.setColor(0xffff4f93);
        body.setShadowLayer(GUMotion.dp(3f), 0f, GUMotion.dp(2f), 0x597a0f3e);
        shine.setStyle(Paint.Style.STROKE);
        shine.setStrokeCap(Paint.Cap.ROUND);
        shine.setColor(0xd9ffb3d1);
        hint.setStyle(Paint.Style.STROKE);
        hint.setColor(0xffffffff);
    }

    /** Ribbon colours: the gift's backdrop (base, light, dark). */
    void setColors(int base, int light, int dark) {
        body.setColor(base);
        body.setShadowLayer(GUMotion.dp(3f), 0f, GUMotion.dp(2f), GUMotion.withAlpha(dark, 0.35f));
        shine.setColor(GUMotion.withAlpha(light, 0.85f));
    }

    void draw(Canvas canvas, float kx, float ky, float ex, float ey, float lx, float ly, float sag, float alpha, float hintPhase, float scale) {
        if (alpha <= 0f) {
            return;
        }
        body.setStrokeWidth(GUMotion.dp(11f) * scale);
        shine.setStrokeWidth(GUMotion.dp(3f) * scale);
        int a = (int) (255 * alpha);
        // left tail first (it hangs behind the right one)
        curve(kx, ky, lx, ly, -GUMotion.dp(12f));
        body.setAlpha(a);
        canvas.drawPath(path, body);
        curve(kx - GUMotion.dp(2f), ky - GUMotion.dp(1f), lx - GUMotion.dp(2.5f), ly - GUMotion.dp(1f), -GUMotion.dp(12f));
        shine.setAlpha((int) (217 * alpha));
        canvas.drawPath(path, shine);

        curve(kx, ky, ex, ey, sag);
        canvas.drawPath(path, body);
        curve(kx - GUMotion.dp(2f), ky - GUMotion.dp(1f), ex - GUMotion.dp(2.5f), ey - GUMotion.dp(1f), sag);
        canvas.drawPath(path, shine);

        if (hintPhase >= 0f) {
            float r = GUMotion.dp(14f + 16f * hintPhase);
            hint.setStrokeWidth(GUMotion.dp(1.5f));
            hint.setAlpha((int) (230 * (1f - hintPhase) * alpha));
            canvas.drawCircle(ex, ey, r, hint);
        }
    }

    private void curve(float ax, float ay, float bx, float by, float sag) {
        float mx = (ax + bx) * 0.5f, my = (ay + by) * 0.5f;
        float dx = bx - ax, dy = by - ay;
        float len = Math.max(0.001f, (float) Math.hypot(dx, dy));
        float nx = -dy / len, ny = dx / len;
        path.rewind();
        path.moveTo(ax, ay);
        path.quadTo(mx + nx * sag, my + ny * sag, bx, by);
    }

    /** Hairline cracks racing from the knot over the glass. Built once in unit-disc space. */
    static final class Cracks {
        private final Path unit = new Path();
        private final Path scaled = new Path();
        private final Path partial = new Path();
        private final Paint line = new Paint(Paint.ANTI_ALIAS_FLAG);
        private final Paint glow = new Paint(Paint.ANTI_ALIAS_FLAG);
        private final android.graphics.Matrix matrix = new android.graphics.Matrix();
        private GUMotion.Rand rng;

        Cracks(float ox, float oy) {
            line.setStyle(Paint.Style.STROKE);
            line.setStrokeJoin(Paint.Join.ROUND);
            line.setColor(0xffffffff);
            glow.setStyle(Paint.Style.STROKE);
            glow.setStrokeJoin(Paint.Join.ROUND);
            glow.setColor(0x8ccfe6ff);
            rng = new GUMotion.Rand(5);
            for (int i = 0; i < 7; i++) {
                float a = (float) (i / 7.0 * 2.0 * Math.PI) + rng.range(-0.3f, 0.3f);
                branch(ox, oy, a, 9 + (int) (rng.next() * 5f), 0);
            }
        }

        private void branch(float x, float y, float a, int steps, int depth) {
            unit.moveTo(x, y);
            for (int i = 0; i < steps; i++) {
                a += rng.range(-0.55f, 0.55f);
                float len = rng.range(0.07f, 0.15f);
                x += (float) Math.cos(a) * len;
                y += (float) Math.sin(a) * len;
                unit.lineTo(x, y);
                if (Math.hypot(x, y) > 1.05) {
                    break;
                }
                if (depth < 2 && rng.next() < 0.28f) {
                    float side = rng.next() < 0.5f ? -1f : 1f;
                    branch(x, y, a + side * rng.range(0.5f, 1.1f), 3 + (int) (rng.next() * 4f), depth + 1);
                    unit.moveTo(x, y);
                }
            }
        }

        void draw(Canvas canvas, Path clip, float cx, float cy, float radius, float progress, float alpha) {
            if (alpha <= 0f || progress <= 0f) {
                return;
            }
            matrix.reset();
            matrix.postScale(radius, radius);
            matrix.postTranslate(cx, cy);
            unit.transform(matrix, scaled);
            partial.rewind();
            // Reveal every contour up to `progress` of its length.
            PathMeasure pm = new PathMeasure(scaled, false);
            do {
                float l = pm.getLength();
                pm.getSegment(0f, l * progress, partial, true);
            } while (pm.nextContour());
            canvas.save();
            canvas.clipPath(clip);
            glow.setStrokeWidth(GUMotion.dp(4f));
            glow.setAlpha((int) (140 * alpha));
            canvas.drawPath(partial, glow);
            line.setStrokeWidth(GUMotion.dp(1.2f));
            line.setAlpha((int) (255 * alpha));
            canvas.drawPath(partial, line);
            canvas.restore();
        }
    }
}
