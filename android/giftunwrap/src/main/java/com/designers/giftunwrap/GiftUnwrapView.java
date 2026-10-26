package com.designers.giftunwrap;

import android.annotation.SuppressLint;
import android.content.Context;
import android.graphics.Canvas;
import android.graphics.DashPathEffect;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.PointF;
import android.graphics.RadialGradient;
import android.graphics.RectF;
import android.graphics.Shader;
import android.graphics.Typeface;
import android.graphics.drawable.Drawable;
import android.view.MotionEvent;
import android.view.VelocityTracker;
import android.widget.FrameLayout;

import java.util.HashSet;
import java.util.Set;

/**
 * The whole unwrap in one full-screen, transparent view (same behaviour as the iOS
 * {@code GiftUnwrapView}):
 * <ol>
 * <li><b>Open</b> — the host calls {@link #startFrom} when the gift message is tapped: the
 * wrapped gift (a glass sphere tied with a ribbon in the backdrop's colours, the model inside)
 * comes forward from the message, the chat dims.</li>
 * <li><b>Hint</b> — "Pull the ribbon to unwrap", a pulse on the tab, and a ghost finger that
 * shows the gesture until the person touches it.</li>
 * <li><b>Pull</b> — the tail follows the finger 1:1; the glass stretches, trembles, cracks.
 * Let go early and it springs back; a flick that would carry past the end breaks it.</li>
 * <li><b>Snap</b> — shards, flash, the backdrop floods the screen and its symbol pattern fills
 * it, the animated model springs out.</li>
 * <li><b>Sheet</b> — the reveal condenses into Telegram's gift sheet (header on the backdrop,
 * attribute table, "Show on Profile").</li>
 * </ol>
 * Navigation is left to the host: {@link Callbacks}.
 */
public class GiftUnwrapView extends FrameLayout {
    public interface Callbacks {
        /** "Show on Profile". */
        void onPrimaryAction(GiftUnwrapView view);

        /** The sheet's close button: keep the gift private. */
        void onSecondaryAction(GiftUnwrapView view);

        default void onSnap(GiftUnwrapView view) {
        }
    }

    public static final int PHASE_WRAPPED = 0, PHASE_PULLING = 1, PHASE_SNAPPED = 2, PHASE_LEAVING = 3;

    /** Sphere radius and the tail geometry, dp at sphere scale 1. */
    static final float RADIUS_DP = GlassSphere.RADIUS_DP;
    private static final float K = RADIUS_DP / 74f;
    private static final float TAIL_X = 45f * K, TAIL_Y = 102f * K, PULL_X = 16f * K, PULL_Y = 122f * K;
    // The second tail hangs down and to the left, clear of the glass.
    private static final float LEFT_X = -25f * K, LEFT_Y = 143f * K;
    private static final float GHOST_DP = 74f;
    /** Seconds after the snap when the reveal condenses into the sheet. */
    private static final float CONDENSE = 1.2f;

    private final GiftUnwrapContent content;
    private final GlassSphere sphere = new GlassSphere();
    private final GlassShards shards = new GlassShards();
    private final RibbonTails ribbon = new RibbonTails();
    private final RibbonTails.Cracks cracks;
    private final PatternBackdrop backdrop;
    private final Effects effects;
    private final GiftSheetView sheet;
    private final GUFeedback feedback;
    private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint hintText = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint guide = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Path clip = new Path();
    private final RectF rect = new RectF();
    private final long baseNanos = GUMotion.nowNanos();
    private Callbacks callbacks;

    private int phase = PHASE_WRAPPED;
    private float sphereX, sphereY;
    private int safeTop, safeBottom;
    private boolean started;
    private boolean touchedOnce;

    private float openTime = -100f, originX, originY, originScale = 1f;
    private float arrival = -100f, jelly = -100f, idleSince;
    private float tension, tailDx, tailDy, grabDx, grabDy;
    private int lastHapticStep;
    private boolean crackStarted;
    private float releaseTime = -1f, releaseTension, releaseDx, releaseDy;
    private float autoSnapTime = -1f, autoSnapTension, autoSnapDx, autoSnapDy;
    private VelocityTracker velocity;

    private float snapTime, snapX, snapY, snapScale = 1f;
    private float snapKnotX, snapKnotY, snapTailX, snapTailY, snapLeftX, snapLeftY;
    private float leaveTime = -1f;
    private boolean giftTaken;
    private float exitTime = -1f;
    private PointF exitTarget;
    private Runnable exitCompletion;
    private final Set<String> fired = new HashSet<>();
    private boolean shardsVisible = true;
    private final RectF sheetRect = new RectF();

    // last drawn gift geometry (for takeGift)
    private float giftX, giftY, giftSize, giftRotation;

    public GiftUnwrapView(Context context, GiftUnwrapContent content) {
        super(context);
        this.content = content;
        setWillNotDraw(false);
        setClipChildren(false);
        cracks = new RibbonTails.Cracks(GlassSphere.KNOT[0], -GlassSphere.KNOT[1]);
        int[] rib = content.backdrop.ribbon();
        sphere.setColors(rib[0], rib[1], rib[2]);
        ribbon.setColors(rib[0], rib[1], rib[2]);
        backdrop = new PatternBackdrop(content.backdrop, content.symbolBitmap, content.symbolDrawable);
        effects = new Effects(content.backdrop.inner);
        feedback = new GUFeedback(this);
        sheet = new GiftSheetView(context, content);
        sheet.setVisibility(INVISIBLE);
        sheet.onPrimary = this::primaryTapped;
        sheet.onClose = this::secondaryTapped;
        addView(sheet, new LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT));
        if (content.art != null && content.art.drawable != null) {
            content.art.drawable.setCallback(this);
        }
        hintText.setColor(0xffffffff);
        hintText.setTextAlign(Paint.Align.CENTER);
        hintText.setTextSize(GUMotion.dp(15f));
        hintText.setTypeface(Typeface.create("sans-serif-medium", Typeface.NORMAL));
        guide.setStyle(Paint.Style.STROKE);
        guide.setStrokeCap(Paint.Cap.ROUND);
        guide.setStrokeJoin(Paint.Join.ROUND);
        guide.setColor(0xd9ffffff);
        guide.setStrokeWidth(GUMotion.dp(2.2f));
    }

    /** Full sphere radius in px (for {@link #showInMessage} scales). */
    public static float sphereRadiusPx() {
        return GUMotion.dp(RADIUS_DP);
    }

    public void setCallbacks(Callbacks callbacks) {
        this.callbacks = callbacks;
    }

    public GUFeedback getFeedback() {
        return feedback;
    }

    public int getPhase() {
        return phase;
    }

    /** Centre of the sphere once it is in front of the chat, in this view's pixels. */
    public void setSphereCenter(float x, float y) {
        sphereX = x;
        sphereY = y;
        invalidate();
    }

    /** The default sphere centre for this view's size (42 % down the safe area). */
    public PointF defaultSphereCenter() {
        return new PointF(getWidth() / 2f, safeTop + (getHeight() - safeTop - safeBottom) * 0.43f);
    }

    public void setSafeInsets(int top, int bottom) {
        safeTop = top;
        safeBottom = bottom;
        requestLayout();
    }

    /**
     * Shows the wrapped gift resting in its message: {@code x, y} = centre of the message's
     * sticker slot, {@code scale} = slot sphere radius / full radius. Touches pass through to the
     * chat until {@link #open()}.
     */
    public void showInMessage(float x, float y, float scale, boolean animated) {
        float t = now();
        originX = x;
        originY = y;
        originScale = scale;
        openTime = 1e9f;
        arrival = animated ? t : t - 10f;
        phase = PHASE_WRAPPED;
        started = true;
        post(() -> {
            feedback.prepare();
            if (animated) {
                feedback.play(GUFeedback.Sound.ARRIVE);
            }
        });
        invalidate();
    }

    /** The gift message was tapped: the wrapped gift comes forward, the chat dims, the hint starts. */
    public void open() {
        if (openTime < 1e8f) {
            return;
        }
        float t = now();
        openTime = t;
        idleSince = t + 0.6f;
        feedback.tap();
        feedback.play(GUFeedback.Sound.WHOOSH, 0.5f);
        invalidate();
    }

    /** {@link #showInMessage} + {@link #open()} in one go. */
    public void startFrom(float x, float y, float scale) {
        showInMessage(x, y, scale, false);
        open();
    }

    public boolean isOpen() {
        return openTime < 1e8f;
    }

    /** Shows the wrapped gift right in place (popping up like a new message when {@code animated}). */
    public void start(boolean animated) {
        float t = now();
        arrival = animated ? t : t - 10f;
        openTime = t - 10f;
        originX = sphereX;
        originY = sphereY;
        originScale = 1f;
        idleSince = t;
        phase = PHASE_WRAPPED;
        started = true;
        post(() -> {
            feedback.prepare();
            if (animated) {
                feedback.play(GUFeedback.Sound.ARRIVE);
            }
        });
        invalidate();
    }

    /** Breaks the glass without a gesture. */
    public void snap() {
        if (phase == PHASE_WRAPPED || phase == PHASE_PULLING) {
            performSnap(now());
        }
    }

    /** The gift's current frame (px) — the host draws its own flight from here; the sheet drops. */
    public RectF takeGift() {
        giftTaken = true;
        if (leaveTime < 0f) {
            leaveTime = now();
        }
        invalidate();
        return new RectF(giftX - giftSize / 2f, giftY - giftSize / 2f, giftX + giftSize / 2f, giftY + giftSize / 2f);
    }

    /** Drops the sheet and flies the gift to {@code target} (or lets it fade). */
    public void playExit(PointF target, Runnable completion) {
        if (leaveTime < 0f) {
            leaveTime = now();
        }
        phase = PHASE_LEAVING;
        exitTime = now();
        exitTarget = target;
        exitCompletion = completion;
        invalidate();
    }

    public void release() {
        feedback.release();
    }

    private float now() {
        return (GUMotion.nowNanos() - baseNanos) / 1e9f;
    }

    private static float dp(float v) {
        return GUMotion.dp(v);
    }

    // --- layout

    private void layoutSheet(int w, int h) {
        int rows = GiftSheetView.tableRows(content);
        float bodyH = dp(GiftSheetView.bodyHeightDp(rows));
        float bottom = h - Math.max(dp(6f), safeBottom);
        float headerH = Math.max(dp(250f), Math.min(dp(GiftSheetView.HEADER_DP), bottom - bodyH - safeTop - dp(40f)));
        sheetRect.set(dp(6f), bottom - bodyH - headerH, w - dp(6f), bottom);
    }

    @Override
    protected void onLayout(boolean changed, int left, int top, int right, int bottom) {
        int w = right - left, h = bottom - top;
        layoutSheet(w, h);
        sheet.layout(Math.round(sheetRect.left), Math.round(sheetRect.top), Math.round(sheetRect.right), Math.round(sheetRect.bottom));
        if (sphereX == 0f && sphereY == 0f) {
            PointF c = defaultSphereCenter();
            sphereX = c.x;
            sphereY = c.y;
        }
    }

    @Override
    protected void onMeasure(int widthMeasureSpec, int heightMeasureSpec) {
        super.onMeasure(widthMeasureSpec, heightMeasureSpec);
        layoutSheet(getMeasuredWidth(), getMeasuredHeight());
        sheet.measure(MeasureSpec.makeMeasureSpec(Math.round(sheetRect.width()), MeasureSpec.EXACTLY),
                MeasureSpec.makeMeasureSpec(Math.round(sheetRect.height()), MeasureSpec.EXACTLY));
    }

    // --- sphere position

    private float openK(float t) {
        return GUMotion.spring(t - openTime, GUMotion.MENU);
    }

    private float sphereScale(float t) {
        float pop = GUMotion.lerp(0.25f, 1f, GUMotion.spring(t - arrival, GUMotion.BOUNCE));
        return GUMotion.lerp(originScale, 1f, openK(t)) * pop;
    }

    private float sphereCX(float t) {
        return GUMotion.lerp(originX, sphereX, openK(t));
    }

    private float sphereCY(float t) {
        return GUMotion.lerp(originY, sphereY, openK(t));
    }

    private float tailEndX(float t) {
        return sphereCX(t) + dp(TAIL_X) * sphereScale(t) + tailDx;
    }

    private float tailEndY(float t) {
        return sphereCY(t) + dp(TAIL_Y) * sphereScale(t) + tailDy;
    }

    // --- hint: the ghost finger shows the pull until the person touches the gift

    private static final float GHOST_START = 0.95f, GHOST_CYCLE = 4.2f;

    /** Ghost pull distance in px (≥ 0), or -1 when no ghost is shown. */
    private float ghostDistance(float t) {
        if (touchedOnce || phase != PHASE_WRAPPED || releaseTime >= 0f) {
            return -1f;
        }
        float idle = t - openTime - GHOST_START;
        if (idle < 0f) {
            return -1f;
        }
        float c = idle % GHOST_CYCLE;
        if (c > 1.25f) {
            return -1f;
        }
        return dp(GHOST_DP) * GUMotion.easeInOut(GUMotion.clamp((c - 0.22f) / 0.5f));
    }

    /** Spring-back of the tail after a ghost lets go (px along the pull axis). */
    private float ghostRelease(float t) {
        if (touchedOnce || phase != PHASE_WRAPPED) {
            return 0f;
        }
        float idle = t - openTime - GHOST_START;
        if (idle < 0f) {
            return 0f;
        }
        float c = idle % GHOST_CYCLE;
        if (c < 0.9f) {
            return 0f;
        }
        return dp(GHOST_DP) * (1f - GUMotion.spring(c - 0.9f, GUMotion.BOUNCE));
    }

    // --- touches

    @SuppressLint("ClickableViewAccessibility")
    @Override
    public boolean onTouchEvent(MotionEvent e) {
        float t = now();
        float x = e.getX(), y = e.getY();
        if (phase == PHASE_SNAPPED) {
            return true; // the sheet blocks the chat underneath
        }
        if (phase == PHASE_LEAVING || !started || !isOpen() || openK(t) < 0.85f) {
            return false;
        }
        float s = sphereScale(t);
        float plen = (float) Math.hypot(PULL_X, PULL_Y);
        float ux = PULL_X / plen, uy = PULL_Y / plen;
        switch (e.getActionMasked()) {
            case MotionEvent.ACTION_DOWN: {
                float ex = tailEndX(t), ey = tailEndY(t);
                if (Math.hypot(x - ex, y - ey) < dp(48f)) {
                    touchedOnce = true;
                    phase = PHASE_PULLING;
                    releaseTime = -1f;
                    grabDx = ex - x;
                    grabDy = ey - y;
                    lastHapticStep = (int) (tension * 10f);
                    velocity = VelocityTracker.obtain();
                    velocity.addMovement(e);
                    getParent().requestDisallowInterceptTouchEvent(true);
                    feedback.tick();
                    invalidate();
                    return true;
                }
                if (Math.hypot(x - sphereCX(t), y - sphereCY(t)) < dp(RADIUS_DP) * s + dp(8f)) {
                    jelly = t;
                    feedback.tick();
                    invalidate();
                    return true;
                }
                return true; // the dimmed chat behind is not interactive
            }
            case MotionEvent.ACTION_MOVE: {
                if (phase != PHASE_PULLING) {
                    return false;
                }
                if (velocity != null) {
                    velocity.addMovement(e);
                }
                float restX = sphereCX(t) + dp(TAIL_X) * s, restY = sphereCY(t) + dp(TAIL_Y) * s;
                float vx = x + grabDx - restX, vy = y + grabDy - restY;
                float along = vx * ux + vy * uy;
                float px = vx - ux * along, py = vy - uy * along;
                float pl = (float) Math.hypot(px, py);
                float soft = GUMotion.rubberBand(pl, dp(90f));
                float dx = pl > 0.001f ? px / pl : 0f, dy = pl > 0.001f ? py / pl : 0f;
                if (along < 0f) {
                    along = -GUMotion.rubberBand(-along, dp(60f));
                }
                tailDx = ux * along + dx * soft;
                tailDy = uy * along + dy * soft;
                setTension(Math.max(0f, along / (dp(plen) * s)), t);
                invalidate();
                return true;
            }
            case MotionEvent.ACTION_UP:
            case MotionEvent.ACTION_CANCEL: {
                if (phase != PHASE_PULLING) {
                    return false;
                }
                float vAlong = 0f;
                if (velocity != null) {
                    velocity.addMovement(e);
                    velocity.computeCurrentVelocity(1000);
                    vAlong = velocity.getXVelocity() * ux + velocity.getYVelocity() * uy;
                    velocity.recycle();
                    velocity = null;
                }
                // Apple's momentum projection (deceleration 0.99).
                float projected = (vAlong / 1000f) * 0.99f / (1f - 0.99f);
                float along = tailDx * ux + tailDy * uy;
                if (e.getActionMasked() == MotionEvent.ACTION_UP && (along + projected) / (dp(plen) * s) >= 1f) {
                    autoSnapTime = t;
                    autoSnapTension = tension;
                    autoSnapDx = tailDx;
                    autoSnapDy = tailDy;
                } else {
                    phase = PHASE_WRAPPED;
                    releaseTime = t;
                    releaseTension = tension;
                    releaseDx = tailDx;
                    releaseDy = tailDy;
                    jelly = t;
                    idleSince = t;
                    crackStarted = false;
                }
                invalidate();
                return true;
            }
        }
        return super.onTouchEvent(e);
    }

    private void setTension(float value, float t) {
        tension = Math.min(1f, value);
        int step = (int) (tension * 10f);
        if (step > lastHapticStep) {
            feedback.tension();
            feedback.play(GUFeedback.Sound.CREAK, 0.3f + 0.7f * tension);
        }
        lastHapticStep = step;
        if (tension >= 0.86f && !crackStarted) {
            crackStarted = true;
            feedback.crackle();
            feedback.play(GUFeedback.Sound.CRACKLE);
        }
        if (value >= 1f) {
            performSnap(t);
        }
    }

    private void performSnap(float t) {
        if (phase == PHASE_SNAPPED || phase == PHASE_LEAVING) {
            return;
        }
        phase = PHASE_SNAPPED;
        snapTime = t;
        snapScale = sphereScale(t);
        snapX = sphereCX(t);
        snapY = sphereCY(t);
        PointF k = sphere.knotPoint();
        snapKnotX = k.x;
        snapKnotY = k.y;
        snapTailX = tailEndX(t);
        snapTailY = tailEndY(t);
        snapLeftX = snapX + dp(LEFT_X) * snapScale;
        snapLeftY = snapY + dp(LEFT_Y + 10f) * snapScale;
        autoSnapTime = -1f;
        feedback.shatter();
        feedback.play(GUFeedback.Sound.SHATTER);
        if (callbacks != null) {
            callbacks.onSnap(this);
        }
    }

    private void primaryTapped() {
        if (phase != PHASE_SNAPPED) {
            return;
        }
        feedback.tap();
        feedback.play(GUFeedback.Sound.TAP);
        phase = PHASE_LEAVING;
        if (callbacks != null) {
            callbacks.onPrimaryAction(this);
        }
    }

    private void secondaryTapped() {
        if (phase != PHASE_SNAPPED) {
            return;
        }
        feedback.tap();
        if (callbacks != null) {
            callbacks.onSecondaryAction(this);
        }
    }

    // --- drawing

    @Override
    protected boolean verifyDrawable(Drawable who) {
        return (content.art != null && who == content.art.drawable) || super.verifyDrawable(who);
    }

    @Override
    protected void onDraw(Canvas canvas) {
        if (!started) {
            return;
        }
        float t = now();
        if (releaseTime >= 0f && phase == PHASE_WRAPPED) {
            float k = GUMotion.spring(t - releaseTime, GUMotion.BOUNCE);
            tension = Math.max(0f, releaseTension * (1f - k));
            tailDx = releaseDx * (1f - k);
            tailDy = releaseDy * (1f - k);
            if (t - releaseTime > 1.2f) {
                releaseTime = -1f;
                tension = 0f;
                tailDx = tailDy = 0f;
            }
            lastHapticStep = (int) (tension * 10f);
        }
        if (autoSnapTime >= 0f && phase == PHASE_PULLING) {
            float u = GUMotion.clamp((t - autoSnapTime) / 0.12f);
            float s = sphereScale(t);
            tailDx = GUMotion.lerp(autoSnapDx, dp(PULL_X) * s, u);
            tailDy = GUMotion.lerp(autoSnapDy, dp(PULL_Y) * s, u);
            setTension(GUMotion.lerp(autoSnapTension, 1.0001f, u), t);
        }
        drawScrim(canvas, t);
        if (phase == PHASE_WRAPPED || phase == PHASE_PULLING) {
            drawWrapped(canvas, t);
        } else {
            drawSnapped(canvas, t);
        }
        postInvalidateOnAnimation();
    }

    private float leaveK(float t) {
        return leaveTime >= 0f ? GUMotion.easeIn(GUMotion.clamp((t - leaveTime) / 0.42f)) : 0f;
    }

    private void drawScrim(Canvas canvas, float t) {
        float open = GUMotion.easeInOut(GUMotion.clamp((t - openTime) / 0.45f));
        float a = 0.42f * open;
        if (phase >= PHASE_SNAPPED) {
            a = GUMotion.lerp(0.42f, 0.36f, GUMotion.spring(t - snapTime - CONDENSE, GUMotion.SHEET)) * (1f - leaveK(t));
        }
        if (a > 0.003f) {
            canvas.drawColor(GUMotion.withAlpha(0xff000000, a));
        }
    }

    private void drawWrapped(Canvas canvas, float t) {
        float ta = t - arrival;
        float alpha = GUMotion.clamp(ta / 0.12f);
        float scale = sphereScale(t);
        float cx = sphereCX(t), cy = sphereCY(t);
        float wob = 0f;
        float ua = ta - 0.12f;
        if (ua > 0f) {
            wob += 0.075f * (float) (Math.exp(-ua * 4.2f) * Math.sin(ua * 2 * Math.PI * 3.1));
        }
        float uo = t - openTime - 0.25f;
        if (uo > 0f && uo < 2f) {
            wob += 0.05f * (float) (Math.exp(-uo * 4.5f) * Math.sin(uo * 2 * Math.PI * 2.8));
        }
        float uj = t - jelly;
        if (uj > 0f && uj < 2f) {
            wob += 0.06f * (float) (Math.exp(-uj * 4.2f) * Math.sin(uj * 2 * Math.PI * 3.1));
        }
        float breath = phase == PHASE_WRAPPED ? 0.012f * (float) Math.sin(t * 2.6f) : 0f;
        float amp = dp(2.2f) * (float) Math.pow(GUMotion.clamp((tension - 0.55f) / 0.45f), 2.5);
        float tx = (float) Math.sin(t * 83f) * amp, ty = (float) Math.cos(t * 97f) * amp;

        // the ghost finger moves the tail (drawing only)
        float plen = (float) Math.hypot(PULL_X, PULL_Y);
        float ux = PULL_X / plen, uy = PULL_Y / plen;
        float gd = ghostDistance(t);
        float gOff = gd >= 0f ? gd : ghostRelease(t);
        float gTension = gOff / (dp(plen) * scale) * 0.6f;
        float ten = Math.max(tension, gTension);

        sphere.set(cx + tx, cy + ty, scale, 1f + wob - breath, 1f - wob + breath, ten, ten, alpha);

        // far half of the bands, a haze of the backdrop and the model inside, the glass, the near half and the bow
        sphere.drawBack(canvas);
        float hr = dp(RADIUS_DP) * scale * 0.85f;
        paint.setShader(new RadialGradient(cx, cy, hr, GUMotion.withAlpha(content.backdrop.inner, 0.6f * alpha), GUMotion.withAlpha(content.backdrop.outer, 0f), Shader.TileMode.CLAMP));
        canvas.drawCircle(cx, cy, hr, paint);
        paint.setShader(null);
        float gx = cx + tx + ux * ten * dp(6f), gy = cy + ty - dp(4f) * scale + uy * ten * dp(6f);
        drawGift(canvas, gx, gy, dp(112f * K) * scale, (float) Math.toDegrees(Math.sin(t * 1.5f) * 0.07f), 0f, alpha * 0.92f, t);
        sphere.drawGlass(canvas);
        sphere.drawFront(canvas);

        PointF knot = sphere.knotPoint();
        float swayX = phase == PHASE_WRAPPED ? (float) Math.sin(t * 2.1f) * dp(2f) : 0f;
        float swayY = phase == PHASE_WRAPPED ? (float) Math.sin(t * 1.6f) * dp(1.5f) : 0f;
        float ex = cx + dp(TAIL_X) * scale + tailDx + swayX + ux * gOff;
        float ey = cy + dp(TAIL_Y) * scale + tailDy + swayY + uy * gOff;
        float lx = cx + (dp(LEFT_X) + (float) Math.sin(t * 1.7f) * dp(1.5f)) * scale;
        float ly = cy + (dp(LEFT_Y) + ten * dp(10f)) * scale;
        ribbon.draw(canvas, knot.x, knot.y, ex, ey, lx, ly, dp(10f) * (1f - ten), alpha, -1f, scale);

        float crack = GUMotion.clamp((tension - 0.86f) / 0.14f);
        if (crack > 0f) {
            Path outline = sphere.outline();
            cracks.draw(canvas, outline, sphere.cx, sphere.cy, sphere.radius, crack, 1f);
        }
        drawHint(canvas, t, cx, cy, scale, ux, uy, gd);
    }

    /** "Pull the ribbon to unwrap", the pulse on the tab and the ghost finger with its guide. */
    private void drawHint(Canvas canvas, float t, float cx, float cy, float scale, float ux, float uy, float gd) {
        float shown = GUMotion.tg(GUMotion.clamp((t - openTime - 0.55f) / 0.3f));
        float gone = touchedOnce ? 1f : 0f;
        float a = shown * (1f - gone);
        if (a <= 0.003f) {
            return;
        }
        float restX = cx + dp(TAIL_X) * scale, restY = cy + dp(TAIL_Y) * scale;
        // capsule above the gift
        String text = content.hint;
        float tw = hintText.measureText(text);
        float hy = cy - dp(RADIUS_DP) * scale - dp(52f) + (1f - shown) * dp(10f);
        rect.set(cx - tw / 2f - dp(16f), hy - dp(18f), cx + tw / 2f + dp(16f), hy + dp(18f));
        paint.setColor(GUMotion.withAlpha(0xff000000, 0.32f * a));
        canvas.drawRoundRect(rect, dp(18f), dp(18f), paint);
        hintText.setAlpha((int) (255 * a));
        canvas.drawText(text, cx, hy - (hintText.descent() + hintText.ascent()) / 2f, hintText);
        // pulse ring on the tab (not while the ghost is demonstrating)
        float idle = t - openTime - 0.65f;
        boolean ghostNear = gd >= 0f || ghostRelease(t) > dp(1f);
        if (idle > 0f && !ghostNear) {
            float p = (idle % 1.3f) / 0.9f;
            if (p <= 1f) {
                paint.setStyle(Paint.Style.STROKE);
                paint.setStrokeWidth(dp(2f));
                paint.setColor(GUMotion.withAlpha(0xffffffff, 0.85f * (float) Math.sin(Math.PI * p) * a));
                canvas.drawCircle(restX, restY, dp(20f) * (0.7f + 0.6f * p), paint);
                paint.setStyle(Paint.Style.FILL);
            }
        }
        // ghost finger + dotted guide with an arrow head
        if (gd >= 0f) {
            float c = (t - openTime - GHOST_START) % GHOST_CYCLE;
            float fa = Math.min(GUMotion.clamp(c / 0.12f), 1f - GUMotion.clamp((c - 0.95f) / 0.2f)) * a;
            float ga = GUMotion.clamp((c - 0.15f) / 0.15f) * (1f - GUMotion.clamp((c - 0.9f) / 0.2f)) * a;
            if (ga > 0f) {
                float sx = restX + ux * dp(26f), sy = restY + uy * dp(26f);
                float exx = restX + ux * dp(GHOST_DP + 26f), eyy = restY + uy * dp(GHOST_DP + 26f);
                guide.setAlpha((int) (217 * ga));
                guide.setPathEffect(new DashPathEffect(new float[]{0.1f, dp(7f)}, 0f));
                canvas.drawLine(sx, sy, exx, eyy, guide);
                guide.setPathEffect(null);
                float px = -uy, py = ux, h = dp(6.5f);
                canvas.drawLine(exx - ux * h + px * h, eyy - uy * h + py * h, exx, eyy, guide);
                canvas.drawLine(exx - ux * h - px * h, eyy - uy * h - py * h, exx, eyy, guide);
            }
            float fx = restX + ux * gd, fy = restY + uy * gd;
            float press = GUMotion.clamp(c / 0.12f);
            float r = dp(21f) * (1.2f - 0.2f * press);
            paint.setShader(new RadialGradient(fx, fy, r, new int[]{GUMotion.withAlpha(0xffffffff, 0.42f * fa), GUMotion.withAlpha(0xffffffff, 0.22f * fa)}, null, Shader.TileMode.CLAMP));
            canvas.drawCircle(fx, fy, r, paint);
            paint.setShader(null);
            paint.setStyle(Paint.Style.STROKE);
            paint.setStrokeWidth(dp(1f));
            paint.setColor(GUMotion.withAlpha(0xffffffff, 0.55f * fa));
            canvas.drawCircle(fx, fy, r, paint);
            paint.setStyle(Paint.Style.FILL);
        }
    }

    private void drawSnapped(Canvas canvas, float t) {
        float st = t - snapTime;
        int w = getWidth(), h = getHeight();
        float leave = leaveK(t);
        float drop = dp(760f) * leave;
        float exitU = exitTime >= 0f ? GUMotion.clamp((t - exitTime) / 0.55f) : 0f;
        float k = GUMotion.spring(st - CONDENSE, GUMotion.SHEET);   // reveal → sheet

        // gift: pops out of the glass, then settles in the sheet header
        float pop = GUMotion.spring(st - 0.02f, GUMotion.BOUNCE);
        float revealSize = dp(172f) * w / dp(402f);
        float hk = sheetRect.height() > 0 ? (sheetRect.height() - dp(GiftSheetView.bodyHeightDp(GiftSheetView.tableRows(content)))) / dp(GiftSheetView.HEADER_DP) : 1f;
        float sheetGiftY = sheetRect.top + dp(100f) * hk;
        float gx = GUMotion.lerp(snapX, w / 2f, k);
        float gy = GUMotion.lerp(snapY + (float) Math.sin(st * 2f) * dp(2.5f) * GUMotion.clamp(st), sheetGiftY, k) + (giftTaken ? 0f : drop);
        float gs = GUMotion.lerp(GUMotion.lerp(dp(RADIUS_DP * 1.1f) * snapScale, revealSize, pop), dp(128f) * Math.min(1f, hk * 1.05f), k);
        float rz = (float) (-0.3 * Math.exp(-st * 3.6) * Math.cos(st * 12.0));

        // backdrop: floods from the glass, then condenses into the sheet header (it runs under the body)
        float maxR = 0f;
        float[][] corners = {{0, 0}, {w, 0}, {0, h}, {w, h}};
        for (float[] c : corners) {
            maxR = Math.max(maxR, (float) Math.hypot(c[0] - snapX, c[1] - snapY));
        }
        float revealR = (maxR + dp(40f)) * GUMotion.bezier(0.25f, 0.75f, 0.3f, 1f, (st - 0.02f) / 0.9f);
        clip.rewind();
        if (k <= 0.001f) {
            clip.addCircle(snapX, snapY, Math.max(0f, revealR), Path.Direction.CW);
        } else {
            float headerBottom = sheetRect.top + (sheetRect.height() - dp(GiftSheetView.bodyHeightDp(GiftSheetView.tableRows(content)))) + dp(60f);
            rect.set(GUMotion.lerp(-2f, sheetRect.left, k), GUMotion.lerp(-2f, sheetRect.top, k) + drop,
                    GUMotion.lerp(w + 2f, sheetRect.right, k), GUMotion.lerp(h + 2f, headerBottom, k) + drop);
            float r = dp(38f) * k;
            clip.addRoundRect(rect, new float[]{r, r, r, r, 0, 0, 0, 0}, Path.Direction.CW);
        }
        backdrop.centerX = gx;
        backdrop.centerY = giftTaken ? gy + drop : gy;
        backdrop.gradientRadius = dp(GUMotion.lerp(470f, 300f, k));
        backdrop.scale = GUMotion.lerp(1f, 0.82f, k);
        backdrop.holeDp = GUMotion.lerp(70f, 58f, k);
        float bl = GUMotion.easeInOut(GUMotion.seg(st, 0.05f, 0.5f)) * (0.55f + 0.45f * (float) Math.exp(-st * 0.9f));
        if (exitU < 1f && (st > 0f)) {
            backdrop.draw(canvas, clip, w, h, st - 0.12f, snapX, snapY, dp(900f), bl * (1f - exitU));
        }

        // sheet (header texts, chips, body)
        if (st > CONDENSE) {
            sheet.setVisibility(VISIBLE);
            sheet.setAppear(st - CONDENSE);
            sheet.setTranslationY(drop);
        } else {
            sheet.setVisibility(INVISIBLE);
        }

        effects.drawBehindGift(canvas, st, gx, gy, gs, (1f - k) * (1f - leave), t);
        if (!giftTaken) {
            float ga = 1f;
            float fx = gx, fy = gy, fs = gs;
            if (exitTime >= 0f) {
                float e = GUMotion.bezier(0.42f, 0f, 0.2f, 1f, exitU);
                if (exitTarget != null) {
                    fx = GUMotion.lerp(gx, exitTarget.x, e);
                    fy = GUMotion.lerp(gy - drop, exitTarget.y, e);
                }
                fs *= GUMotion.lerp(1f, 0.3f, e);
                ga = 1f - GUMotion.clamp((exitU - 0.7f) / 0.3f);
            }
            drawGift(canvas, fx, fy, fs, (float) Math.toDegrees(rz), 0f, ga, t);
        }

        // shards, tails, cracks fading
        if (shardsVisible) {
            float camera = h / (2f * (float) Math.tan(Math.toRadians(15.0)));
            shardsVisible = shards.draw(canvas, st, snapX, snapY, dp(RADIUS_DP) * snapScale, camera) || st < 0.3f;
        }
        float fall = st * st * dp(900f);
        float ta = 1f - GUMotion.clamp(st / 0.22f);
        if (ta > 0f) {
            float pullOut = GUMotion.easeOut(st / 0.3f);
            ribbon.draw(canvas, snapKnotX, snapKnotY + fall * 0.6f, snapTailX + dp(8f) * pullOut, snapTailY + fall + dp(26f) * pullOut, snapLeftX, snapLeftY + fall, dp(14f), ta, -1f, snapScale);
        }
        effects.drawFront(canvas, st, snapX, snapY, gx, gy, (1f - k) * (1f - leave), t);

        once("shimmer", st > 0.05f, () -> feedback.play(GUFeedback.Sound.SHIMMER));
        once("pattern", st > 0.2f, () -> {
            feedback.play(GUFeedback.Sound.PATTERN);
            feedback.tick();
        });
        once("pattern2", st > 0.45f, feedback::tick);
        once("sheet", st > CONDENSE + 0.05f, () -> feedback.play(GUFeedback.Sound.WHOOSH, 0.35f));
        if (exitTime >= 0f && exitU >= 1f && exitCompletion != null) {
            Runnable r = exitCompletion;
            exitCompletion = null;
            post(r);
        }
    }

    private void once(String id, boolean condition, Runnable r) {
        if (condition && fired.add(id)) {
            r.run();
        }
    }

    private void drawGift(Canvas canvas, float x, float y, float size, float rotationDeg, float squash, float alpha, float t) {
        giftX = x;
        giftY = y;
        giftSize = size;
        giftRotation = rotationDeg;
        if (content.art != null) {
            content.art.draw(canvas, x, y, size, rotationDeg, squash, alpha, t);
        }
    }

    /** Current rotation of the gift in degrees (for a seamless hand-off to a flight). */
    public float getGiftRotation() {
        return giftRotation;
    }

    /** Seconds on this view's clock (the gift's animation phase, for a seamless hand-off). */
    public float clock() {
        return now();
    }
}
