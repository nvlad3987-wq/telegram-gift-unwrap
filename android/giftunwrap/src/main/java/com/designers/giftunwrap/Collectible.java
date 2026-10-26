package com.designers.giftunwrap;

import android.graphics.Bitmap;

/**
 * A collectible (unique) gift as the profile shows it: the model artwork on its own backdrop
 * with the symbol pattern. Any Telegram collectible maps to this from its three attributes
 * ({@code starGiftAttributeModel}, {@code starGiftAttributeBackdrop},
 * {@code starGiftAttributePattern}).
 */
public final class Collectible {
    public final String name;
    public final GiftArt art;
    public final GiftUnwrapContent.Backdrop backdrop;
    /** The symbol (any colour, it is tinted with the backdrop's pattern colour). Null → none. */
    public final Bitmap symbol;

    public Collectible(String name, GiftArt art, GiftUnwrapContent.Backdrop backdrop, Bitmap symbol) {
        this.name = name;
        this.art = art;
        this.backdrop = backdrop;
        this.symbol = symbol;
    }
}
