package com.designers.giftunwrap;

import android.content.res.Resources;

/**
 * Motion tokens shared with the iOS version (Telegram's springs and curves).
 * The whole unwrap is evaluated as closed-form functions of time, so every frame is
 * deterministic and both platforms use the same numbers.
 */
public final class GUMotion {
    private GUMotion() {
    }

    /** mass, stiffness, damping */
    /**
     * The animation clock, in nanoseconds: {@code SystemClock.uptimeMillis}, the same monotonic
     * clock as touch events, {@code postDelayed} and Choreographer frames (and the test clock).
     */
    public static long nowNanos() {
        return android.os.SystemClock.uptimeMillis() * 1_000_000L;
    }

    public static final float[] BOUNCE = {5f, 900f, 88f};
    public static final float[] MENU = {5f, 900f, 104f};
    public static final float[] SHEET = {5f, 900f, 124f};

    /** Normalised spring response 0 → 1 at time t (seconds). */
    public static float spring(float t, float[] s) {
        if (t <= 0f) {
            return 0f;
        }
        double m = s[0], k = s[1], d = s[2];
        double w = Math.sqrt(k / m);
        double z = d / (2.0 * Math.sqrt(k * m));
        if (z < 1.0) {
            double wd = w * Math.sqrt(1.0 - z * z);
            return (float) (1.0 - Math.exp(-z * w * t) * (Math.cos(wd * t) + z * w / wd * Math.sin(wd * t)));
        }
        return (float) (1.0 - Math.exp(-w * t) * (1.0 + w * t));
    }

    /** Cubic bezier easing (CSS semantics), x in 0..1. */
    public static float bezier(float x1, float y1, float x2, float y2, float x) {
        x = clamp(x);
        float lo = 0f, hi = 1f, u = x;
        for (int i = 0; i < 24; i++) {
            u = (lo + hi) * 0.5f;
            float bx = 3f * (1f - u) * (1f - u) * u * x1 + 3f * (1f - u) * u * u * x2 + u * u * u;
            if (bx < x) {
                lo = u;
            } else {
                hi = u;
            }
        }
        return 3f * (1f - u) * (1f - u) * u * y1 + 3f * (1f - u) * u * u * y2 + u * u * u;
    }

    public static float tg(float u) {
        return bezier(0.38f, 0.7f, 0.125f, 1f, u);
    }

    public static float easeOut(float u) {
        return bezier(0.2f, 0.9f, 0.3f, 1f, u);
    }

    public static float easeInOut(float u) {
        return bezier(0.42f, 0f, 0.58f, 1f, u);
    }

    public static float easeIn(float u) {
        return bezier(0.5f, 0f, 0.9f, 0.6f, u);
    }

    public static float clamp(float x) {
        return Math.min(1f, Math.max(0f, x));
    }

    public static float clamp(float x, float a, float b) {
        return Math.min(b, Math.max(a, x));
    }

    public static float lerp(float a, float b, float u) {
        return a + (b - a) * u;
    }

    public static float seg(float t, float t0, float d) {
        return clamp((t - t0) / d);
    }

    public static float rubberBand(float overshoot, float dimension) {
        float c = 0.55f;
        return (overshoot * dimension * c) / (dimension + c * Math.abs(overshoot));
    }

    public static float hash(float n) {
        double s = Math.sin(n * 127.1 + 311.7) * 43758.5453;
        return (float) (s - Math.floor(s));
    }

    public static float dp(float value) {
        return value * Resources.getSystem().getDisplayMetrics().density;
    }

    public static int mix(int a, int b, float u) {
        int aa = (a >>> 24) & 0xff, ar = (a >> 16) & 0xff, ag = (a >> 8) & 0xff, ab = a & 0xff;
        int ba = (b >>> 24) & 0xff, br = (b >> 16) & 0xff, bg = (b >> 8) & 0xff, bb = b & 0xff;
        return ((int) (aa + (ba - aa) * u) << 24) | ((int) (ar + (br - ar) * u) << 16) | ((int) (ag + (bg - ag) * u) << 8) | (int) (ab + (bb - ab) * u);
    }

    public static int withAlpha(int color, float alpha) {
        int a = (int) (((color >>> 24) & 0xff) * clamp(alpha));
        return (a << 24) | (color & 0x00ffffff);
    }

    /** Deterministic pseudo random numbers (same LCG as iOS). */
    public static final class Rand {
        private long state;

        public Rand(long seed) {
            state = seed & 0xffffffffL;
        }

        public float next() {
            state = (state * 1664525L + 1013904223L) & 0xffffffffL;
            return state / 4294967296f;
        }

        public float range(float a, float b) {
            return a + (b - a) * next();
        }
    }
}
