package com.designers.giftunwrap;

import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.RectF;
import android.graphics.drawable.Drawable;

/**
 * A gift's artwork, animated the way Telegram animates it.
 * <ul>
 * <li>Inside Telegram the adapters pass the gift's own animated sticker drawable
 * ({@code RLottieDrawable} on Android), which animates itself.</li>
 * <li>The demos pass frames rendered from the original Lottie file of the model
 * (512 × 512, 60 fps, 3 s loop in Telegram; the demo bundles 30 fps).</li>
 * <li>A single bitmap still works (static).</li>
 * </ul>
 */
public final class GiftArt {
    public final Drawable drawable;
    public final Bitmap[] frames;
    public final float fps;
    public final Bitmap still;
    private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG | Paint.FILTER_BITMAP_FLAG);
    private final RectF rect = new RectF();

    private GiftArt(Drawable drawable, Bitmap[] frames, float fps, Bitmap still) {
        this.drawable = drawable;
        this.frames = frames;
        this.fps = fps;
        this.still = still;
    }

    public static GiftArt of(Bitmap bitmap) {
        return new GiftArt(null, null, 0f, bitmap);
    }

    public static GiftArt of(Drawable drawable) {
        return new GiftArt(drawable, null, 0f, null);
    }

    public static GiftArt frames(Bitmap[] frames, float fps) {
        return new GiftArt(null, frames, fps, frames.length > 0 ? frames[0] : null);
    }

    public boolean isAnimated() {
        return drawable != null || (frames != null && frames.length > 1);
    }

    /** The frame shown at {@code time} seconds (loops). */
    public Bitmap frameAt(float time) {
        if (frames == null || frames.length == 0) {
            return still;
        }
        int i = (int) Math.floor(Math.max(0f, time) * fps) % frames.length;
        return frames[i];
    }

    /** Draws the artwork centred at (cx, cy) in a {@code size} square. */
    public void draw(Canvas canvas, float cx, float cy, float size, float rotationDeg, float squash, float alpha, float time) {
        if (alpha <= 0.001f || size <= 0.5f) {
            return;
        }
        canvas.save();
        canvas.translate(cx, cy);
        canvas.rotate(rotationDeg);
        canvas.scale(1f + squash, 1f - squash);
        int half = Math.round(size / 2f);
        if (drawable != null) {
            drawable.setBounds(-half, -half, half, half);
            drawable.setAlpha((int) (255 * GUMotion.clamp(alpha)));
            drawable.draw(canvas);
        } else {
            Bitmap b = frameAt(time);
            if (b != null) {
                float k = size / Math.max(b.getWidth(), b.getHeight());
                rect.set(-b.getWidth() * k / 2f, -b.getHeight() * k / 2f, b.getWidth() * k / 2f, b.getHeight() * k / 2f);
                paint.setAlpha((int) (255 * GUMotion.clamp(alpha)));
                canvas.drawBitmap(b, null, rect, paint);
            }
        }
        canvas.restore();
    }
}
