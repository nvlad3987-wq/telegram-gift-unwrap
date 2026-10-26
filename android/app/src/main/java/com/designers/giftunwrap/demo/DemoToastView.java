package com.designers.giftunwrap.demo;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.RectF;
import android.view.View;

import com.designers.giftunwrap.GUMotion;
import com.designers.giftunwrap.GiftArt;

/**
 * Telegram's undo-overlay toast from the kit ("Jingle Bells #18 082 is now on your profile.
 * View"), above the tab bar, rising on the menu spring, with the gift's animated model as icon.
 */
public class DemoToastView extends View {
    private final Bitmap image;
    private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG | Paint.FILTER_BITMAP_FLAG);
    private final RectF rect = new RectF();
    private GiftArt icon;
    private long shownAt = -1;

    public DemoToastView(Context context) {
        super(context);
        image = DemoAssets.kit(context, "toast");
    }

    void show(GiftArt icon) {
        this.icon = icon;
        shownAt = GUMotion.nowNanos();
        postInvalidateOnAnimation();
    }

    @Override
    protected void onDraw(Canvas canvas) {
        if (shownAt < 0) {
            return;
        }
        float age = (GUMotion.nowNanos() - shownAt) / 1e9f;
        float k = getWidth() / DemoAssets.KIT_WIDTH;
        float in = GUMotion.spring(age, GUMotion.MENU);
        float out = GUMotion.easeIn(GUMotion.seg(age, 2.55f, 0.32f));
        float y = (726f + (1f - in) * 90f + out * 30f) * k;
        float s = 0.92f + 0.08f * GUMotion.clamp(in);
        float a = GUMotion.clamp(in * 1.6f) * (1f - out);
        canvas.save();
        canvas.scale(s, s, 201f * k, y + 28f * k);
        paint.setAlpha((int) (255 * a));
        rect.set(16f * k, y, 386f * k, y + 56f * k);
        canvas.drawBitmap(image, null, rect, paint);
        if (icon != null) {
            icon.draw(canvas, 44f * k, y + 28f * k, 36f * k, 0f, 0f, a, age);
        }
        canvas.restore();
        if (age < 3f) {
            postInvalidateOnAnimation();
        }
    }
}
