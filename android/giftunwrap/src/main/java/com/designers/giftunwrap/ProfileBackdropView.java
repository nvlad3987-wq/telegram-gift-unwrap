package com.designers.giftunwrap;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Path;
import android.view.View;

/**
 * A profile header that takes a collectible's backdrop: the colour spreads from the point where
 * the gift lands and the symbol pattern fills the header behind the wave (an even field, kept
 * clear around the avatar). Timed on a {@link GiftOrbitView}'s clock so it lands with the gift.
 */
public class ProfileBackdropView extends View {
    private PatternBackdrop backdrop;
    private GiftOrbitView clock;
    private float landing = -1f;
    private float avatarX, avatarY, originX, originY;
    private final Path clip = new Path();

    public ProfileBackdropView(Context context) {
        super(context);
    }

    public void setAvatarCenter(float x, float y) {
        avatarX = x;
        avatarY = y;
        if (backdrop != null) {
            backdrop.centerX = x;
            backdrop.centerY = y;
        }
    }

    /** @param originX where the wave starts (the gift's landing point), in this view's pixels */
    public void prepare(GiftUnwrapContent.Backdrop colors, Bitmap symbol, GiftOrbitView clock, float landing, float originX, float originY) {
        backdrop = new PatternBackdrop(colors, symbol, null);
        backdrop.centerX = avatarX;
        backdrop.centerY = avatarY;
        backdrop.gradientRadius = GUMotion.dp(300f);
        backdrop.scale = 0.78f;
        backdrop.symbolSizeDp = 26f;
        backdrop.alpha = 0.5f;
        backdrop.holeDp = 92f;
        this.clock = clock;
        this.landing = landing;
        this.originX = originX;
        this.originY = originY;
        invalidate();
    }

    @Override
    protected void onDraw(Canvas canvas) {
        if (backdrop == null || clock == null) {
            return;
        }
        float age = clock.now() - landing;
        float r = age > -0.03f ? GUMotion.dp(620f) * GUMotion.bezier(0.25f, 0.75f, 0.3f, 1f, (age + 0.03f) / 0.85f) : 0f;
        if (r > 0.5f) {
            clip.rewind();
            clip.addCircle(originX, originY, r, Path.Direction.CW);
            backdrop.draw(canvas, clip, getWidth(), getHeight(), age, originX, originY, GUMotion.dp(700f), 0f);
        }
        if (age < 3f) {
            postInvalidateOnAnimation();
        }
    }
}
