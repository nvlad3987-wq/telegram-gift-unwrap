package com.designers.giftunwrap;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.RectF;
import android.view.View;

/**
 * Overlay that flies the gift from the reveal to a (moving) target — e.g. its slot in the
 * profile orbit — along a curve, shrinking, with a sparkle trail.
 */
public class GiftFlightView extends View {
    public interface Target {
        /** {x, y, size} in this view's pixels at time {@code t} (seconds since the flight started). */
        float[] at(float t);
    }

    private final Effects trail;
    private GiftArt gift;
    private float artClock;
    private RectF from;
    private float startRotation;
    private Target target;
    private float duration = 1.25f;
    private long startNanos;
    private Runnable completion;
    private boolean flying;

    public GiftFlightView(Context context, int tint) {
        super(context);
        trail = new Effects(tint);
        setWillNotDraw(false);
    }

    /** @param artClock the gift's animation time at the start (keeps the model's loop seamless) */
    public void fly(GiftArt gift, float artClock, RectF from, float rotation, float duration, Target target, Runnable completion) {
        this.gift = gift;
        this.artClock = artClock;
        this.from = from;
        this.startRotation = rotation;
        this.duration = duration;
        this.target = target;
        this.completion = completion;
        this.startNanos = GUMotion.nowNanos();
        this.flying = true;
        invalidate();
    }

    @Override
    protected void onDraw(Canvas canvas) {
        float t = (GUMotion.nowNanos() - startNanos) / 1e9f;
        if (flying && gift != null) {
            float u = GUMotion.clamp(t / duration);
            float e = GUMotion.bezier(0.42f, 0f, 0.2f, 1f, u);
            float[] end = target.at(t);
            float p0x = from.centerX(), p0y = from.centerY();
            float p1x = p0x - GUMotion.dp(10f), p1y = p0y - GUMotion.dp(150f);
            float p2x = end[0] - GUMotion.dp(70f), p2y = end[1] - GUMotion.dp(110f);
            float v = 1f - e;
            float x = v * v * v * p0x + 3 * v * v * e * p1x + 3 * v * e * e * p2x + e * e * e * end[0];
            float y = v * v * v * p0y + 3 * v * v * e * p1y + 3 * v * e * e * p2y + e * e * e * end[1];
            float size = GUMotion.lerp(from.width() * 1.08f, end[2], GUMotion.easeOut(GUMotion.clamp(u * 1.15f)));
            float rz = startRotation * (1f - e) + (float) Math.toDegrees(Math.sin(e * Math.PI) * -0.35);
            float q = 0.06f * (float) Math.sin(e * Math.PI * 3) * (1f - e);
            if (u < 1f) {
                trail.addTrail(x, y, t);
                gift.draw(canvas, x, y, size, rz, q, 1f, artClock + t);
            } else {
                flying = false;
                if (completion != null) {
                    Runnable r = completion;
                    completion = null;
                    post(r);
                }
            }
        }
        trail.drawFront(canvas, -10f, 0f, 0f, 0f, 0f, 0f, t);
        if (flying || t < duration + 1f) {
            postInvalidateOnAnimation();
        }
    }
}
