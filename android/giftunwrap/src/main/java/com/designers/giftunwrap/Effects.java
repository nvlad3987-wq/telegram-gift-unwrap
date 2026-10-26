package com.designers.giftunwrap;

import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.PorterDuff;
import android.graphics.PorterDuffColorFilter;
import android.graphics.PorterDuffXfermode;
import android.graphics.RadialGradient;
import android.graphics.RectF;
import android.graphics.Shader;

import java.util.ArrayList;
import java.util.List;

/** Flash, ring of light, aura and sparkles (burst, idle twinkles, flight trail). */
final class Effects {
    private static final class Spark {
        float birth, life, vx, vy, size, k;
        int color;
        boolean idle;
        float x, y; // trail: fixed spawn position
        boolean trail;
    }

    private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint ring = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint sparkPaint = new Paint(Paint.ANTI_ALIAS_FLAG | Paint.FILTER_BITMAP_FLAG);
    private final Bitmap sparkle = Snowflake.sparkle(32);
    private final List<Spark> sparks = new ArrayList<>();
    private final List<Spark> trail = new ArrayList<>();
    private final RectF dst = new RectF();
    private final int tint;

    Effects(int tint) {
        this.tint = tint;
        ring.setStyle(Paint.Style.STROKE);
        ring.setColor(0xffffffff);
        sparkPaint.setXfermode(new PorterDuffXfermode(PorterDuff.Mode.ADD));
        GUMotion.Rand r = new GUMotion.Rand(3);
        int[] colors = {0xffffffff, 0xffcfe6ff, 0xff9fd0ff};
        burst(r, 90, 520f, 0.01f, new float[]{5f, 12f}, new float[]{0.5f, 1.2f}, colors);
        burst(r, 30, 220f, 0.18f, new float[]{3f, 8f}, new float[]{0.6f, 1.4f}, colors);
        for (int i = 0; i < 16; i++) {
            Spark s = new Spark();
            s.idle = true;
            s.birth = GUMotion.hash(i * 3.3f) * 2f;
            s.life = 0.9f + GUMotion.hash(i) * 0.8f;
            s.size = 4f + GUMotion.hash(i + 2) * 5f;
            s.k = GUMotion.hash(i + 5);
            s.color = 0xffffffff;
            sparks.add(s);
        }
    }

    private void burst(GUMotion.Rand r, int n, float speed, float t0, float[] size, float[] life, int[] colors) {
        for (int i = 0; i < n; i++) {
            float u = r.next() * 2f - 1f;
            float a = r.next() * (float) (Math.PI * 2);
            float s = (float) Math.sqrt(1f - u * u);
            float v = speed * (0.35f + r.next() * 0.85f);
            Spark p = new Spark();
            p.birth = t0 + r.next() * 0.05f;
            p.life = GUMotion.lerp(life[0], life[1], r.next());
            p.vx = s * (float) Math.cos(a) * v;
            p.vy = -u * v;
            p.size = GUMotion.lerp(size[0], size[1], r.next());
            p.color = colors[(int) (r.next() * colors.length) % colors.length];
            p.k = r.next();
            sparks.add(p);
        }
    }

    /** Adds a trail sparkle at a point (call every frame of a flight). */
    void addTrail(float x, float y, float now) {
        Spark s = new Spark();
        s.trail = true;
        s.x = x + (GUMotion.hash(now * 37f) - 0.5f) * GUMotion.dp(14f);
        s.y = y;
        s.birth = now;
        s.life = 0.55f;
        s.size = 5f + GUMotion.hash(now * 11f) * 6f;
        s.color = trail.size() % 3 == 0 ? 0xffffffff : 0xffcfe6ff;
        s.k = GUMotion.hash(now);
        trail.add(s);
        if (trail.size() > 60) {
            trail.remove(0);
        }
    }

    void drawBehindGift(Canvas canvas, float age, float giftX, float giftY, float giftSize, float idle, float time) {
        if (age <= 0f) {
            return;
        }
        float dp = GUMotion.dp(1f);
        float aura = (0.35f + 0.65f * (float) Math.exp(-age * 1.5f)) * idle * 0.6f;
        int light = GUMotion.mix(tint, 0xffffffff, 0.7f);
        float ar = giftSize * 1.7f;
        paint.setShader(new RadialGradient(giftX, giftY, ar, GUMotion.withAlpha(light, 0.55f * aura), GUMotion.withAlpha(light, 0f), Shader.TileMode.CLAMP));
        canvas.drawCircle(giftX, giftY, ar, paint);
        paint.setShader(null);
    }

    void drawFront(Canvas canvas, float age, float cx, float cy, float giftX, float giftY, float idle, float now) {
        float dp = GUMotion.dp(1f);
        if (age > -0.02f) {
            float fl = (float) (Math.exp(-Math.pow(Math.max(0f, age) / 0.13f, 1.4f)) * GUMotion.clamp((age + 0.02f) / 0.02f));
            if (fl > 0.003f) {
                float fs = (130f + 110f * GUMotion.clamp(age / 0.3f)) * dp;
                int light = GUMotion.mix(tint, 0xffffffff, 0.7f);
                paint.setShader(new RadialGradient(cx, cy, fs, new int[]{GUMotion.withAlpha(0xffffffff, fl), GUMotion.withAlpha(light, 0.6f * fl), GUMotion.withAlpha(light, 0f)}, new float[]{0f, 0.25f, 1f}, Shader.TileMode.CLAMP));
                canvas.drawCircle(cx, cy, fs, paint);
                paint.setShader(null);
            }
        }
        if (age > 0f && age < 0.6f) {
            float r = (60f + 450f * GUMotion.easeOut(age / 0.6f)) * dp;
            ring.setStrokeWidth(3f * dp);
            ring.setAlpha((int) (255 * 0.55f * (1f - age / 0.6f)));
            canvas.drawCircle(cx, cy, r, ring);
        }
        // sparkles
        for (Spark s : sparks) {
            float a;
            float x, y;
            if (s.idle) {
                if (age < 0.65f || idle < 0.5f) {
                    continue;
                }
                a = (age - 0.65f - s.birth) % 2.2f;
                if (a < 0f || a > s.life) {
                    continue;
                }
                double ang = s.k * 6.283 + (age - s.birth) * 0.1;
                float rr = (70f + s.k * 50f) * dp;
                x = giftX + (float) Math.cos(ang) * rr;
                y = giftY + (float) Math.sin(ang) * rr * 0.75f;
            } else {
                a = age - s.birth;
                if (a < 0f || a > s.life) {
                    continue;
                }
                float d = (float) ((1.0 - Math.exp(-a * 3.0)) / 3.0);
                x = cx + s.vx * dp * d;
                y = cy + s.vy * dp * d + 90f * dp * a * a;
            }
            drawSpark(canvas, x, y, s, a);
        }
        for (Spark s : trail) {
            float a = now - s.birth;
            if (a < 0f || a > s.life) {
                continue;
            }
            drawSpark(canvas, s.x, s.y + a * 30f * dp, s, a);
        }
    }

    private void drawSpark(Canvas canvas, float x, float y, Spark s, float a) {
        float u = a / s.life;
        float alpha = (float) (Math.sin(Math.PI * Math.min(1f, u * 1.1f)) * (0.6f + 0.4f * Math.sin(a * 25f + s.k * 10f)));
        if (alpha <= 0f) {
            return;
        }
        float half = s.size * GUMotion.dp(1f) * (1f - 0.4f * u);
        dst.set(x - half, y - half, x + half, y + half);
        sparkPaint.setColorFilter(new PorterDuffColorFilter(s.color, PorterDuff.Mode.MULTIPLY));
        sparkPaint.setAlpha((int) (255 * alpha));
        canvas.drawBitmap(sparkle, null, dst, sparkPaint);
    }
}
