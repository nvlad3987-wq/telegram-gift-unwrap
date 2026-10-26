import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramCore
import AccountContext
import TelegramPresentationData
import UndoUI
import EmojiTextAttachmentView
import TextFormat

/// Full-screen overlay that plays the unwrap for a received collectible gift.
///
/// Presented from `ChatController` when an incoming `starGiftUnique` message is tapped for the
/// first time (see `INTEGRATION.md`). Works for any collectible: everything comes from the
/// gift's own attributes. Everything visual lives in `GiftUnwrapView` (the same
/// code as the demo app); this file only connects it to Telegram:
/// - model and symbol are Telegram's own animated stickers (`InlineStickerItemLayer`),
/// - backdrop colours, names and rarities come from the gift's attributes,
/// - "Show on Profile" calls `updateStarGiftAddedToProfile` and shows Telegram's own toast,
/// - the close button keeps the gift private (the regular `GiftViewScreen` stays one tap away).
public final class GiftUnwrapScreen: ViewController {
    private let context: AccountContext
    private let gift: StarGift.UniqueGift
    private let reference: StarGiftReference
    private let savedToProfile: Bool
    private let openDetails: () -> Void
    private weak var parentController: ViewController?
    private var unwrapView: GiftUnwrapView?
    private var didStart = false
    /// Centre of the gift's sticker in the tapped message, in window coordinates (optional).
    public var sourcePoint: CGPoint?

    /// - Parameters:
    ///   - reference: `.message(messageId:)` of the gift message.
    ///   - openDetails: opens the regular gift sheet (kept for hosts that want it after closing).
    public init(context: AccountContext, gift: StarGift.UniqueGift, reference: StarGiftReference, savedToProfile: Bool, parentController: ViewController?, openDetails: @escaping () -> Void) {
        self.context = context
        self.parentController = parentController
        self.gift = gift
        self.reference = reference
        self.savedToProfile = savedToProfile
        self.openDetails = openDetails
        super.init(navigationBarPresentationData: nil)
        self.statusBar.statusBarStyle = .White
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - First open

    private static func key(_ messageId: EngineMessage.Id) -> String {
        return "GiftUnwrapScreen.opened.\(messageId.peerId.toInt64()).\(messageId.namespace).\(messageId.id)"
    }

    /// True until the gift message has been unwrapped once on this device.
    public static func shouldUnwrap(messageId: EngineMessage.Id) -> Bool {
        return !UserDefaults.standard.bool(forKey: GiftUnwrapScreen.key(messageId))
    }

    public static func markUnwrapped(messageId: EngineMessage.Id) {
        UserDefaults.standard.set(true, forKey: GiftUnwrapScreen.key(messageId))
    }

    // MARK: - View

    override public func loadDisplayNode() {
        self.displayNode = ASDisplayNode()
        self.displayNode.backgroundColor = .clear
        self.displayNodeDidLoad()
    }

    override public func displayNodeDidLoad() {
        super.displayNodeDidLoad()
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        let content = GiftUnwrapTelegram.content(context: self.context, gift: self.gift, savedToProfile: self.savedToProfile, strings: presentationData.strings)
        let view = GiftUnwrapView(content: content)
        view.onPrimaryAction = { [weak self] in
            self?.showOnProfile()
        }
        view.onSecondaryAction = { [weak self] in
            // Close = keep it private; the regular gift sheet stays one tap away on the message.
            self?.unwrapView?.playExit(flyingTo: nil, completion: { [weak self] in
                self?.dismiss()
            })
        }
        view.onSnap = { [weak self] in
            if let self, case let .message(messageId) = self.reference {
                GiftUnwrapScreen.markUnwrapped(messageId: messageId)
            }
        }
        self.displayNode.view.addSubview(view)
        self.unwrapView = view
    }

    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        guard let view = self.unwrapView else {
            return
        }
        view.frame = CGRect(origin: CGPoint(), size: layout.size)
        view.safeInsets = UIEdgeInsets(top: layout.statusBarHeight ?? 20.0, left: 0.0, bottom: layout.intrinsicInsets.bottom, right: 0.0)
        // The wrapped gift comes forward from the gift message that was tapped (its sticker
        // slot when the chat passes it, else the lower part of the screen) to 45 % down.
        view.sphereCenter = CGPoint(x: layout.size.width / 2.0, y: layout.size.height * 0.45)
        if !self.didStart {
            self.didStart = true
            let slot = self.sourcePoint ?? CGPoint(x: layout.size.width / 2.0, y: layout.size.height * 0.7)
            view.start(from: slot, scale: 40.0 / GiftUnwrapView.sphereRadius)
        }
    }

    override public func dismiss(completion: (() -> Void)? = nil) {
        self.unwrapView?.stop()
        super.dismiss(completion: completion)
    }

    // MARK: - Actions

    private func showOnProfile() {
        let context = self.context
        if self.savedToProfile {
            // Already on the profile: the button is just "OK".
            self.unwrapView?.playExit(flyingTo: nil, completion: { [weak self] in
                self?.dismiss()
            })
            return
        }
        let added = true
        let _ = (context.engine.payments.updateStarGiftAddedToProfile(reference: self.reference, added: added)
        |> deliverOnMainQueue).startStandalone()

        var modelFile: TelegramMediaFile?
        for attribute in self.gift.attributes {
            if case let .model(_, file, _, _) = attribute {
                modelFile = file
            }
        }
        let parentController = self.parentController
        let navigationController = parentController?.navigationController as? NavigationController
        let target = CGPoint(x: (self.unwrapView?.bounds.width ?? 0.0) / 2.0, y: -40.0)
        self.unwrapView?.playExit(flyingTo: target, completion: { [weak self] in
            guard let self else {
                return
            }
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            if let file = modelFile, let parent = parentController {
                let toast = UndoOverlayController(
                    presentationData: presentationData,
                    content: .sticker(
                        context: context,
                        file: file,
                        loop: false,
                        title: nil,
                        text: added ? presentationData.strings.Gift_Displayed_NewText : presentationData.strings.Gift_Hidden_NewText,
                        undoText: presentationData.strings.Gift_Displayed_View,
                        customAction: nil
                    ),
                    elevatedLayout: false,
                    action: { [weak navigationController] action in
                        if case .undo = action, let navigationController {
                            let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
                            |> deliverOnMainQueue).start(next: { [weak navigationController] peer in
                                guard let peer, let navigationController else {
                                    return
                                }
                                if let controller = context.sharedContext.makePeerInfoController(context: context, updatedPresentationData: nil, peer: peer, mode: .myProfileGifts, avatarInitiallyExpanded: false, fromChat: false, requestsContext: nil) {
                                    navigationController.pushViewController(controller)
                                }
                            })
                        }
                        return true
                    }
                )
                parent.present(toast, in: .current)
            }
            self.dismiss()
        })
    }
}

/// Builds `GiftUnwrapContent` from a Telegram collectible.
enum GiftUnwrapTelegram {
    static func content(context: AccountContext, gift: StarGift.UniqueGift, savedToProfile: Bool, strings: PresentationStrings) -> GiftUnwrapContent {
        var modelName = ""
        var modelFile: TelegramMediaFile?
        var modelRarity: String?
        var patternName = ""
        var patternFile: TelegramMediaFile?
        var patternRarity: String?
        var backdropName = ""
        var backdropRarity: String?
        var backdrop = GiftUnwrapContent.Backdrop.cobaltBlue

        func rarityText(_ rarity: StarGift.UniqueGift.Attribute.Rarity) -> String? {
            switch rarity {
            case let .permille(value):
                return GiftUnwrapContent.formatRarity(permille: Int(value))
            case .rare:
                return "Rare"
            case .epic:
                return "Epic"
            case .legendary:
                return "Legendary"
            case .uncommon:
                return "Uncommon"
            }
        }

        for attribute in gift.attributes {
            switch attribute {
            case let .model(name, file, rarity, _):
                modelName = name
                modelFile = file
                modelRarity = rarityText(rarity)
            case let .pattern(name, file, rarity):
                patternName = name
                patternFile = file
                patternRarity = rarityText(rarity)
            case let .backdrop(name, _, innerColor, outerColor, patternColor, textColor, rarity):
                backdropName = name
                backdropRarity = rarityText(rarity)
                backdrop = GiftUnwrapContent.Backdrop(
                    inner: UIColor(rgb: UInt32(bitPattern: innerColor)),
                    outer: UIColor(rgb: UInt32(bitPattern: outerColor)),
                    pattern: UIColor(rgb: UInt32(bitPattern: patternColor)),
                    text: UIColor(rgb: UInt32(bitPattern: textColor))
                )
            default:
                break
            }
        }

        var ownerName = ""
        if let owner = gift.owner {
            switch owner {
            case let .name(name):
                ownerName = name
            default:
                ownerName = strings.Gift_Unique_Owner
            }
        }
        let issued = GiftUnwrapContent.formatNumber(Int(gift.availability.issued))
        let total = GiftUnwrapContent.formatNumber(Int(gift.availability.total))

        // Telegram's table order: Model, Symbol, Backdrop (with rarity), Availability.
        var rows: [GiftUnwrapContent.Row] = []
        rows.append(.init(title: strings.Gift_Unique_Model, value: modelName, badge: modelRarity))
        rows.append(.init(title: strings.Gift_Unique_Symbol, value: patternName, badge: patternRarity))
        rows.append(.init(title: strings.Gift_Unique_Backdrop, value: backdropName, badge: backdropRarity))
        rows.append(.init(title: strings.Gift_Unique_Availability, value: strings.Gift_Unique_Issued("\(issued)/\(total)").string))
        let _ = ownerName

        var content = GiftUnwrapContent(
            title: gift.title,
            number: Int(gift.number),
            giftImage: nil,
            symbolImage: nil,
            backdrop: backdrop,
            rows: rows,
            primaryActionTitle: savedToProfile ? strings.Common_OK : strings.Gift_View_Display
        )
        content.caption = savedToProfile ? "" : strings.Gift_View_HiddenInfo
        if let file = modelFile {
            content.makeGiftView = {
                return GiftUnwrapStickerView(context: context, file: file, dynamicColor: nil)
            }
        }
        if let file = patternFile {
            let color = backdrop.pattern
            content.makeSymbolLayer = {
                return GiftUnwrapTelegram.stickerLayer(context: context, file: file, size: CGSize(width: 32.0, height: 32.0), dynamicColor: color)
            }
        }
        return content
    }

    static func stickerLayer(context: AccountContext, file: TelegramMediaFile, size: CGSize, dynamicColor: UIColor?) -> InlineStickerItemLayer {
        let emoji = ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: file.fileId.id, file: file)
        let layer = InlineStickerItemLayer(
            context: context,
            userLocation: .other,
            attemptSynchronousLoad: false,
            emoji: emoji,
            file: file,
            cache: context.animationCache,
            renderer: context.animationRenderer,
            unique: dynamicColor == nil,
            placeholderColor: .clear,
            pointSize: size,
            dynamicColor: dynamicColor,
            loopCount: dynamicColor == nil ? 1 : 0
        )
        layer.isVisibleForAnimations = true
        return layer
    }
}

/// Telegram's animated gift model as a plain UIView that fills its bounds.
final class GiftUnwrapStickerView: UIView {
    private let stickerLayer: InlineStickerItemLayer

    init(context: AccountContext, file: TelegramMediaFile, dynamicColor: UIColor?) {
        self.stickerLayer = GiftUnwrapTelegram.stickerLayer(context: context, file: file, size: CGSize(width: 240.0, height: 240.0), dynamicColor: dynamicColor)
        super.init(frame: CGRect())
        self.layer.addSublayer(self.stickerLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.stickerLayer.frame = self.bounds
        CATransaction.commit()
    }
}
