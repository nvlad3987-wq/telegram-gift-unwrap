package com.designers.giftunwrap.demo;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.RadialGradient;
import android.graphics.RectF;
import android.graphics.Shader;
import android.view.View;
import android.widget.FrameLayout;

import com.designers.giftunwrap.Collectible;
import com.designers.giftunwrap.GiftOrbitView;
import com.designers.giftunwrap.ProfileBackdropView;

import java.util.List;

/**
 * Alex's own profile (Settings) from the Telegram iOS 26 kit: the header is live — profile
 * colour, the collectible backdrop that takes over, and the ring of collectibles around the
 * avatar — under the kit's foreground (QR / Edit glass buttons, name, list, tab bar).
 */
public class DemoProfileView extends FrameLayout {
    private final HeaderBackground headerBg;
    private final ProfileBackdropView collectible;
    private final GiftOrbitView orbit;
    private final Foreground foreground;

    public DemoProfileView(Context context, List<Collectible> collectibles) {
        super(context);
        setBackgroundColor(0xfff2f2f7);
        headerBg = new HeaderBackground(context);
        addView(headerBg);
        collectible = new ProfileBackdropView(context);
        addView(collectible);
        orbit = new GiftOrbitView(context);
        orbit.setGifts(collectibles);
        orbit.setAvatarBitmap(DemoAssets.kit(context, "avatar_ar"));
        addView(orbit, new LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT));
        foreground = new Foreground(context, DemoAssets.kit(context, "profile_fg"));
        addView(foreground, new LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT));
    }

    GiftOrbitView orbit() {
        return orbit;
    }

    float k() {
        return getWidth() / DemoAssets.KIT_WIDTH;
    }

    /** The collectible lands at {@code time} (orbit clock): reserve its slot, recolour the header from there. */
    void prepareLanding(Collectible gift, float time) {
        orbit.prepareNewcomer(gift, time);
        float[] p = orbit.landingPoint(time);
        collectible.prepare(gift.backdrop, gift.symbol, orbit, time, p[0], p[1]);
    }

    @Override
    protected void onLayout(boolean changed, int left, int top, int right, int bottom) {
        super.onLayout(changed, left, top, right, bottom);
        int w = right - left;
        float k = w / DemoAssets.KIT_WIDTH;
        int headerH = Math.round(268f * k);
        headerBg.layout(0, 0, w, headerH);
        collectible.layout(0, 0, w, headerH);
        orbit.setAvatar(201f * k, 142f * k, "AR");
        collectible.setAvatarCenter(201f * k, 142f * k);
    }

    /** A Telegram profile colour (violet) as the header before the collectible arrives. */
    static final class HeaderBackground extends View {
        private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);

        HeaderBackground(Context context) {
            super(context);
        }

        @Override
        protected void onDraw(Canvas canvas) {
            float w = getWidth(), k = w / DemoAssets.KIT_WIDTH;
            paint.setShader(new RadialGradient(201f * k, 142f * k, 330f * k, 0xffa98bff, 0xff6c4bd8, Shader.TileMode.CLAMP));
            canvas.drawRect(0, 0, w, getHeight(), paint);
        }
    }

    /** The kit's profile screen with a transparent header. */
    static final class Foreground extends View {
        private final Bitmap image;
        private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG | Paint.FILTER_BITMAP_FLAG);
        private final RectF rect = new RectF();

        Foreground(Context context, Bitmap image) {
            super(context);
            this.image = image;
        }

        @Override
        protected void onDraw(Canvas canvas) {
            float w = getWidth();
            rect.set(0, 0, w, image.getHeight() * w / image.getWidth());
            canvas.drawBitmap(image, null, rect, paint);
        }
    }
}
