package org.telegram.ui.Gifts;

import static org.telegram.messenger.AndroidUtilities.dp;

import android.app.Activity;
import android.content.Context;
import android.graphics.PointF;
import android.graphics.drawable.Drawable;
import android.os.Bundle;
import android.view.ViewGroup;
import android.widget.FrameLayout;

import com.designers.giftunwrap.GiftUnwrapContent;
import com.designers.giftunwrap.GiftUnwrapView;

import org.telegram.messenger.AndroidUtilities;
import org.telegram.messenger.ImageReceiver;
import org.telegram.messenger.LocaleController;
import org.telegram.messenger.MessageObject;
import org.telegram.messenger.MessagesController;
import org.telegram.messenger.R;
import org.telegram.messenger.UserConfig;
import org.telegram.tgnet.ConnectionsManager;
import org.telegram.tgnet.TLRPC;
import org.telegram.tgnet.tl.TL_stars;
import org.telegram.ui.ActionBar.BaseFragment;
import org.telegram.ui.Components.AnimatedEmojiDrawable;
import org.telegram.ui.Components.BulletinFactory;
import org.telegram.ui.LaunchActivity;
import org.telegram.ui.ProfileActivity;
import org.telegram.ui.Stars.StarsController;
import org.telegram.ui.Stars.StarsIntroActivity;

/**
 * Plays the unwrap over the whole window when an incoming collectible gift message is tapped
 * for the first time (see ChatActionCell patch in INTEGRATION.md). Works for any collectible:
 * everything comes from the gift's own attributes. The visuals are the shared
 * {@link GiftUnwrapView}; this class only plugs Telegram in:
 * the model and the symbol are Telegram's own sticker drawables, the colours, names and
 * rarities come from the gift attributes, "Show on Profile" sends payments.saveStarGift.
 */
public final class GiftUnwrapOverlay {
    private GiftUnwrapOverlay() {
    }

    private static String key(int account, MessageObject message) {
        return "gift_unwrap_" + message.getDialogId() + "_" + message.getId();
    }

    /** True until this gift message has been unwrapped once on this device. */
    public static boolean shouldUnwrap(int account, MessageObject message) {
        return !MessagesController.getGlobalMainSettings().getBoolean(key(account, message), false);
    }

    private static void markUnwrapped(int account, MessageObject message) {
        MessagesController.getGlobalMainSettings().edit().putBoolean(key(account, message), true).apply();
    }

    /**
     * @param slotX centre of the gift's sticker in the message, in window pixels (the wrapped
     *              gift comes forward from there)
     */
    public static void show(Context context, int account, MessageObject message, TL_stars.TL_starGiftUnique gift, boolean savedToProfile, float slotX, float slotY, Runnable openDetails) {
        Activity activity = AndroidUtilities.findActivity(context);
        if (activity == null) {
            activity = LaunchActivity.instance;
        }
        if (activity == null) {
            openDetails.run();
            return;
        }
        final ViewGroup container = (ViewGroup) activity.getWindow().getDecorView();

        TL_stars.starGiftAttributeModel model = null;
        TL_stars.starGiftAttributePattern pattern = null;
        TL_stars.starGiftAttributeBackdrop backdrop = null;
        for (TL_stars.StarGiftAttribute a : gift.attributes) {
            if (a instanceof TL_stars.starGiftAttributeModel) {
                model = (TL_stars.starGiftAttributeModel) a;
            } else if (a instanceof TL_stars.starGiftAttributePattern) {
                pattern = (TL_stars.starGiftAttributePattern) a;
            } else if (a instanceof TL_stars.starGiftAttributeBackdrop) {
                backdrop = (TL_stars.starGiftAttributeBackdrop) a;
            }
        }

        GiftUnwrapContent c = new GiftUnwrapContent();
        c.title = gift.title;
        c.number = gift.num;
        if (backdrop != null) {
            c.backdrop = new GiftUnwrapContent.Backdrop(backdrop.center_color | 0xFF000000, backdrop.edge_color | 0xFF000000, backdrop.pattern_color | 0xFF000000, backdrop.text_color | 0xFF000000);
        }
        // Telegram's table order: Model, Symbol, Backdrop (with rarity), Availability, From.
        if (model != null) {
            c.addRow(LocaleController.getString(R.string.Gift2AttributeModel), model.name, rarity(model.rarity), null);
        }
        if (pattern != null) {
            c.addRow(LocaleController.getString(R.string.Gift2AttributeSymbol), pattern.name, rarity(pattern.rarity), null);
        }
        if (backdrop != null) {
            c.addRow(LocaleController.getString(R.string.Gift2AttributeBackdrop), backdrop.name, rarity(backdrop.rarity), null);
        }
        c.addRow(LocaleController.getString(R.string.Gift2Availability), GiftUnwrapContent.formatNumber(gift.availability_issued) + "/" + GiftUnwrapContent.formatNumber(gift.availability_total), null, null);
        final TLRPC.User sender = MessagesController.getInstance(account).getUser(message.getSenderId());
        if (sender != null) {
            c.addRow(LocaleController.getString(R.string.Gift2From), org.telegram.messenger.UserObject.getUserName(sender), null, null);
        }
        c.primaryAction = LocaleController.getString(savedToProfile ? R.string.OK : R.string.Gift2ShowOnProfile);
        // iOS wording under the button; Telegram-Android has no string for it yet (add one to localize).
        c.caption = savedToProfile ? "" : "Only you can see this gift for now.";

        // Model: Telegram's sticker through an ImageReceiver wrapped as a Drawable.
        final ImageReceiverDrawable modelDrawable = new ImageReceiverDrawable();
        if (model != null) {
            StarsIntroActivity.setGiftImage(modelDrawable.receiver, model.document, 160);
            c.art = com.designers.giftunwrap.GiftArt.of(modelDrawable);
        }

        // The symbol drawable invalidates the window; GiftUnwrapView redraws every frame anyway.
        AnimatedEmojiDrawable.SwapAnimatedEmojiDrawable symbol = null;
        if (pattern != null) {
            symbol = new AnimatedEmojiDrawable.SwapAnimatedEmojiDrawable(container, false, dp(28));
            symbol.set(pattern.document, false);
            symbol.setColor(c.backdrop.pattern);
            symbol.attach();
            c.symbolDrawable = symbol;
        }

        final GiftUnwrapView view = new GiftUnwrapView(context, c);
        modelDrawable.receiver.setParentView(view);
        modelDrawable.receiver.onAttachedToWindow();

        final AnimatedEmojiDrawable.SwapAnimatedEmojiDrawable symbolRef = symbol;
        final TLRPC.Document sticker = model != null ? model.document : null;

        final Runnable remove = () -> {
            view.release();
            modelDrawable.receiver.onDetachedFromWindow();
            if (symbolRef != null) {
                symbolRef.detach();
            }
            container.removeView(view);
        };

        view.setCallbacks(new GiftUnwrapView.Callbacks() {
            @Override
            public void onPrimaryAction(GiftUnwrapView v) {
                if (savedToProfile) {
                    v.playExit(null, remove);
                    return;
                }
                saveToProfile(account, message, sticker);
                v.playExit(new PointF(v.getWidth() / 2f, -dp(40)), remove);
            }

            @Override
            public void onSecondaryAction(GiftUnwrapView v) {
                // close = keep it private; the usual gift sheet is one tap away on the message
                v.playExit(null, remove);
            }

            @Override
            public void onSnap(GiftUnwrapView v) {
                markUnwrapped(account, message);
            }
        });

        container.addView(view, new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
        view.setSafeInsets(AndroidUtilities.statusBarHeight, AndroidUtilities.navigationBarHeight);
        view.post(() -> {
            final android.graphics.PointF center = view.defaultSphereCenter();
            view.setSphereCenter(center.x, center.y);
            // the wrapped gift comes forward from the message that was tapped
            view.startFrom(slotX, slotY, dp(40) / GiftUnwrapView.sphereRadiusPx());
        });
    }

    private static String rarity(TL_stars.StarGiftAttributeRarity r) {
        if (r instanceof TL_stars.TL_starGiftAttributeRarity) {
            return GiftUnwrapContent.formatRarity(((TL_stars.TL_starGiftAttributeRarity) r).permille);
        } else if (r instanceof TL_stars.TL_starGiftAttributeRarityRare) {
            return "Rare";
        } else if (r instanceof TL_stars.TL_starGiftAttributeRarityEpic) {
            return "Epic";
        } else if (r instanceof TL_stars.TL_starGiftAttributeRarityLegendary) {
            return "Legendary";
        } else if (r instanceof TL_stars.TL_starGiftAttributeRarityUncommon) {
            return "Uncommon";
        }
        return null;
    }

    private static void saveToProfile(int account, MessageObject message, TLRPC.Document sticker) {
        final TL_stars.saveStarGift req = new TL_stars.saveStarGift();
        req.unsave = false;
        final TL_stars.TL_inputSavedStarGiftUser input = new TL_stars.TL_inputSavedStarGiftUser();
        input.msg_id = message.getId();
        req.stargift = input;
        ConnectionsManager.getInstance(account).sendRequest(req, (res, err) -> AndroidUtilities.runOnUIThread(() -> {
            final BaseFragment fragment = LaunchActivity.getSafeLastFragment();
            if (!(res instanceof TLRPC.TL_boolTrue) || fragment == null) {
                return;
            }
            final long selfId = UserConfig.getInstance(account).getClientUserId();
            StarsController.getInstance(account).invalidateProfileGifts(selfId);
            if (sticker == null) {
                return;
            }
            BulletinFactory.of(fragment).createEmojiBulletin(
                    sticker,
                    LocaleController.getString(R.string.Gift2MadePublicTitle),
                    AndroidUtilities.replaceSingleTag(LocaleController.getString(R.string.Gift2MadePublic), () -> {
                        final Bundle args = new Bundle();
                        args.putLong("user_id", selfId);
                        args.putBoolean("my_profile", true);
                        args.putBoolean("open_gifts", true);
                        fragment.presentFragment(new ProfileActivity(args));
                    })
            ).show(true);
        }));
    }

    /** Lets GiftUnwrapView draw Telegram's ImageReceiver (animated sticker) as a Drawable. */
    static final class ImageReceiverDrawable extends Drawable {
        final ImageReceiver receiver = new ImageReceiver();

        @Override
        public void draw(android.graphics.Canvas canvas) {
            android.graphics.Rect b = getBounds();
            receiver.setImageCoords(b.left, b.top, b.width(), b.height());
            receiver.draw(canvas);
        }

        @Override
        public void setAlpha(int alpha) {
            receiver.setAlpha(alpha / 255f);
        }

        @Override
        public void setColorFilter(android.graphics.ColorFilter colorFilter) {
        }

        @Override
        public int getOpacity() {
            return android.graphics.PixelFormat.TRANSLUCENT;
        }
    }
}
