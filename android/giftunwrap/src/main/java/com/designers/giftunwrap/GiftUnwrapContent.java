package com.designers.giftunwrap;

import android.graphics.Bitmap;
import android.graphics.drawable.Drawable;

import java.util.ArrayList;
import java.util.List;

/**
 * Everything the unwrap screen needs about the gift, as plain values. The Telegram adapter
 * fills it from {@code TL_stars.TL_starGiftUnique} (any collectible: model, symbol, backdrop,
 * number, availability); the demo fills it by hand.
 */
public class GiftUnwrapContent {

    /** Backdrop colours, exactly as Telegram sends them ({@code starGiftAttributeBackdrop}). */
    public static class Backdrop {
        /** center_color, edge_color, pattern_color, text_color */
        public final int inner, outer, pattern, text;

        public Backdrop(int inner, int outer, int pattern, int text) {
            this.inner = inner;
            this.outer = outer;
            this.pattern = pattern;
            this.text = text;
        }

        /** "Cobalt Blue" (backdrop #53 of Telegram's 80). */
        public static Backdrop cobaltBlue() {
            return new Backdrop(0xff6088cf, 0xff5162b8, 0xff13247c, 0xffc2d3f5);
        }

        /** "Midnight Blue". */
        public static Backdrop midnightBlue() {
            return new Backdrop(0xff5c6985, 0xff354057, 0xff030a18, 0xffbfcce0);
        }

        /** The ribbon on the wrapped gift wears the backdrop's colours: {base, light, dark}. */
        int[] ribbon() {
            int base = GUMotion.mix(outer, inner, 0.35f);
            return new int[]{base, GUMotion.mix(inner, 0xffffffff, 0.55f), GUMotion.mix(pattern, base, 0.35f)};
        }
    }

    public static class Row {
        public final String title, value, badge, avatarLetter;

        public Row(String title, String value, String badge, String avatarLetter) {
            this.title = title;
            this.value = value;
            this.badge = badge;
            this.avatarLetter = avatarLetter;
        }
    }

    public String title = "";
    /** Collectible number, or 0 for none. */
    public int number;
    public String subtitlePrefix = "Collectible #";
    /** The model (animated sticker drawable inside Telegram, frames in the demo). */
    public GiftArt art;
    /** The pattern symbol (white or any colour, it is tinted). Null → built-in snowflake. */
    public Bitmap symbolBitmap;
    /** Optional drawable for the symbol (already coloured), used instead of the bitmap. */
    public Drawable symbolDrawable;
    public Backdrop backdrop = Backdrop.cobaltBlue();
    /** Model / Symbol / Backdrop (with rarity), Availability, From… — Telegram's table. */
    public final List<Row> rows = new ArrayList<>();
    /** The sender's message, shown as the last, full-width row. Null → none. */
    public String message;
    public String caption = "Only you can see this gift for now.";
    public String primaryAction = "Show on Profile";
    public String hint = "Pull the ribbon to unwrap";
    public String[] chips = {"transfer", "wear", "sell"};

    public GiftUnwrapContent addRow(String title, String value, String badge, String avatarLetter) {
        rows.add(new Row(title, value, badge, avatarLetter));
        return this;
    }

    /** "18 082" — collectible numbers are grouped by thousands. */
    public static String formatNumber(int number) {
        String digits = String.valueOf(number);
        StringBuilder out = new StringBuilder();
        for (int i = 0; i < digits.length(); i++) {
            if (i > 0 && (digits.length() - i) % 3 == 0) {
                out.append(' ');
            }
            out.append(digits.charAt(i));
        }
        return out.toString();
    }

    /** Rarity per mille → "1.2%". */
    public static String formatRarity(int permille) {
        if (permille % 10 == 0) {
            return (permille / 10) + "%";
        }
        return String.format(java.util.Locale.US, "%.1f%%", permille / 10f);
    }
}
