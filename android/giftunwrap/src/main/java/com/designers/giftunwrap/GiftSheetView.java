package com.designers.giftunwrap;

import android.annotation.SuppressLint;
import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.RectF;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.text.TextUtils;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.MotionEvent;
import android.view.View;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.TextView;

import java.util.ArrayList;
import java.util.List;

/**
 * Telegram's collectible gift sheet, laid out like the iOS 26 kit: a header (close and
 * share/more glass buttons, title, "Collectible #N", transfer / wear / sell) over the gift's
 * backdrop — which {@link GiftUnwrapView} draws, so the reveal can condense into it — and a
 * white body with the attribute table (rarity badges), the caption and the blue button.
 */
final class GiftSheetView extends FrameLayout {
    static final float HEADER_DP = 313f;
    static final float ROW_DP = 42f;
    static final int BUTTON_COLOR = 0xff008afe;

    final View close;
    final View more;
    final TextView title;
    final TextView subtitle;
    final LinearLayout chips;
    final LinearLayout body;
    final TextView button;
    private final List<View> headerParts = new ArrayList<>();
    private final int rows;
    Runnable onPrimary, onClose;

    @SuppressLint("ClickableViewAccessibility")
    GiftSheetView(Context context, GiftUnwrapContent content) {
        super(context);
        setClipChildren(false);
        Typeface medium = Typeface.create("sans-serif-medium", Typeface.NORMAL);
        Typeface bold = Typeface.create("sans-serif", Typeface.BOLD);
        Typeface regular = Typeface.create("sans-serif", Typeface.NORMAL);

        close = new GlassButton(context, GlassButton.CLOSE);
        close.setOnClickListener(v -> {
            if (onClose != null) {
                onClose.run();
            }
        });
        addView(close, new LayoutParams(dp(42), dp(42)));
        more = new GlassButton(context, GlassButton.SHARE_MORE);
        addView(more, new LayoutParams(dp(86), dp(42)));

        title = text(context, content.title, 24, Color.WHITE, bold);
        title.setLetterSpacing(-0.02f);
        addView(title, new LayoutParams(LayoutParams.MATCH_PARENT, dp(30)));
        subtitle = text(context, content.number > 0 ? content.subtitlePrefix + GiftUnwrapContent.formatNumber(content.number) : "", 15, GUMotion.withAlpha(content.backdrop.text, 0.9f), regular);
        addView(subtitle, new LayoutParams(LayoutParams.MATCH_PARENT, dp(20)));

        chips = new LinearLayout(context);
        chips.setOrientation(LinearLayout.HORIZONTAL);
        for (int i = 0; i < content.chips.length; i++) {
            LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(0, LayoutParams.MATCH_PARENT, 1f);
            if (i > 0) {
                lp.leftMargin = dp(10);
            }
            chips.addView(new Chip(context, i, content.chips[i], content.backdrop.pattern), lp);
        }
        addView(chips, new LayoutParams(LayoutParams.MATCH_PARENT, dp(64)));
        headerParts.add(title);
        headerParts.add(subtitle);
        headerParts.add(chips);
        headerParts.add(close);
        headerParts.add(more);

        // body: table, caption, button
        body = new LinearLayout(context);
        body.setOrientation(LinearLayout.VERTICAL);
        GradientDrawable bodyBg = new GradientDrawable();
        bodyBg.setColor(Color.WHITE);
        bodyBg.setCornerRadius(dp(44));
        body.setBackground(bodyBg);
        body.setPadding(dp(16), dp(16), dp(16), 0);
        LinearLayout table = new LinearLayout(context);
        table.setOrientation(LinearLayout.VERTICAL);
        GradientDrawable tableBg = new GradientDrawable();
        tableBg.setColor(Color.WHITE);
        tableBg.setCornerRadius(dp(12));
        tableBg.setStroke(Math.max(1, dp(0.66f)), 0xffc6c6c8);
        table.setBackground(tableBg);
        table.setClipToOutline(true);
        int n = content.rows.size() + (content.message != null ? 1 : 0);
        for (int i = 0; i < content.rows.size(); i++) {
            table.addView(row(context, content.rows.get(i), i == n - 1, regular, medium), new LinearLayout.LayoutParams(LayoutParams.MATCH_PARENT, dp(ROW_DP)));
        }
        if (content.message != null) {
            TextView m = text(context, content.message, 16, Color.BLACK, regular);
            m.setGravity(Gravity.CENTER_VERTICAL | Gravity.START);
            m.setPadding(dp(12), 0, dp(12), 0);
            m.setSingleLine(true);
            m.setEllipsize(TextUtils.TruncateAt.END);
            table.addView(m, new LinearLayout.LayoutParams(LayoutParams.MATCH_PARENT, dp(ROW_DP)));
        }
        rows = n;
        body.addView(table, new LinearLayout.LayoutParams(LayoutParams.MATCH_PARENT, dp(ROW_DP) * n));
        TextView caption = text(context, content.caption, 13, 0xff8e8e93, regular);
        LinearLayout.LayoutParams cp = new LinearLayout.LayoutParams(LayoutParams.MATCH_PARENT, dp(18));
        cp.topMargin = dp(14);
        body.addView(caption, cp);
        button = text(context, content.primaryAction, 17, Color.WHITE, medium);
        GradientDrawable bb = new GradientDrawable();
        bb.setColor(BUTTON_COLOR);
        bb.setCornerRadius(dp(25));
        button.setBackground(bb);
        button.setOnTouchListener((v, e) -> {
            // respond on press, commit on release
            if (e.getAction() == MotionEvent.ACTION_DOWN) {
                v.animate().scaleX(0.97f).scaleY(0.97f).alpha(0.86f).setDuration(90).start();
            } else if (e.getAction() == MotionEvent.ACTION_UP || e.getAction() == MotionEvent.ACTION_CANCEL) {
                v.animate().scaleX(1f).scaleY(1f).alpha(1f).setDuration(240).setInterpolator(new android.view.animation.OvershootInterpolator(2f)).start();
            }
            return false;
        });
        button.setOnClickListener(v -> {
            if (onPrimary != null) {
                onPrimary.run();
            }
        });
        LinearLayout.LayoutParams bp = new LinearLayout.LayoutParams(LayoutParams.MATCH_PARENT, dp(50));
        bp.topMargin = dp(18);
        body.addView(button, bp);
        addView(body, new LayoutParams(LayoutParams.MATCH_PARENT, Math.round(bodyHeightDp(n) * GUMotion.dp(1f))));
    }

    /** Body height for {@code rows} table rows: 16 + rows·42 + caption + button + 31 (kit: 399 for 6 rows). */
    static float bodyHeightDp(int rows) {
        return 16f + rows * ROW_DP + 14f + 18f + 18f + 50f + 31f;
    }

    static int tableRows(GiftUnwrapContent content) {
        return content.rows.size() + (content.message != null ? 1 : 0);
    }

    float headerHeight() {
        return getHeight() - bodyHeightDp(rows) * GUMotion.dp(1f);
    }

    @Override
    protected void onLayout(boolean changed, int left, int top, int right, int bottom) {
        int w = right - left, h = bottom - top;
        int bodyH = Math.round(bodyHeightDp(rows) * GUMotion.dp(1f));
        int headerH = h - bodyH;
        float k = headerH / GUMotion.dp(HEADER_DP);   // the header shrinks on short screens
        int exact = MeasureSpec.EXACTLY;
        close.measure(MeasureSpec.makeMeasureSpec(dp(42), exact), MeasureSpec.makeMeasureSpec(dp(42), exact));
        more.measure(MeasureSpec.makeMeasureSpec(dp(86), exact), MeasureSpec.makeMeasureSpec(dp(42), exact));
        title.measure(MeasureSpec.makeMeasureSpec(w, exact), MeasureSpec.makeMeasureSpec(dp(30), exact));
        subtitle.measure(MeasureSpec.makeMeasureSpec(w, exact), MeasureSpec.makeMeasureSpec(dp(20), exact));
        chips.measure(MeasureSpec.makeMeasureSpec(w - dp(32), exact), MeasureSpec.makeMeasureSpec(dp(64), exact));
        body.measure(MeasureSpec.makeMeasureSpec(w, exact), MeasureSpec.makeMeasureSpec(bodyH, exact));
        close.layout(dp(16), dp(16), dp(58), dp(58));
        more.layout(w - dp(16) - dp(86), dp(16), w - dp(16), dp(58));
        int ty = Math.round(GUMotion.dp(178f) * k);
        title.layout(0, ty, w, ty + dp(30));
        subtitle.layout(0, ty + dp(30), w, ty + dp(50));
        int cy = Math.round(GUMotion.dp(236f) * k);
        chips.layout(dp(16), cy, w - dp(16), cy + dp(64));
        body.layout(0, headerH, w, h);
    }

    @Override
    protected void onMeasure(int widthMeasureSpec, int heightMeasureSpec) {
        setMeasuredDimension(MeasureSpec.getSize(widthMeasureSpec), MeasureSpec.getSize(heightMeasureSpec));
    }

    /** {@code t}: seconds since the reveal began condensing into the sheet. */
    void setAppear(float t) {
        float[] delays = {0.12f, 0.16f, 0.2f, 0.26f, 0.3f};
        for (int i = 0; i < headerParts.size(); i++) {
            View v = headerParts.get(i);
            float u = GUMotion.clamp((t - delays[i]) / 0.4f), e = GUMotion.tg(u);
            v.setAlpha(GUMotion.easeInOut(GUMotion.clamp((t - delays[i]) / 0.25f)));
            v.setTranslationY((1f - e) * dp(14));
            v.setScaleX(0.96f + 0.04f * e);
            v.setScaleY(0.96f + 0.04f * e);
        }
        float bk = GUMotion.spring(t - 0.03f, GUMotion.SHEET);
        body.setTranslationY((1f - bk) * dp(430));
        body.setAlpha(t > 0f ? 1f : 0f);
    }

    private View row(Context context, GiftUnwrapContent.Row r, boolean last, Typeface regular, Typeface medium) {
        FrameLayout row = new FrameLayout(context) {
            private final Paint p = new Paint();

            @Override
            protected void dispatchDraw(Canvas canvas) {
                p.setColor(0xffeeeeef);
                canvas.drawRect(0, 0, dp(98), getHeight(), p);
                p.setColor(0xffc6c6c8);
                float hair = Math.max(1, dp(0.66f));
                canvas.drawRect(dp(98), 0, dp(98) + hair, getHeight(), p);
                if (!last) {
                    canvas.drawRect(0, getHeight() - hair, getWidth(), getHeight(), p);
                }
                super.dispatchDraw(canvas);
            }
        };
        row.setWillNotDraw(false);
        TextView key = text(context, r.title, 16, Color.BLACK, regular);
        key.setGravity(Gravity.CENTER_VERTICAL | Gravity.START);
        key.setPadding(dp(12), 0, dp(4), 0);
        row.addView(key, new LayoutParams(dp(98), LayoutParams.MATCH_PARENT));
        LinearLayout value = new LinearLayout(context);
        value.setOrientation(LinearLayout.HORIZONTAL);
        value.setGravity(Gravity.CENTER_VERTICAL);
        TextView v = text(context, r.value, 16, Color.BLACK, regular);
        v.setSingleLine(true);
        v.setEllipsize(TextUtils.TruncateAt.END);
        value.addView(v, new LinearLayout.LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT));
        if (r.badge != null) {
            TextView b = text(context, r.badge, 13, BUTTON_COLOR, medium);
            b.setPadding(dp(7), 0, dp(7), 0);
            GradientDrawable bg = new GradientDrawable();
            bg.setColor(0xffe5f3ff);
            bg.setCornerRadius(dp(10));
            b.setBackground(bg);
            LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(LayoutParams.WRAP_CONTENT, dp(20));
            lp.leftMargin = dp(7);
            value.addView(b, lp);
        }
        LayoutParams vp = new LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT);
        vp.leftMargin = dp(110);
        vp.rightMargin = dp(10);
        row.addView(value, vp);
        return row;
    }

    private static TextView text(Context context, String s, float sp, int color, Typeface tf) {
        TextView t = new TextView(context);
        t.setText(s);
        t.setTextColor(color);
        t.setTextSize(TypedValue.COMPLEX_UNIT_DIP, sp);
        t.setTypeface(tf);
        t.setGravity(Gravity.CENTER);
        t.setIncludeFontPadding(false);
        return t;
    }

    static int dp(float v) {
        return Math.round(GUMotion.dp(v));
    }

    /** iOS 26 glass button on the backdrop: white 17 % fill, hairline light edge, white glyphs. */
    static final class GlassButton extends View {
        static final int CLOSE = 0, SHARE_MORE = 1;
        private final int kind;
        private final Paint fill = new Paint(Paint.ANTI_ALIAS_FLAG);
        private final Paint edge = new Paint(Paint.ANTI_ALIAS_FLAG);
        private final Paint glyph = new Paint(Paint.ANTI_ALIAS_FLAG);
        private final RectF r = new RectF();
        private final Path p = new Path();

        GlassButton(Context context, int kind) {
            super(context);
            this.kind = kind;
            fill.setColor(0x2bffffff);
            edge.setStyle(Paint.Style.STROKE);
            edge.setStrokeWidth(GUMotion.dp(0.6f));
            edge.setColor(0x59ffffff);
            glyph.setColor(Color.WHITE);
            glyph.setStyle(Paint.Style.STROKE);
            glyph.setStrokeCap(Paint.Cap.ROUND);
            glyph.setStrokeJoin(Paint.Join.ROUND);
            glyph.setStrokeWidth(GUMotion.dp(2.2f));
        }

        @Override
        protected void onDraw(Canvas c) {
            float w = getWidth(), h = getHeight(), d = GUMotion.dp(1f);
            r.set(0, 0, w, h);
            c.drawRoundRect(r, h / 2f, h / 2f, fill);
            r.inset(d * 0.3f, d * 0.3f);
            c.drawRoundRect(r, h / 2f, h / 2f, edge);
            float cy = h / 2f;
            if (kind == CLOSE) {
                float cx = w / 2f, s = 6f * d;
                c.drawLine(cx - s, cy - s, cx + s, cy + s, glyph);
                c.drawLine(cx + s, cy - s, cx - s, cy + s, glyph);
            } else {
                float cx = 23f * d;
                p.rewind();   // share: arrow up out of a box
                p.moveTo(cx, cy - 9.5f * d);
                p.lineTo(cx, cy + 3.5f * d);
                p.moveTo(cx - 4.8f * d, cy - 5.2f * d);
                p.lineTo(cx, cy - 10f * d);
                p.lineTo(cx + 4.8f * d, cy - 5.2f * d);
                p.moveTo(cx - 4f * d, cy - 1.5f * d);
                p.lineTo(cx - 6.5f * d, cy - 1.5f * d);
                p.lineTo(cx - 6.5f * d, cy + 10f * d);
                p.lineTo(cx + 6.5f * d, cy + 10f * d);
                p.lineTo(cx + 6.5f * d, cy - 1.5f * d);
                p.lineTo(cx + 4f * d, cy - 1.5f * d);
                glyph.setStyle(Paint.Style.STROKE);
                c.drawPath(p, glyph);
                glyph.setStyle(Paint.Style.FILL);
                for (int i = -1; i <= 1; i++) {
                    c.drawCircle(w - 26f * d + i * 7.5f * d, cy, 2.2f * d, glyph);
                }
                glyph.setStyle(Paint.Style.STROKE);
            }
        }
    }

    /** transfer / wear / sell: a glass tile tinted with the backdrop's pattern colour. */
    static final class Chip extends View {
        private final int icon;
        private final String label;
        private final Paint fill = new Paint(Paint.ANTI_ALIAS_FLAG);
        private final Paint edge = new Paint(Paint.ANTI_ALIAS_FLAG);
        private final Paint white = new Paint(Paint.ANTI_ALIAS_FLAG);
        private final Paint text = new Paint(Paint.ANTI_ALIAS_FLAG);
        private final Paint ink = new Paint(Paint.ANTI_ALIAS_FLAG);
        private final RectF r = new RectF();
        private final Path p = new Path();

        Chip(Context context, int icon, String label, int patternColor) {
            super(context);
            this.icon = icon;
            this.label = label;
            fill.setColor(GUMotion.withAlpha(patternColor, 0.36f));
            ink.setColor(patternColor | 0xff000000);
            ink.setStyle(Paint.Style.STROKE);
            ink.setStrokeWidth(GUMotion.dp(1.4f));
            ink.setStrokeCap(Paint.Cap.ROUND);
            edge.setStyle(Paint.Style.STROKE);
            edge.setStrokeWidth(GUMotion.dp(0.66f));
            edge.setColor(0x2effffff);
            white.setColor(Color.WHITE);
            text.setColor(Color.WHITE);
            text.setTextAlign(Paint.Align.CENTER);
            text.setTextSize(GUMotion.dp(13f));
        }

        @Override
        protected void onDraw(Canvas c) {
            float w = getWidth(), h = getHeight(), d = GUMotion.dp(1f);
            r.set(0, 0, w, h);
            c.drawRoundRect(r, 14 * d, 14 * d, fill);
            c.drawRoundRect(r, 14 * d, 14 * d, edge);
            float cx = w / 2f, cy = 21f * d;
            p.rewind();
            if (icon == 0) {        // transfer: a gem with an arrow badge
                p.moveTo(cx - 10 * d, cy - 3 * d);
                p.lineTo(cx - 5 * d, cy - 8 * d);
                p.lineTo(cx + 5 * d, cy - 8 * d);
                p.lineTo(cx + 10 * d, cy - 3 * d);
                p.lineTo(cx, cy + 9 * d);
                p.close();
                c.drawPath(p, white);
                c.drawCircle(cx + 7 * d, cy + 6 * d, 5.5f * d, white);
                c.drawLine(cx + 4.5f * d, cy + 6 * d, cx + 9.5f * d, cy + 6 * d, ink);
                c.drawLine(cx + 7.5f * d, cy + 4 * d, cx + 9.5f * d, cy + 6 * d, ink);
                c.drawLine(cx + 7.5f * d, cy + 8 * d, cx + 9.5f * d, cy + 6 * d, ink);
            } else if (icon == 1) { // wear: a crown
                p.moveTo(cx - 10 * d, cy - 4 * d);
                p.lineTo(cx - 5 * d, cy + 1 * d);
                p.lineTo(cx, cy - 7 * d);
                p.lineTo(cx + 5 * d, cy + 1 * d);
                p.lineTo(cx + 10 * d, cy - 4 * d);
                p.lineTo(cx + 8 * d, cy + 6 * d);
                p.lineTo(cx - 8 * d, cy + 6 * d);
                p.close();
                c.drawPath(p, white);
                r.set(cx - 8 * d, cy + 7.5f * d, cx + 8 * d, cy + 10 * d);
                c.drawRoundRect(r, d, d, white);
            } else {                // sell: a price tag
                c.save();
                c.rotate(-45f, cx, cy);
                r.set(cx - 6 * d, cy - 11 * d, cx + 6 * d, cy + 9 * d);
                p.moveTo(cx, cy - 13 * d);
                p.lineTo(cx + 6 * d, cy - 7 * d);
                p.lineTo(cx + 6 * d, cy + 9 * d);
                p.lineTo(cx - 6 * d, cy + 9 * d);
                p.lineTo(cx - 6 * d, cy - 7 * d);
                p.close();
                c.drawPath(p, white);
                ink.setStyle(Paint.Style.FILL);
                c.drawCircle(cx, cy - 6 * d, 1.8f * d, ink);
                ink.setStyle(Paint.Style.STROKE);
                c.restore();
            }
            c.drawText(label, cx, h - 14 * d, text);
        }
    }
}
