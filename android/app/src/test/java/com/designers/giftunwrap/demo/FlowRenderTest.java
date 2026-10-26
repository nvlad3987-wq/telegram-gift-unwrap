package com.designers.giftunwrap.demo;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertTrue;
import static org.robolectric.Shadows.shadowOf;

import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.os.Looper;
import android.os.SystemClock;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;

import com.designers.giftunwrap.GiftUnwrapView;

import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.Robolectric;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.android.controller.ActivityController;
import org.robolectric.annotation.Config;
import org.robolectric.annotation.GraphicsMode;
import org.robolectric.annotation.LooperMode;

import java.io.File;
import java.io.FileOutputStream;
import java.io.PrintWriter;
import java.io.StringWriter;
import java.lang.reflect.Field;
import java.time.Duration;
import java.util.zip.ZipEntry;
import java.util.zip.ZipOutputStream;

/**
 * Plays the whole demo with real touches on the real views and renders every frame with
 * Android's own graphics stack (Robolectric native graphics):
 * gift message → tap → hint and ghost finger → pull the ribbon → glass breaks → backdrop and
 * pattern → gift sheet → tap Show on Profile → the gift flies into the orbit → toast.
 *
 * Output: {@code frames/android_flow.zip} (30 fps JPEG frames), key stills and {@code log.txt}
 * in the project folder.
 */
@RunWith(RobolectricTestRunner.class)
@Config(sdk = 34, qualifiers = "w393dp-h852dp-xhdpi")
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@LooperMode(LooperMode.Mode.PAUSED)
public class FlowRenderTest {
    private static final int FPS = 60;

    private MainActivity activity;
    private View decor;
    private ZipOutputStream zip;
    private int frame;
    private long elapsedMs;
    private final StringBuilder log = new StringBuilder();
    private File out;

    @Test
    public void playWholeFlow() throws Exception {
        String dir = System.getProperty("flow.out");
        out = dir != null ? new File(dir) : new File(System.getProperty("user.dir"), "../frames").getCanonicalFile();
        out.mkdirs();
        try {
            run();
        } catch (Throwable t) {
            StringWriter sw = new StringWriter();
            t.printStackTrace(new PrintWriter(sw));
            log.append("FAILED at ").append(elapsedMs).append(" ms, frame ").append(frame).append('\n').append(sw);
            throw t;
        } finally {
            if (zip != null) {
                zip.close();
            }
            try (FileOutputStream f = new FileOutputStream(new File(out, "log.txt"))) {
                f.write(log.toString().getBytes("UTF-8"));
            }
        }
    }

    private void run() throws Exception {
        // Frames only when the test advances the clock (by default Robolectric fast-forwards
        // the clock through animation callbacks), at 60 Hz like a phone.
        org.robolectric.shadows.ShadowChoreographer.setPaused(true);
        org.robolectric.shadows.ShadowChoreographer.setFrameDelay(Duration.ofMillis(16));
        ActivityController<MainActivity> controller = Robolectric.buildActivity(MainActivity.class).setup();
        activity = controller.get();
        decor = activity.getWindow().getDecorView();
        zip = new ZipOutputStream(new FileOutputStream(new File(out, "android_flow.zip")));
        step();
        log.append("decor ").append(decor.getWidth()).append('x').append(decor.getHeight()).append('\n');
        DemoChatView chat = (DemoChatView) field(activity, "chat");
        float k = chat.k();

        // 1. The gift message arrives in the chat (the wrapped gift rests in the card).
        play(1.3f);
        still("01_gift_message");
        GiftUnwrapView unwrap = (GiftUnwrapView) field(activity, "unwrap");
        assertNotNull(unwrap);
        assertEquals(GiftUnwrapView.PHASE_WRAPPED, unwrap.getPhase());

        // 2. Tap the card ("Unwrap").
        long tap = SystemClock.uptimeMillis();
        touch(tap, MotionEvent.ACTION_DOWN, 201f * k, 752f * k);
        play(0.12f);
        touch(tap, MotionEvent.ACTION_UP, 201f * k, 752f * k);
        assertTrue("the card opens the gift", unwrap.isOpen());

        // 3. The gift comes forward; the hint and a ghost finger show the pull.
        play(0.9f);
        still("02_hint");
        play(0.75f);
        still("02b_ghost_finger");
        play(1.6f);

        // 4. Pull the ribbon tab along its pull direction.
        float density = activity.getResources().getDisplayMetrics().density;
        int[] at = new int[2];
        unwrap.getLocationInWindow(at);
        float sx = (float) field(unwrap, "sphereX") + at[0];
        float sy = (float) field(unwrap, "sphereY") + at[1];
        float tailX = (float) field(unwrap, "TAIL_X"), tailY = (float) field(unwrap, "TAIL_Y");
        float pullX = (float) field(unwrap, "PULL_X"), pullY = (float) field(unwrap, "PULL_Y");
        float tabX = sx + tailX * density, tabY = sy + tailY * density;
        float len = (float) Math.hypot(pullX, pullY);
        float ux = pullX / len, uy = pullY / len;
        float full = len * density;
        log.append(String.format("sphere %.0f,%.0f  tab %.0f,%.0f  pull %.0f px%n", sx, sy, tabX, tabY, full));

        long down = SystemClock.uptimeMillis();
        touch(down, MotionEvent.ACTION_DOWN, tabX, tabY);
        int steps = Math.round(1.4f * FPS);
        for (int i = 1; i <= steps; i++) {
            float u = (float) i / steps;
            float e = 1f - (float) Math.pow(1f - u, 2.1f);
            float d = full * 0.9f * e;
            step();
            touch(down, MotionEvent.ACTION_MOVE, tabX + ux * d + 2f * density * (float) Math.sin(u * 3f), tabY + uy * d);
            capture();
        }
        still("03_pull_the_ribbon");
        float d0 = full * 0.9f;
        for (int i = 1; i <= 3; i++) {
            float d = d0 + full * 0.12f * i;
            step();
            touch(down, MotionEvent.ACTION_MOVE, tabX + ux * d, tabY + uy * d);
            capture();
        }
        touch(down, MotionEvent.ACTION_UP, tabX + ux * (d0 + full * 0.36f), tabY + uy * (d0 + full * 0.36f));

        // 5. The glass breaks, the backdrop and its pattern fill the screen, then the gift sheet.
        play(0.25f);
        still("04_glass_breaks");
        assertEquals("a flick past the end must break the glass", GiftUnwrapView.PHASE_SNAPPED, unwrap.getPhase());
        play(0.6f);
        still("05_backdrop_pattern");
        play(1.6f);
        still("06_gift_sheet");
        play(0.6f);

        // 6. Tap "Show on Profile" like a finger would.
        TextView primary = findText(decor, "Show on Profile");
        assertNotNull("primary button", primary);
        int[] p = new int[2];
        primary.getLocationInWindow(p);
        float bx = p[0] + primary.getWidth() / 2f, by = p[1] + primary.getHeight() / 2f;
        log.append(String.format("button at %.0f,%.0f%n", bx, by));
        long tapDown = SystemClock.uptimeMillis();
        touch(tapDown, MotionEvent.ACTION_DOWN, bx, by);
        play(0.12f);
        touch(tapDown, MotionEvent.ACTION_UP, bx, by);

        // 7. The gift flies into the ring around the avatar, the header recolours, the toast rises.
        play(0.4f);
        still("07_fly_to_profile");
        View profile = (View) field(activity, "profile");
        assertEquals(View.VISIBLE, profile.getVisibility());
        play(1.1f);
        still("08_profile");
        play(1.4f);
        still("08b_toast");
        play(0.8f);

        log.append("frames ").append(frame).append(", ").append(elapsedMs).append(" ms\n");
        log.append("OK\n");
        assertTrue(frame > 600);
    }

    // --- helpers

    /** Advances the clock by one frame and runs everything due. */
    private void step() {
        frame++;
        long target = Math.round(frame * 1000.0 / FPS);
        long delta = target - elapsedMs;
        elapsedMs = target;
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(delta));
    }

    private void play(float seconds) throws Exception {
        int n = Math.round(seconds * FPS);
        for (int i = 0; i < n; i++) {
            step();
            capture();
        }
    }

    private Bitmap render() {
        Bitmap bm = Bitmap.createBitmap(decor.getWidth(), decor.getHeight(), Bitmap.Config.ARGB_8888);
        decor.draw(new Canvas(bm));
        return bm;
    }

    private void capture() throws Exception {
        Bitmap bm = render();
        zip.putNextEntry(new ZipEntry(String.format("f%05d.jpg", frame)));
        bm.compress(Bitmap.CompressFormat.JPEG, 88, zip);
        zip.closeEntry();
        bm.recycle();
    }

    private void still(String name) throws Exception {
        Bitmap bm = render();
        try (FileOutputStream f = new FileOutputStream(new File(out, name + ".png"))) {
            bm.compress(Bitmap.CompressFormat.PNG, 100, f);
        }
        log.append(String.format("%-24s t=%5d ms  frame %d  uptime %d%n", name, elapsedMs, frame, SystemClock.uptimeMillis()));
        bm.recycle();
    }

    private void touch(long downTime, int action, float x, float y) {
        MotionEvent e = MotionEvent.obtain(downTime, SystemClock.uptimeMillis(), action, x, y, 0);
        decor.dispatchTouchEvent(e);
        e.recycle();
    }

    private static Object field(Object o, String name) throws Exception {
        Class<?> c = o.getClass();
        while (c != null) {
            try {
                Field f = c.getDeclaredField(name);
                f.setAccessible(true);
                return f.get(o);
            } catch (NoSuchFieldException ignored) {
                c = c.getSuperclass();
            }
        }
        throw new NoSuchFieldException(name);
    }

    private static TextView findText(View v, String text) {
        if (v instanceof TextView && text.contentEquals(((TextView) v).getText()) && v.isShown()) {
            return (TextView) v;
        }
        if (v instanceof ViewGroup) {
            ViewGroup g = (ViewGroup) v;
            for (int i = 0; i < g.getChildCount(); i++) {
                TextView r = findText(g.getChildAt(i), text);
                if (r != null) {
                    return r;
                }
            }
        }
        return null;
    }
}
