package com.designers.giftunwrap.demo;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;

import com.designers.giftunwrap.Collectible;
import com.designers.giftunwrap.GiftArt;
import com.designers.giftunwrap.GiftUnwrapContent;

import java.io.IOException;
import java.io.InputStream;
import java.util.ArrayList;
import java.util.List;

/**
 * Demo assets: screens exported from the Telegram iOS 26 UI kit (Figma, @2x of a 402 × 874 pt
 * screen), frames rendered from the original Telegram Lottie files of the gift models (30 fps
 * loops), and symbol silhouettes.
 */
final class DemoAssets {
    /** Kit screens are laid out on a 402 pt wide iPhone screen. */
    static final float KIT_WIDTH = 402f;

    private DemoAssets() {
    }

    static Bitmap bitmap(Context c, String path) {
        try (InputStream in = c.getAssets().open(path)) {
            return BitmapFactory.decodeStream(in);
        } catch (IOException e) {
            throw new IllegalStateException(path, e);
        }
    }

    static Bitmap kit(Context c, String name) {
        return bitmap(c, "kit/" + name + "@2x.webp");
    }

    static Bitmap symbol(Context c, String name) {
        return bitmap(c, "sym/" + name + ".png");
    }

    /**
     * The model's animation: an atlas {@code gifts/<name>_<frames>x<size>.webp} (10 frames per
     * row) cut into frames.
     */
    static GiftArt model(Context c, String name) {
        try {
            for (String f : c.getAssets().list("gifts")) {
                if (f.startsWith(name + "_") && f.endsWith(".webp")) {
                    String[] spec = f.substring(name.length() + 1, f.length() - 5).split("x");
                    int count = Integer.parseInt(spec[0]), size = Integer.parseInt(spec[1]);
                    Bitmap atlas = bitmap(c, "gifts/" + f);
                    Bitmap[] frames = new Bitmap[count];
                    for (int i = 0; i < count; i++) {
                        frames[i] = Bitmap.createBitmap(atlas, (i % 10) * size, (i / 10) * size, size, size);
                    }
                    atlas.recycle();
                    return GiftArt.frames(frames, 30f);
                }
            }
        } catch (IOException e) {
            throw new IllegalStateException(name, e);
        }
        throw new IllegalStateException("no frames for " + name);
    }

    /** Backdrop colours from Telegram (center, edge, pattern, text). */
    static GiftUnwrapContent.Backdrop backdrop(String name) {
        switch (name) {
            case "Emerald":
                return new GiftUnwrapContent.Backdrop(0xff78c585, 0xff42a171, 0xff006532, 0xffb9f9d9);
            case "Black":
                return new GiftUnwrapContent.Backdrop(0xff363738, 0xff0e0f0f, 0xff6c6868, 0xff8c8f91);
            case "Fire Engine":
                return new GiftUnwrapContent.Backdrop(0xfff05f4f, 0xffc43949, 0xff690009, 0xffffb7a6);
            case "Mexican Pink":
                return new GiftUnwrapContent.Backdrop(0xffe36692, 0xffc9497c, 0xff750230, 0xffffd6e6);
            case "Amber":
                return new GiftUnwrapContent.Backdrop(0xffdab345, 0xffb1802a, 0xff7a3100, 0xffffedc7);
            default:
                return GiftUnwrapContent.Backdrop.cobaltBlue();
        }
    }

    /** Five collectibles already on Alex's profile (real models / backdrops / symbols). */
    static List<Collectible> profileCollectibles(Context c) {
        String[][] specs = {
                {"Plush Pepe", "plush_pepe", "Emerald", "clover"},
                {"Durov's Cap", "durovs_cap", "Black", "star"},
                {"Heart Locket", "heart_locket", "Fire Engine", "heart"},
                {"Precious Peach", "precious_peach", "Mexican Pink", "cherry"},
                {"Toy Bear", "toy_bear", "Amber", "moon"}};
        List<Collectible> out = new ArrayList<>();
        for (String[] s : specs) {
            out.add(new Collectible(s[0], model(c, s[1]), backdrop(s[2]), symbol(c, s[3])));
        }
        return out;
    }
}
