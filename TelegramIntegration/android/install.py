#!/usr/bin/env python3
"""Installs the Gift Unwrap overlay into a Telegram-Android (DrKLO/Telegram) checkout.

    python install.py C:\\path\\to\\Telegram

Safe to run twice. It:
  1. copies the shared library (android/giftunwrap/.../com/designers/giftunwrap/*.java)
     into TMessagesProj/src/main/java/com/designers/giftunwrap/,
  2. copies GiftUnwrapOverlay.java into org/telegram/ui/Gifts/,
  3. patches ChatActionCell.java: the first time an incoming collectible gift message is
     opened, the unwrap plays instead of StarGiftSheet (the sheet stays one tap away).
"""
import os
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
LIB = os.path.join(HERE, "..", "..", "android", "giftunwrap", "src", "main", "java", "com", "designers", "giftunwrap")
JAVA = os.path.join("TMessagesProj", "src", "main", "java")
MARK = "// GiftUnwrapOverlay: first open of a received collectible"

ANCHOR = """            new StarGiftSheet(getContext(), currentAccount, currentMessageObject.getDialogId(), themeDelegate)
                .set(currentMessageObject)
                .show();
        } else if (currentMessageObject.messageOwner.action instanceof TLRPC.TL_messageActionSetChatTheme) {"""

PATCH = """            MARK
            if (!currentMessageObject.isOutOwner() && action.gift instanceof TL_stars.TL_starGiftUnique && org.telegram.ui.Gifts.GiftUnwrapOverlay.shouldUnwrap(currentAccount, currentMessageObject)) {
                final MessageObject unwrapMessage = currentMessageObject;
                final int unwrapAccount = currentAccount;
                final Context unwrapContext = getContext();
                final int[] unwrapAt = new int[2];
                getLocationInWindow(unwrapAt);
                org.telegram.ui.Gifts.GiftUnwrapOverlay.show(unwrapContext, unwrapAccount, unwrapMessage, (TL_stars.TL_starGiftUnique) action.gift, action.saved,
                    unwrapAt[0] + getWidth() / 2f, unwrapAt[1] + getHeight() * 0.36f, () ->
                    new StarGiftSheet(unwrapContext, unwrapAccount, unwrapMessage.getDialogId(), themeDelegate)
                        .set(unwrapMessage)
                        .show());
                return;
            }
""".replace("MARK", MARK)


def die(msg):
    print("error:", msg)
    sys.exit(1)


def main():
    if len(sys.argv) != 2:
        die("usage: install.py /path/to/Telegram")
    root = os.path.abspath(sys.argv[1])
    cell = os.path.join(root, JAVA, "org", "telegram", "ui", "Cells", "ChatActionCell.java")
    if not os.path.exists(cell):
        die("not a Telegram-Android checkout: " + root)

    dst = os.path.join(root, JAVA, "com", "designers", "giftunwrap")
    os.makedirs(dst, exist_ok=True)
    for name in sorted(os.listdir(LIB)):
        if name.endswith(".java"):
            shutil.copy(os.path.join(LIB, name), dst)
    print("library -> com/designers/giftunwrap")
    shutil.copy(os.path.join(HERE, "GiftUnwrapOverlay.java"), os.path.join(root, JAVA, "org", "telegram", "ui", "Gifts"))
    print("overlay -> org/telegram/ui/Gifts/GiftUnwrapOverlay.java")

    text = open(cell, encoding="utf-8").read()
    if MARK in text:
        print("cell    -> already patched")
        return
    at = text.find(ANCHOR)
    if at < 0:
        die("could not find the StarGiftSheet call for TL_messageActionStarGiftUnique in ChatActionCell.java")
    # insert right before the `new StarGiftSheet(...)` of the unique-gift branch
    text = text[:at] + PATCH + text[at:]
    open(cell, "w", encoding="utf-8").write(text)
    print("cell    -> GiftUnwrapOverlay plays on the first open of a received collectible")


if __name__ == "__main__":
    main()
