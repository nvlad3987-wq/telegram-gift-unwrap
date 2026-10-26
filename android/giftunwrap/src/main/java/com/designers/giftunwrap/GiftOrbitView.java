package com.designers.giftunwrap;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.LinearGradient;
import android.graphics.Paint;
import android.graphics.PorterDuff;
import android.graphics.PorterDuffColorFilter;
import android.graphics.RadialGradient;
import android.graphics.RectF;
import android.graphics.Shader;
import android.graphics.Typeface;
import android.view.View;

import java.util.ArrayList;
import java.util.List;

/**
 * The profile avatar with the owner's collectibles circling it like a planet's ring. Each one
 * is shown as Telegram shows a collectible: its animated model on its own backdrop (center →
 * edge gradient with the symbol pattern) and a soft glow in the backdrop colour; they hover
 * ±1.6 dp and wiggle a little, like the gifts on Telegram's profile cover. The far half of the
 * ring passes behind the avatar. A newcomer can be announced for a landing time; the others
 * ease from N to N+1 slots to make room.
 */
public class GiftOrbitView extends View {
    private final List<Collectible> gifts = new ArrayList<>();
    private Collectible newcomer;
    private float arrival = -1f;
    private final long base = GUMotion.nowNanos();
    private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG | Paint.FILTER_BITMAP_FLAG);
    private final Paint symbolPaint = new Paint(Paint.ANTI_ALIAS_FLAG | Paint.FILTER_BITMAP_FLAG);
    private final Paint text = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final RectF rect = new RectF();
    private float avatarX, avatarY;
    private String letter = "A";
    private Bitmap avatar;
    private final float radiusX = GUMotion.dp(150f), radiusY = GUMotion.dp(30f), depth = GUMotion.dp(80f), tilt = -0.07f;
    private static final float OMEGA = 0.36f;
    private static final float DISC_DP = 19f, MODEL_DP = 34f;

    public GiftOrbitView(Context context) {
        super(context);
        text.setColor(0xffffffff);
        text.setTextAlign(Paint.Align.CENTER);
        text.setTypeface(Typeface.create("sans-serif", Typeface.BOLD));
        text.setTextSize(GUMotion.dp(40f));
    }

    public void setGifts(List<Collectible> collectibles) {
        gifts.clear();
        gifts.addAll(collectibles);
        invalidate();
    }

    public void setAvatar(float x, float y, String letter) {
        avatarX = x;
        avatarY = y;
        this.letter = letter;
        invalidate();
    }

    /** A photo (or Telegram's rendered avatar) instead of the letter placeholder. */
    public void setAvatarBitmap(Bitmap bitmap) {
        avatar = bitmap;
        invalidate();
    }

    public float avatarX() {
        return avatarX;
    }

    public float avatarY() {
        return avatarY;
    }

    /** Seconds on this view's clock. */
    public float now() {
        return (GUMotion.nowNanos() - base) / 1e9f;
    }

    /** Reserves the next slot for a collectible landing at {@code time} (this view's clock). */
    public void prepareNewcomer(Collectible gift, float time) {
        newcomer = gift;
        arrival = time;
        invalidate();
    }

    private float[] angles(float t) {
        int n = gifts.size();
        float k = arrival >= 0f ? GUMotion.tg(GUMotion.seg(t, arrival - 0.5f, 0.9f)) : 0f;
        float b = 1.15f + t * OMEGA;
        float[] out = new float[n + 1];
        for (int i = 0; i < n; i++) {
            float before = i * 2f * (float) Math.PI / Math.max(1, n);
            float after = i * 2f * (float) Math.PI / (n + 1);
            out[i] = b + GUMotion.lerp(before, after, k);
        }
        out[n] = b + n * 2f * (float) Math.PI / (n + 1);
        return out;
    }

    /** {x, y, z} in this view's pixels for an orbit angle. */
    public float[] position(float phi) {
        float x = (float) Math.cos(phi) * radiusX, y = (float) Math.sin(phi) * radiusY, z = (float) Math.sin(phi) * depth;
        float c = (float) Math.cos(tilt), s = (float) Math.sin(tilt);
        return new float[]{avatarX + x * c - y * s, avatarY + GUMotion.dp(4f) + x * s + y * c, z};
    }

    /** Where a newcomer landing at {@code time} will be: {x, y, depth scale}. */
    public float[] landingPoint(float time) {
        float saved = arrival;
        arrival = time;
        float[] p = position(angles(time)[gifts.size()]);
        arrival = saved;
        return new float[]{p[0], p[1], 1f + p[2] / GUMotion.dp(400f)};
    }

    /** Size of the model on the orbit (px) at depth scale 1. */
    public static float modelSize() {
        return GUMotion.dp(MODEL_DP);
    }

    @Override
    protected void onDraw(Canvas canvas) {
        float t = now();
        float[] a = angles(t);
        for (int pass = 0; pass < 2; pass++) {
            if (pass == 1) {
                drawAvatar(canvas, t);
            }
            for (int i = 0; i < gifts.size(); i++) {
                float[] p = position(a[i]);
                if ((p[2] < 0f) == (pass == 0)) {
                    drawItem(canvas, gifts.get(i), p, 1f, t, i);
                }
            }
            if (newcomer != null && arrival >= 0f && t > arrival - 0.02f) {
                float[] p = position(a[gifts.size()]);
                if ((p[2] < 0f) == (pass == 0)) {
                    drawItem(canvas, newcomer, p, Math.max(0.001f, GUMotion.spring(t - arrival + 0.02f, GUMotion.BOUNCE)), t, gifts.size());
                }
            }
        }
        postInvalidateOnAnimation();
    }

    private void drawAvatar(Canvas canvas, float t) {
        float r = GUMotion.dp(52f);
        float pulse = arrival >= 0f && t > arrival ? (float) Math.exp(-(t - arrival) * 2.4f) : 0f;
        float s = 1f + 0.035f * pulse;
        if (pulse > 0.01f) {
            paint.setStyle(Paint.Style.STROKE);
            paint.setStrokeWidth(GUMotion.dp(2.5f));
            paint.setColor(GUMotion.withAlpha(0xffffffff, 0.6f * pulse));
            canvas.drawCircle(avatarX, avatarY, r + GUMotion.dp(6f + 16f * (1f - pulse)), paint);
            paint.setStyle(Paint.Style.FILL);
        }
        canvas.save();
        canvas.scale(s, s, avatarX, avatarY);
        if (avatar != null) {
            rect.set(avatarX - r, avatarY - r, avatarX + r, avatarY + r);
            paint.setAlpha(255);
            canvas.drawBitmap(avatar, null, rect, paint);
        } else {
            // Telegram's placeholder: a vertical gradient (blue pair) with the initials
            paint.setShader(new LinearGradient(avatarX, avatarY - r, avatarX, avatarY + r, 0xff72d5fd, 0xff2a9ef1, Shader.TileMode.CLAMP));
            canvas.drawCircle(avatarX, avatarY, r, paint);
            paint.setShader(null);
            canvas.drawText(letter, avatarX, avatarY - (text.descent() + text.ascent()) / 2f, text);
        }
        canvas.restore();
    }

    private void drawItem(Canvas canvas, Collectible c, float[] p, float appear, float t, int idx) {
        float ds = 1f + p[2] / GUMotion.dp(400f);
        float x = p[0];
        float y = p[1] + (float) Math.sin(t * 2 * Math.PI / (3.8f + idx * 0.35f) + idx) * GUMotion.dp(1.6f);
        float r = GUMotion.dp(DISC_DP) * ds * appear;
        if (r < 0.3f) {
            return;
        }
        GiftUnwrapContent.Backdrop b = c.backdrop;
        // glow in the backdrop colour (Telegram: a soft light tinted with the center colour)
        paint.setShader(new RadialGradient(x, y, r * 1.9f, GUMotion.withAlpha(b.inner, 0.55f), GUMotion.withAlpha(b.inner, 0f), Shader.TileMode.CLAMP));
        canvas.drawCircle(x, y, r * 1.9f, paint);
        // the backdrop disc
        paint.setShader(new RadialGradient(x, y - r * 0.15f, r, b.inner, b.outer, Shader.TileMode.CLAMP));
        canvas.drawCircle(x, y, r, paint);
        paint.setShader(null);
        if (c.symbol != null) {
            canvas.save();
            symbolPaint.setColorFilter(new PorterDuffColorFilter(b.pattern | 0xff000000, PorterDuff.Mode.SRC_IN));
            symbolPaint.setAlpha(128);
            for (int i = 0; i < 7; i++) {
                double a = i * Math.PI * 2 / 7 + 0.3;
                float sx = x + (float) Math.cos(a) * r * 0.78f, sy = y + (float) Math.sin(a) * r * 0.78f, h = r * 0.13f;
                rect.set(sx - h, sy - h, sx + h, sy + h);
                canvas.drawBitmap(c.symbol, null, rect, symbolPaint);
            }
            canvas.restore();
        }
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(GUMotion.dp(0.6f));
        paint.setColor(0x47ffffff);
        canvas.drawCircle(x, y, r - GUMotion.dp(0.3f), paint);
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(0xff000000);
        float wiggle = (float) Math.toDegrees(Math.sin(t * 2 * Math.PI / (2.4f + idx * 0.3f) + idx * 2) * 0.04f);
        if (c.art != null) {
            c.art.draw(canvas, x, y, GUMotion.dp(MODEL_DP) * ds * appear, wiggle, 0f, 1f, t + idx * 0.73f);
        }
    }
}
