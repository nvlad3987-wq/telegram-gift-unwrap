package com.designers.giftunwrap;

import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.RadialGradient;
import android.graphics.Shader;

/** Built-in artwork: the snowflake symbol and the sparkle particle. */
final class Snowflake {
    private Snowflake() {
    }

    static Bitmap bitmap(int size) {
        Bitmap b = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888);
        Canvas c = new Canvas(b);
        float k = size / 24f;
        Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
        p.setColor(0xffffffff);
        p.setStyle(Paint.Style.STROKE);
        p.setStrokeWidth(1.7f * k);
        p.setStrokeCap(Paint.Cap.ROUND);
        c.translate(size / 2f, size / 2f);
        for (int i = 0; i < 6; i++) {
            c.save();
            c.rotate(i * 60f);
            c.drawLine(0, 0, 0, -9.8f * k, p);
            c.drawLine(0, -6.6f * k, -2.6f * k, -8.8f * k, p);
            c.drawLine(0, -6.6f * k, 2.6f * k, -8.8f * k, p);
            c.drawLine(0, -3.4f * k, -2.1f * k, -5.0f * k, p);
            c.drawLine(0, -3.4f * k, 2.1f * k, -5.0f * k, p);
            c.restore();
        }
        p.setStyle(Paint.Style.FILL);
        c.drawCircle(0, 0, 1.9f * k, p);
        return b;
    }

    static Bitmap sparkle(int size) {
        Bitmap b = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888);
        Canvas c = new Canvas(b);
        float r = size / 2f;
        Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
        p.setShader(new RadialGradient(r, r, r * 0.45f, 0xffffffff, 0x00ffffff, Shader.TileMode.CLAMP));
        c.drawCircle(r, r, r * 0.45f, p);
        p.setShader(null);
        p.setColor(0xffffffff);
        Path s = new Path();
        s.moveTo(r, 0);
        s.quadTo(r * 1.08f, r * 0.92f, size, r);
        s.quadTo(r * 1.08f, r * 1.08f, r, size);
        s.quadTo(r * 0.92f, r * 1.08f, 0, r);
        s.quadTo(r * 0.92f, r * 0.92f, r, 0);
        s.close();
        c.drawPath(s, p);
        return b;
    }
}
