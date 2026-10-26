load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "GiftUnwrapScreen",
    module_name = "GiftUnwrapScreen",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//submodules/AsyncDisplayKit",
        "//submodules/Display",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/TelegramCore",
        "//submodules/AccountContext",
        "//submodules/TelegramPresentationData",
        "//submodules/UndoUI",
        "//submodules/TextFormat",
        "//submodules/TelegramUI/Components/EmojiTextAttachmentView",
    ],
    visibility = [
        "//visibility:public",
    ],
)
