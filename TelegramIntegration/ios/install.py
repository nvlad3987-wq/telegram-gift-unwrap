#!/usr/bin/env python3
"""Installs the Gift Unwrap screen into a Telegram-iOS checkout.

    python3 install.py /path/to/Telegram-iOS

What it does (safe to run twice):
  1. copies the module to submodules/TelegramUI/Components/Gifts/GiftUnwrapScreen
     (BUILD + Sources/GiftUnwrapScreen.swift + Sources/Kit/*.swift from the demo app),
  2. adds it to the deps of //submodules/TelegramUI,
  3. in ChatController.swift: imports it and, when an incoming collectible gift message
     is opened for the first time, presents GiftUnwrapScreen instead of the gift sheet.
"""
import os
import re
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
KIT = os.path.join(HERE, "..", "..", "ios", "GiftUnwrap", "Kit")
MODULE = "submodules/TelegramUI/Components/Gifts/GiftUnwrapScreen"
DEP = '        "//submodules/TelegramUI/Components/Gifts/GiftUnwrapScreen",\n'
MARK = "// GiftUnwrapScreen: first open of a received collectible"

PATCH = '''                                MARK
                                if case let .starGiftUnique(unwrapGift, _, _, unwrapSaved, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _) = action.action, case let .unique(unwrapUniqueGift) = unwrapGift, message.flags.contains(.Incoming), GiftUnwrapScreen.shouldUnwrap(messageId: message.id) {
                                    self.chatDisplayNode.dismissInput()
                                    let unwrapMessage = message
                                    let unwrapScreen = GiftUnwrapScreen(context: self.context, gift: unwrapUniqueGift, reference: .message(messageId: message.id), savedToProfile: unwrapSaved, parentController: self, openDetails: { [weak self] in
                                        guard let self else {
                                            return
                                        }
                                        let controller = self.context.sharedContext.makeGiftViewScreen(context: self.context, message: EngineMessage(unwrapMessage), shareStory: nil)
                                        self.push(controller)
                                    })
                                    self.present(unwrapScreen, in: .window(.root))
                                    return true
                                }
'''.replace("MARK", MARK)


def die(msg):
    print("error:", msg)
    sys.exit(1)


def main():
    if len(sys.argv) != 2:
        die("usage: install.py /path/to/Telegram-iOS")
    root = os.path.abspath(sys.argv[1])
    chat = os.path.join(root, "submodules/TelegramUI/Sources/ChatController.swift")
    tbuild = os.path.join(root, "submodules/TelegramUI/BUILD")
    if not os.path.exists(chat) or not os.path.exists(tbuild):
        die("not a Telegram-iOS checkout: " + root)

    # 1. module
    dst = os.path.join(root, MODULE)
    if os.path.exists(dst):
        shutil.rmtree(dst)
    os.makedirs(os.path.join(dst, "Sources", "Kit"))
    shutil.copy(os.path.join(HERE, "GiftUnwrapScreen", "BUILD"), dst)
    shutil.copy(os.path.join(HERE, "GiftUnwrapScreen", "Sources", "GiftUnwrapScreen.swift"), os.path.join(dst, "Sources"))
    for name in sorted(os.listdir(KIT)):
        if name.endswith(".swift"):
            shutil.copy(os.path.join(KIT, name), os.path.join(dst, "Sources", "Kit"))
    print("module  ->", MODULE)

    # 2. dependency of TelegramUI
    text = open(tbuild).read()
    if DEP not in text:
        anchor = '        "//submodules/TelegramUI/Components/Gifts/GiftCraftScreen",\n'
        if anchor not in text:
            die("could not find the GiftCraftScreen dependency in TelegramUI/BUILD")
        text = text.replace(anchor, anchor + DEP, 1)
        open(tbuild, "w").write(text)
        print("BUILD   -> added dependency")
    else:
        print("BUILD   -> dependency already there")

    # 3. ChatController
    text = open(chat).read()
    if MARK in text:
        print("Chat    -> already patched")
        return
    if "import GiftUnwrapScreen\n" not in text:
        text = text.replace("import UndoUI\n", "import UndoUI\nimport GiftUnwrapScreen\n", 1)
    case_at = text.find("case .starGift, .starGiftUnique:")
    if case_at < 0:
        die("could not find `case .starGift, .starGiftUnique:` in ChatController.swift")
    m = re.compile(r"\} else \{\n").search(text, case_at)
    if not m or m.start() - case_at > 1500:
        die("could not find the place to insert the unwrap screen")
    text = text[:m.end()] + PATCH + text[m.end():]
    open(chat, "w").write(text)
    print("Chat    -> GiftUnwrapScreen is shown on the first open of a received collectible")


if __name__ == "__main__":
    main()
