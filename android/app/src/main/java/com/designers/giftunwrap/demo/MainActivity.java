package com.designers.giftunwrap.demo;

import android.app.Activity;
import android.graphics.Color;
import android.graphics.RectF;
import android.os.Build;
import android.os.Bundle;
import android.view.View;
import android.view.ViewGroup;
import android.view.Window;
import android.view.WindowInsets;
import android.widget.FrameLayout;

import com.designers.giftunwrap.Collectible;
import com.designers.giftunwrap.GUFeedback;
import com.designers.giftunwrap.GUMotion;
import com.designers.giftunwrap.GiftArt;
import com.designers.giftunwrap.GiftFlightView;
import com.designers.giftunwrap.GiftUnwrapContent;
import com.designers.giftunwrap.GiftUnwrapView;

/**
 * The concept end to end, as in the film: a gift message arrives → tap it → the wrapped gift
 * comes forward with a hint (a ghost finger shows the pull) → pull the ribbon → the glass
 * breaks, the collectible's backdrop and pattern fill the screen → the reveal settles into the
 * gift sheet → Show on Profile → the gift flies into the ring of collectibles around the avatar,
 * the header takes its backdrop, a toast. Tap the profile to play again.
 */
public class MainActivity extends Activity {
    private FrameLayout root;
    private DemoChatView chat;
    private GiftUnwrapView unwrap;
    private View dim;
    private DemoProfileView profile;
    private GiftFlightView flight;
    private DemoToastView toast;
    private GiftUnwrapContent content;
    private Collectible bells;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        Window w = getWindow();
        w.setStatusBarColor(Color.TRANSPARENT);
        w.setNavigationBarColor(Color.TRANSPARENT);
        root = new FrameLayout(this);
        root.setBackgroundColor(Color.BLACK);
        setContentView(root);
        // The kit screens carry their own status bar: run edge to edge with the system bars hidden.
        if (Build.VERSION.SDK_INT >= 30) {
            w.setDecorFitsSystemWindows(false);
            if (w.getInsetsController() != null) {
                w.getInsetsController().hide(WindowInsets.Type.systemBars());
                w.getInsetsController().setSystemBarsBehavior(android.view.WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE);
            }
        } else {
            w.getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_FULLSCREEN | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                    | View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN | View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                    | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION);
        }
        build();
    }

    private GiftUnwrapContent jingleBells() {
        GiftUnwrapContent c = new GiftUnwrapContent();
        c.title = "Jingle Bells";
        c.number = 18082;
        c.art = DemoAssets.model(this, "ice_chime");
        c.backdrop = GiftUnwrapContent.Backdrop.cobaltBlue();
        c.symbolBitmap = DemoAssets.symbol(this, "snowflake");
        c.addRow("Model", "Ice Chime", GiftUnwrapContent.formatRarity(5), null)
                .addRow("Symbol", "Snowflake", GiftUnwrapContent.formatRarity(16), null)
                .addRow("Backdrop", "Cobalt Blue", GiftUnwrapContent.formatRarity(18), null)
                .addRow("Availability", "69 724/99 920 issued", null, null)
                .addRow("From", "Mia Carter", null, null);
        c.message = "Happy birthday, Alex! ✨";
        return c;
    }

    private void build() {
        root.removeAllViews();
        content = jingleBells();
        bells = new Collectible("Jingle Bells", content.art, content.backdrop, content.symbolBitmap);
        ViewGroup.LayoutParams match = new ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT);

        chat = new DemoChatView(this);
        root.addView(chat, match);

        unwrap = new GiftUnwrapView(this, content);
        root.addView(unwrap, match);

        dim = new View(this);
        dim.setBackgroundColor(Color.BLACK);
        dim.setAlpha(0f);
        root.addView(dim, match);

        profile = new DemoProfileView(this, DemoAssets.profileCollectibles(this));
        profile.setVisibility(View.INVISIBLE);
        profile.setOnClickListener(v -> restart());
        root.addView(profile, match);

        flight = new GiftFlightView(this, content.backdrop.inner);
        root.addView(flight, match);

        toast = new DemoToastView(this);
        root.addView(toast, match);

        chat.onGiftTapped = () -> unwrap.open();
        unwrap.setCallbacks(new GiftUnwrapView.Callbacks() {
            @Override
            public void onPrimaryAction(GiftUnwrapView view) {
                showOnProfile();
            }

            @Override
            public void onSecondaryAction(GiftUnwrapView view) {
                view.playExit(null, MainActivity.this::restart);
            }
        });
        root.post(() -> {
            float k = chat.k();
            unwrap.setSphereCenter(201f * k, 392f * k);
            chat.playArrival();
            root.postDelayed(() -> unwrap.showInMessage(chat.slotX(), chat.slotY(), chat.slotRadius() / GiftUnwrapView.sphereRadiusPx(), true), 120);
        });
    }

    private void restart() {
        unwrap.release();
        build();
    }

    private void showOnProfile() {
        final float width = root.getWidth();
        profile.setVisibility(View.VISIBLE);
        profile.setTranslationX(width);

        // Telegram push: the profile slides in over 0.62 s on the tg curve, the chat moves 30 % left.
        final long pushStart = GUMotion.nowNanos() + 100_000_000L;
        Runnable push = new Runnable() {
            @Override
            public void run() {
                float u = GUMotion.clamp((GUMotion.nowNanos() - pushStart) / 1e9f / 0.62f);
                float e = GUMotion.tg(u);
                profile.setTranslationX(width * (1f - e));
                chat.setTranslationX(-width * 0.3f * e);
                unwrap.setTranslationX(-width * 0.3f * e);
                dim.setAlpha(0.2f * e);
                if (u < 1f) {
                    root.postOnAnimation(this);
                }
            }
        };
        root.postOnAnimation(push);

        final float duration = 1.13f;
        final float landing = profile.orbit().now() + duration;
        profile.prepareLanding(bells, landing);
        RectF from = unwrap.takeGift();
        GiftArt art = content.art;
        flight.fly(art, unwrap.clock(), from, unwrap.getGiftRotation(), duration, t -> {
            float[] p = profile.orbit().landingPoint(landing);
            return new float[]{p[0] + profile.getTranslationX(), p[1], com.designers.giftunwrap.GiftOrbitView.modelSize() * p[2]};
        }, null);

        GUFeedback sounds = unwrap.getFeedback();
        sounds.play(GUFeedback.Sound.WHOOSH);
        root.postDelayed(() -> {
            sounds.play(GUFeedback.Sound.LAND);
            sounds.play(GUFeedback.Sound.SWELL, 0.8f);
            root.performHapticFeedback(android.view.HapticFeedbackConstants.VIRTUAL_KEY);
        }, (long) (duration * 1000));
        root.postDelayed(() -> {
            sounds.play(GUFeedback.Sound.TOAST);
            toast.show(art);
        }, (long) (duration * 1000) + 400);
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        if (unwrap != null) {
            unwrap.release();
        }
    }
}
