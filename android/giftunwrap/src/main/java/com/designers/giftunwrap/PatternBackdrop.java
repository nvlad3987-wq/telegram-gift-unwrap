package com.designers.giftunwrap;

import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.PorterDuff;
import android.graphics.PorterDuffColorFilter;
import android.graphics.RadialGradient;
import android.graphics.Rect;
import android.graphics.RectF;
import android.graphics.Shader;
import android.graphics.drawable.Drawable;

import java.util.ArrayList;
import java.util.List;

/**
 * A collectible's backdrop: Telegram's radial gradient (center → edge colour) and the symbol
 * pattern as an even field that fills the whole area (a hex grid anchored on the gift, fading a
 * little with distance and kept clear right behind the gift). Symbols pop in as a wave spreads
 * from a point. Used full-screen behind the revealed gift, in the gift sheet header and in the
 * profile header.
 */
final class PatternBackdrop {
    static final class Item {
        final float x, y, distance, jitter;

        Item(float x, float y, float jitter) {
            this.x = x;
            this.y = y;
            this.distance = (float) Math.hypot(x, y);
            this.jitter = jitter;
        }
    }

    private final GiftUnwrapContent.Backdrop backdrop;
    private final Bitmap symbol;
    private final Drawable symbolDrawable;
    private final List<Item> items = field(52f);
    private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint symbolPaint = new Paint(Paint.ANTI_ALIAS_FLAG | Paint.FILTER_BITMAP_FLAG);
    private final RectF dst = new RectF();
    private final Rect src = new Rect();

    /** Pattern anchor (the gift), gradient radius, field scale and the clear radius around the gift. */
    float centerX, centerY, gradientRadius, scale = 1f;
    float symbolSizeDp = 26f, alpha = 0.62f, holeDp = 70f;

    PatternBackdrop(GiftUnwrapContent.Backdrop backdrop, Bitmap symbol, Drawable symbolDrawable) {
        this.backdrop = backdrop;
        this.symbol = symbol != null ? symbol : Snowflake.bitmap(96);
        this.symbolDrawable = symbolDrawable;
        symbolPaint.setColorFilter(new PorterDuffColorFilter(backdrop.pattern, PorterDuff.Mode.SRC_IN));
        src.set(0, 0, this.symbol.getWidth(), this.symbol.getHeight());
    }

    /**
     * @param clip       area to fill (a growing circle, the sheet header, …)
     * @param waveAge    seconds since the pop-in wave started (large → everything shown)
     * @param waveX      origin of the wave
     * @param speed      wave speed in px per second
     * @param backlight  0..1 soft white light behind the gift
     */
    void draw(Canvas canvas, Path clip, float width, float height, float waveAge, float waveX, float waveY, float speed, float backlight) {
        canvas.save();
        canvas.clipPath(clip);
        paint.setShader(new RadialGradient(centerX, centerY, Math.max(1f, gradientRadius),
                new int[]{backdrop.inner, backdrop.outer}, null, Shader.TileMode.CLAMP));
        canvas.drawRect(0f, 0f, width, height, paint);
        if (backlight > 0f) {
            float r = GUMotion.dp(150f) * scale;
            paint.setShader(new RadialGradient(centerX, centerY, r,
                    new int[]{GUMotion.withAlpha(0xffe2eeff, 0.55f * backlight), GUMotion.withAlpha(0xffbed4ff, 0.22f * backlight), 0x00a0beff},
                    new float[]{0f, 0.45f, 1f}, Shader.TileMode.CLAMP));
            canvas.drawCircle(centerX, centerY, r, paint);
        }
        paint.setShader(null);

        float dp = GUMotion.dp(1f);
        float hole = holeDp * dp;
        for (Item it : items) {
            float x = centerX + it.x * dp * scale, y = centerY + it.y * dp * scale;
            float size = symbolSizeDp * dp * scale * (1.08f - 0.22f * GUMotion.clamp(it.distance / 520f));
            if (x < -size || x > width + size || y < -size || y > height + size) {
                continue;
            }
            float a = waveAge - (float) Math.hypot(x - waveX, y - waveY) / speed - it.jitter * 0.06f;
            if (a <= 0f) {
                continue;
            }
            float k = GUMotion.spring(a, GUMotion.BOUNCE);
            float d = it.distance * dp * scale;
            float al = alpha * GUMotion.clamp(a / 0.1f) * (1f - 0.4f * GUMotion.clamp(it.distance / 600f)) * smooth(hole * 0.62f, hole * 1.25f, d);
            float half = size * 0.5f * Math.max(0f, k);
            if (al <= 0.003f || half < 0.5f) {
                continue;
            }
            if (symbolDrawable != null) {
                symbolDrawable.setBounds((int) (x - half), (int) (y - half), (int) (x + half), (int) (y + half));
                symbolDrawable.setAlpha((int) (255 * al));
                symbolDrawable.draw(canvas);
            } else {
                dst.set(x - half, y - half, x + half, y + half);
                symbolPaint.setAlpha((int) (255 * al));
                canvas.drawBitmap(symbol, src, dst, symbolPaint);
            }
        }
        canvas.restore();
    }

    private static float smooth(float a, float b, float x) {
        float u = GUMotion.clamp((x - a) / (b - a));
        return u * u * (3f - 2f * u);
    }

    /** An even hex grid of symbol positions (dp offsets from the anchor). */
    static List<Item> field(float spacing) {
        float h = spacing * 0.866f;
        List<Item> out = new ArrayList<>();
        for (int j = -22; j <= 22; j++) {
            for (int i = -10; i <= 10; i++) {
                float x = (i + ((j & 1) != 0 ? 0.5f : 0f)) * spacing, y = j * h;
                out.add(new Item(x, y, GUMotion.hash(i * 31.7f + j * 7.3f)));
            }
        }
        return out;
    }
}
