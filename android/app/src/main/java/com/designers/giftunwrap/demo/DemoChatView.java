package com.designers.giftunwrap.demo;

import android.annotation.SuppressLint;
import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.RectF;
import android.view.MotionEvent;
import android.view.View;

import com.designers.giftunwrap.GUMotion;

/**
 * The chat with Mia, drawn from the Telegram iOS 26 kit: wallpaper, glass header, bubbles,
 * input bar. A gift message arrives (older messages slide up 260 pt on Telegram's insertion
 * spring, the card rises in); tapping the card opens the gift.
 */
public class DemoChatView extends View {
    private final Bitmap base, messages, card;
    private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG | Paint.FILTER_BITMAP_FLAG);
    private final RectF rect = new RectF();
    private long arrivalStart = -1;
    private long pressStart = -1, releaseStart = -1;
    private boolean pressed;
    Runnable onGiftTapped;

    /** Card frame and sticker slot on the kit screen (pt). */
    private static final float CARD_X = 86f, CARD_Y = 544f, CARD_W = 230f, CARD_H = 242f;
    private static final float SLOT_X = 201.5f, SLOT_Y = 617f, SLOT_R = 42f;

    public DemoChatView(Context context) {
        super(context);
        base = DemoAssets.kit(context, "chat_base");
        messages = DemoAssets.kit(context, "chat_msgs");
        card = DemoAssets.kit(context, "gift_card");
    }

    /** px per kit point. */
    float k() {
        return getWidth() / DemoAssets.KIT_WIDTH;
    }

    float slotX() {
        return SLOT_X * k();
    }

    float slotY() {
        return SLOT_Y * k();
    }

    /** Slot sphere radius in px. */
    float slotRadius() {
        return SLOT_R * k();
    }

    void playArrival() {
        arrivalStart = GUMotion.nowNanos();
        postInvalidateOnAnimation();
    }

    private float age() {
        return arrivalStart < 0 ? -1f : (GUMotion.nowNanos() - arrivalStart) / 1e9f;
    }

    @SuppressLint("ClickableViewAccessibility")
    @Override
    public boolean onTouchEvent(MotionEvent e) {
        float k = k();
        rect.set(CARD_X * k, CARD_Y * k, (CARD_X + CARD_W) * k, (CARD_Y + CARD_H) * k);
        switch (e.getActionMasked()) {
            case MotionEvent.ACTION_DOWN:
                if (age() > 0.6f && rect.contains(e.getX(), e.getY())) {
                    pressed = true;
                    pressStart = GUMotion.nowNanos();
                    releaseStart = -1;
                    invalidate();
                    return true;
                }
                return false;
            case MotionEvent.ACTION_UP:
                if (pressed) {
                    pressed = false;
                    releaseStart = GUMotion.nowNanos();
                    invalidate();
                    if (rect.contains(e.getX(), e.getY()) && onGiftTapped != null) {
                        onGiftTapped.run();
                    }
                }
                return true;
            case MotionEvent.ACTION_CANCEL:
                pressed = false;
                releaseStart = GUMotion.nowNanos();
                return true;
            default:
                return pressed;
        }
    }

    @Override
    protected void onDraw(Canvas canvas) {
        float w = getWidth(), k = k();
        float h = base.getHeight() * w / base.getWidth();
        rect.set(0, 0, w, h);
        canvas.drawBitmap(base, null, rect, paint);
        float t = age() - 0.0f;
        float ins = GUMotion.spring(t, GUMotion.MENU);
        rect.set(0, -260f * k * ins, w, h - 260f * k * ins);
        canvas.drawBitmap(messages, null, rect, paint);
        float cin = GUMotion.spring(t - 0.04f, GUMotion.MENU);
        if (cin > 0f) {
            float press = 1f;
            if (pressed) {
                press = GUMotion.lerp(1f, 0.965f, GUMotion.clamp((GUMotion.nowNanos() - pressStart) / 1e9f / 0.08f));
            } else if (releaseStart > 0) {
                press = GUMotion.lerp(0.965f, 1f, GUMotion.spring((GUMotion.nowNanos() - releaseStart) / 1e9f, GUMotion.BOUNCE));
            }
            float s = (0.86f + 0.14f * GUMotion.clamp(cin)) * press;
            canvas.save();
            canvas.translate(0, (1f - cin) * 260f * k);
            canvas.scale(s, s, (CARD_X + CARD_W / 2f) * k, (CARD_Y + CARD_H) * k);
            paint.setAlpha((int) (255 * GUMotion.clamp(cin * 1.4f)));
            rect.set(CARD_X * k, CARD_Y * k, (CARD_X + CARD_W) * k, (CARD_Y + CARD_H) * k);
            canvas.drawBitmap(card, null, rect, paint);
            if (pressed || (releaseStart > 0 && (GUMotion.nowNanos() - releaseStart) / 1e9f < 0.25f)) {
                Paint hi = new Paint(Paint.ANTI_ALIAS_FLAG);
                float fade = pressed ? 1f : 1f - (GUMotion.nowNanos() - releaseStart) / 1e9f / 0.25f;
                hi.setColor(GUMotion.withAlpha(0xff000000, 0.14f * fade));
                canvas.drawRoundRect(rect, 26f * k, 26f * k, hi);
            }
            paint.setAlpha(255);
            canvas.restore();
        }
        if (t < 1.5f || pressed || releaseStart > 0 && (GUMotion.nowNanos() - releaseStart) / 1e9f < 1f) {
            postInvalidateOnAnimation();
        }
    }
}
