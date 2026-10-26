import UIKit

/// Telegram's collectible gift sheet (iOS 26 kit): a header — close and share/more glass
/// buttons, title, "Collectible #N", transfer / wear / sell — over the gift's backdrop (which
/// `GiftUnwrapView` draws, so the reveal can condense into it), and a white body with the
/// attribute table (rarity badges), the caption and the blue button.
final class GUGiftSheetView: UIView {
    static let headerHeight: CGFloat = 313.0
    static let rowHeight: CGFloat = 42.0
    static let buttonColor = UIColor(guRGB: 0x008afe)

    let closeButton = GUGlassButton(kind: .close)
    let moreButton = GUGlassButton(kind: .shareMore)
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private var chips: [GUChipView] = []
    let body = UIView()
    private let table = UIView()
    private let captionLabel = UILabel()
    let primaryButton: GUSheetButton
    private let rowCount: Int

    var onClose: (() -> Void)?

    init(content: GiftUnwrapContent) {
        self.primaryButton = GUSheetButton(title: content.primaryActionTitle)
        self.rowCount = GUGiftSheetView.tableRows(content)
        super.init(frame: .zero)

        self.closeButton.addTarget(self, action: #selector(self.closeTapped), for: .touchUpInside)
        self.addSubview(self.closeButton)
        self.addSubview(self.moreButton)

        self.titleLabel.attributedText = NSAttributedString(string: content.title, attributes: [
            .font: UIFont.systemFont(ofSize: 24.0, weight: .bold), .foregroundColor: UIColor.white, .kern: -0.4,
        ])
        self.titleLabel.textAlignment = .center
        self.addSubview(self.titleLabel)
        let subtitle = content.number.map { "Collectible #" + GiftUnwrapContent.formatNumber($0) } ?? ""
        self.subtitleLabel.attributedText = NSAttributedString(string: subtitle, attributes: [
            .font: UIFont.systemFont(ofSize: 15.0, weight: .regular), .foregroundColor: content.backdrop.text.withAlphaComponent(0.9),
        ])
        self.subtitleLabel.textAlignment = .center
        self.addSubview(self.subtitleLabel)
        for (i, title) in content.chips.enumerated() {
            let chip = GUChipView(icon: i, title: title, tint: content.backdrop.pattern)
            self.chips.append(chip)
            self.addSubview(chip)
        }

        self.body.backgroundColor = .white
        self.body.layer.cornerRadius = 44.0
        self.body.layer.cornerCurve = .continuous
        self.addSubview(self.body)
        self.table.backgroundColor = .white
        self.table.layer.cornerRadius = 12.0
        self.table.layer.borderWidth = 0.66
        self.table.layer.borderColor = UIColor(guRGB: 0xc6c6c8).cgColor
        self.table.clipsToBounds = true
        self.body.addSubview(self.table)
        var rowViews: [UIView] = content.rows.map { GUTableRow(row: $0) }
        if let message = content.message {
            let label = UILabel()
            label.text = message
            label.font = UIFont.systemFont(ofSize: 16.0)
            label.textColor = .black
            let wrap = UIView()
            wrap.addSubview(label)
            label.tag = 1
            rowViews.append(wrap)
        }
        for (i, v) in rowViews.enumerated() {
            v.frame = CGRect(x: 0.0, y: CGFloat(i) * GUGiftSheetView.rowHeight, width: 0.0, height: GUGiftSheetView.rowHeight)
            if i < rowViews.count - 1 {
                let line = UIView()
                line.backgroundColor = UIColor(guRGB: 0xc6c6c8)
                line.tag = 2
                v.addSubview(line)
            }
            self.table.addSubview(v)
        }
        self.captionLabel.text = content.caption
        self.captionLabel.font = UIFont.systemFont(ofSize: 13.0)
        self.captionLabel.textColor = UIColor(guRGB: 0x8e8e93)
        self.captionLabel.textAlignment = .center
        self.body.addSubview(self.captionLabel)
        self.body.addSubview(self.primaryButton)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    static func tableRows(_ content: GiftUnwrapContent) -> Int {
        return content.rows.count + (content.message != nil ? 1 : 0)
    }

    /// Body height for `rows` rows: 16 + rows·42 + caption + button + 31 (kit: 399 for 6 rows).
    static func bodyHeight(rows: Int) -> CGFloat {
        return 16.0 + CGFloat(rows) * rowHeight + 14.0 + 18.0 + 18.0 + 50.0 + 31.0
    }

    var bodyHeight: CGFloat {
        return GUGiftSheetView.bodyHeight(rows: self.rowCount)
    }

    @objc private func closeTapped() {
        self.onClose?()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let w = self.bounds.width
        let headerH = self.bounds.height - self.bodyHeight
        let k = headerH / GUGiftSheetView.headerHeight
        self.closeButton.frame = CGRect(x: 16.0, y: 16.0, width: 42.0, height: 42.0)
        self.moreButton.frame = CGRect(x: w - 16.0 - 86.0, y: 16.0, width: 86.0, height: 42.0)
        self.titleLabel.frame = CGRect(x: 0.0, y: 178.0 * k, width: w, height: 30.0)
        self.subtitleLabel.frame = CGRect(x: 0.0, y: 178.0 * k + 30.0, width: w, height: 20.0)
        let chipW = (w - 32.0 - 20.0) / 3.0
        for (i, chip) in self.chips.enumerated() {
            chip.frame = CGRect(x: 16.0 + CGFloat(i) * (chipW + 10.0), y: 236.0 * k, width: chipW, height: 64.0)
        }
        self.body.frame = CGRect(x: 0.0, y: headerH, width: w, height: self.bodyHeight)
        let tw = w - 32.0
        self.table.frame = CGRect(x: 16.0, y: 16.0, width: tw, height: CGFloat(self.rowCount) * GUGiftSheetView.rowHeight)
        for v in self.table.subviews {
            v.frame.size.width = tw
            for sub in v.subviews where sub.tag == 2 {
                sub.frame = CGRect(x: 0.0, y: GUGiftSheetView.rowHeight - 0.66, width: tw, height: 0.66)
            }
            for sub in v.subviews where sub.tag == 1 {
                sub.frame = CGRect(x: 12.0, y: 0.0, width: tw - 24.0, height: GUGiftSheetView.rowHeight)
            }
        }
        let ty = self.table.frame.maxY
        self.captionLabel.frame = CGRect(x: 0.0, y: ty + 14.0, width: w, height: 18.0)
        self.primaryButton.frame = CGRect(x: 16.0, y: ty + 14.0 + 18.0 + 18.0, width: w - 32.0, height: 50.0)
    }

    /// `t`: seconds since the reveal began condensing into the sheet.
    func setAppear(_ t: CGFloat) {
        var parts: [(UIView, CGFloat)] = [(self.titleLabel, 0.12), (self.subtitleLabel, 0.16)]
        for chip in self.chips {
            parts.append((chip, 0.2))
        }
        parts.append((self.closeButton, 0.26))
        parts.append((self.moreButton, 0.3))
        guWithoutAnimation {
            for (v, d) in parts {
                let e = GUMotion.tg(GUMotion.clamp((t - d) / 0.4))
                v.alpha = GUMotion.easeInOut(GUMotion.clamp((t - d) / 0.25))
                v.transform = CGAffineTransform(translationX: 0.0, y: (1.0 - e) * 14.0).scaledBy(x: 0.96 + 0.04 * e, y: 0.96 + 0.04 * e)
            }
            let bk = GUMotion.spring(t - 0.03, GUMotion.sheet)
            self.body.transform = CGAffineTransform(translationX: 0.0, y: (1.0 - bk) * 430.0)
            self.body.alpha = t > 0.0 ? 1.0 : 0.0
        }
    }
}

/// One table row: grey key column, value with an optional rarity badge.
final class GUTableRow: UIView {
    init(row: GiftUnwrapContent.Row) {
        super.init(frame: .zero)
        let key = UIView()
        key.backgroundColor = UIColor(guRGB: 0xeeeeef)
        key.frame = CGRect(x: 0.0, y: 0.0, width: 98.0, height: GUGiftSheetView.rowHeight)
        self.addSubview(key)
        let sep = UIView()
        sep.backgroundColor = UIColor(guRGB: 0xc6c6c8)
        sep.frame = CGRect(x: 98.0, y: 0.0, width: 0.66, height: GUGiftSheetView.rowHeight)
        self.addSubview(sep)
        let keyLabel = UILabel(frame: CGRect(x: 12.0, y: 0.0, width: 84.0, height: GUGiftSheetView.rowHeight))
        keyLabel.text = row.title
        keyLabel.font = UIFont.systemFont(ofSize: 16.0)
        keyLabel.adjustsFontSizeToFitWidth = true
        keyLabel.minimumScaleFactor = 0.8
        self.addSubview(keyLabel)
        let value = UILabel()
        value.text = row.value
        value.font = UIFont.systemFont(ofSize: 16.0)
        value.textColor = .black
        value.sizeToFit()
        value.frame = CGRect(x: 110.0, y: 0.0, width: min(value.bounds.width, 170.0), height: GUGiftSheetView.rowHeight)
        self.addSubview(value)
        if let badge = row.badge {
            let b = UILabel()
            b.text = badge
            b.font = UIFont.systemFont(ofSize: 13.0, weight: .medium)
            b.textColor = GUGiftSheetView.buttonColor
            b.textAlignment = .center
            b.backgroundColor = UIColor(guRGB: 0xe5f3ff)
            b.layer.cornerRadius = 10.0
            b.clipsToBounds = true
            b.sizeToFit()
            b.frame = CGRect(x: value.frame.maxX + 7.0, y: (GUGiftSheetView.rowHeight - 20.0) / 2.0, width: b.bounds.width + 14.0, height: 20.0)
            self.addSubview(b)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

/// The big blue button: responds on press, commits on release.
final class GUSheetButton: UIControl {
    private let label = UILabel()
    var onTap: (() -> Void)?

    init(title: String) {
        super.init(frame: .zero)
        self.backgroundColor = GUGiftSheetView.buttonColor
        self.layer.cornerRadius = 25.0
        self.layer.cornerCurve = .continuous
        self.label.attributedText = NSAttributedString(string: title, attributes: [
            .font: UIFont.systemFont(ofSize: 17.0, weight: .semibold), .foregroundColor: UIColor.white,
        ])
        self.label.textAlignment = .center
        self.addSubview(self.label)
        self.addTarget(self, action: #selector(self.down), for: [.touchDown, .touchDragEnter])
        self.addTarget(self, action: #selector(self.up), for: [.touchUpOutside, .touchCancel, .touchDragExit])
        self.addTarget(self, action: #selector(self.tap), for: .touchUpInside)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.label.frame = self.bounds
    }

    @objc private func down() {
        UIView.animate(withDuration: 0.09, delay: 0.0, options: [.beginFromCurrentState, .allowUserInteraction]) {
            self.transform = CGAffineTransform(scaleX: 0.97, y: 0.97)
            self.alpha = 0.86
        }
    }

    @objc private func up() {
        UIView.animate(withDuration: 0.45, delay: 0.0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.0, options: [.beginFromCurrentState, .allowUserInteraction]) {
            self.transform = .identity
            self.alpha = 1.0
        }
    }

    @objc private func tap() {
        self.up()
        self.onTap?()
    }
}

/// iOS 26 glass button on the backdrop: white 17 % fill, a hairline light edge, white glyphs.
final class GUGlassButton: UIControl {
    enum Kind {
        case close
        case shareMore
    }

    private let glyphs = CAShapeLayer()
    private let dots = CAShapeLayer()
    private let kind: Kind

    init(kind: Kind) {
        self.kind = kind
        super.init(frame: .zero)
        self.backgroundColor = UIColor.white.withAlphaComponent(0.17)
        self.layer.borderWidth = 0.6
        self.layer.borderColor = UIColor.white.withAlphaComponent(0.35).cgColor
        self.glyphs.strokeColor = UIColor.white.cgColor
        self.glyphs.fillColor = nil
        self.glyphs.lineWidth = 2.2
        self.glyphs.lineCap = .round
        self.glyphs.lineJoin = .round
        self.layer.addSublayer(self.glyphs)
        self.dots.fillColor = UIColor.white.cgColor
        self.layer.addSublayer(self.dots)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let b = self.bounds
        self.layer.cornerRadius = b.height / 2.0
        let p = UIBezierPath()
        let cy = b.midY
        switch self.kind {
        case .close:
            let cx = b.midX
            p.move(to: CGPoint(x: cx - 6.0, y: cy - 6.0))
            p.addLine(to: CGPoint(x: cx + 6.0, y: cy + 6.0))
            p.move(to: CGPoint(x: cx + 6.0, y: cy - 6.0))
            p.addLine(to: CGPoint(x: cx - 6.0, y: cy + 6.0))
            self.dots.path = nil
        case .shareMore:
            let cx: CGFloat = 23.0
            p.move(to: CGPoint(x: cx, y: cy - 9.5))
            p.addLine(to: CGPoint(x: cx, y: cy + 3.5))
            p.move(to: CGPoint(x: cx - 4.8, y: cy - 5.2))
            p.addLine(to: CGPoint(x: cx, y: cy - 10.0))
            p.addLine(to: CGPoint(x: cx + 4.8, y: cy - 5.2))
            p.move(to: CGPoint(x: cx - 4.0, y: cy - 1.5))
            p.addLine(to: CGPoint(x: cx - 6.5, y: cy - 1.5))
            p.addLine(to: CGPoint(x: cx - 6.5, y: cy + 10.0))
            p.addLine(to: CGPoint(x: cx + 6.5, y: cy + 10.0))
            p.addLine(to: CGPoint(x: cx + 6.5, y: cy - 1.5))
            p.addLine(to: CGPoint(x: cx + 4.0, y: cy - 1.5))
            let d = UIBezierPath()
            for i in -1 ... 1 {
                let x = b.width - 26.0 + CGFloat(i) * 7.5
                d.append(UIBezierPath(ovalIn: CGRect(x: x - 2.2, y: cy - 2.2, width: 4.4, height: 4.4)))
            }
            self.dots.path = d.cgPath
        }
        self.glyphs.path = p.cgPath
    }
}

/// transfer / wear / sell: a glass tile tinted with the backdrop's pattern colour.
final class GUChipView: UIView {
    init(icon: Int, title: String, tint: UIColor) {
        super.init(frame: .zero)
        self.backgroundColor = tint.withAlphaComponent(0.36)
        self.layer.cornerRadius = 14.0
        self.layer.cornerCurve = .continuous
        self.layer.borderWidth = 0.66
        self.layer.borderColor = UIColor.white.withAlphaComponent(0.18).cgColor
        let symbols = ["gift.fill", "crown.fill", "tag.fill"]
        let image = UIImageView(image: UIImage(systemName: symbols[min(icon, symbols.count - 1)], withConfiguration: UIImage.SymbolConfiguration(pointSize: 19.0, weight: .semibold)))
        image.tintColor = .white
        image.contentMode = .center
        image.tag = 1
        self.addSubview(image)
        let label = UILabel()
        label.text = title
        label.font = UIFont.systemFont(ofSize: 13.0)
        label.textColor = .white
        label.textAlignment = .center
        label.tag = 2
        self.addSubview(label)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let b = self.bounds
        self.viewWithTag(1)?.frame = CGRect(x: 0.0, y: 8.0, width: b.width, height: 26.0)
        self.viewWithTag(2)?.frame = CGRect(x: 0.0, y: b.height - 26.0, width: b.width, height: 18.0)
    }
}
