//
//  LXMarqueeLabel.swift
//  LXMarqueeLabel
//
//  Created by 从今以后 on 2017/11/16.
//  Copyright © 2017年 从今以后. All rights reserved.
//

import UIKit

class LXMarqueeLabel: UIView {

    enum State {
        case running, paused, stopped
    }

    var isPaused: Bool { return state == .paused }
    var isRunning: Bool { return state == .running }
    var isStopped: Bool { return state == .stopped }

    private(set) var state: State = .stopped

    /// 文本间距，默认 40，只能在 stopped 状态下设置
    @IBInspectable var textSpacing: CGFloat = 40 {
        willSet {
            precondition(state == .stopped)
        }
    }

    /// 文本滚动速度，默认 50 pt/s，只能在 stopped 状态下设置
    @IBInspectable var textScrollSpeed: CGFloat = 50 {
        willSet {
            precondition(state == .stopped)
        }
    }

    /// 文本颜色，默认 black
    @IBInspectable var textColor: UIColor = .black {
        didSet {
            adjustTextLabelColor()
        }
    }

    /// 文本字体，默认 15 system font，只能在 stopped 状态下设置
    var textFont = UIFont.systemFont(ofSize: 15) {
        didSet {
            precondition(state == .stopped)
            adjustTextLabelFont()
        }
    }

    /// 文本列表
    var textList = [String]() {
        willSet { stop() }
        didSet { resetIndex() }
    }

    /// 渐变遮罩的宽度，默认为 20
    @IBInspectable var fadeWidth: CGFloat = 20 {
        didSet {
            layoutGradientMasks()
            setGradientMaskHidden(!(isGradientMaskColorVisible() && fadeWidth > 0))
        }
    }

    override var backgroundColor: UIColor? {
        didSet {
            adjustGradientMaskColor()
            adjustContentBackgroundColor()
        }
    }

    private var nextIndex = NSNotFound
    private var displayLink: CADisplayLink?

    private let textLabelContainerView = UIView()
    private var onscreenTextLabels = [TextLabel]()
    private var offscreenTextLabels = [TextLabel]()

    private let leftGradientMask = CAGradientLayer()
    private let rightGradientMask = CAGradientLayer()

    deinit {
        invalidateDisplayLink()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
}

// MARK: - 滚动控制
extension LXMarqueeLabel {

    /// 开始滚动
    func run() {
        guard !isRunning else { return }
        guard !textList.isEmpty else { return }

        if state == .stopped {
            addOnscreenTextLabel()
        }

        if window != nil {
            resumeDisplayLink()
        }

        state = .running
    }

    /// 暂停滚动
    func pause() {
        guard isRunning else { return }
        pauseDisplayLink()
        state = .paused
    }

    /// 停止滚动
    func stop() {
        guard !isStopped else { return }
        resetIndex()
        pauseDisplayLink()
        clearOnscreenTextLabels()
        resetContainerViewBounds()
        state = .stopped
    }
}

// MARK: - LXMarqueeLabel.TextLabel
private extension LXMarqueeLabel {
    class TextLabel: UILabel {}
}

// MARK: - 初始化
private extension LXMarqueeLabel {

    func commonInit() {
        textLabelContainerView.clipsToBounds = true
        addSubview(textLabelContainerView)

        leftGradientMask.startPoint = CGPoint(x: 0, y: 0.5)
        leftGradientMask.endPoint = CGPoint(x: 1, y: 0.5)
        layer.addSublayer(leftGradientMask)

        rightGradientMask.startPoint = CGPoint(x: 0, y: 0.5)
        rightGradientMask.endPoint = CGPoint(x: 1, y: 0.5)
        layer.addSublayer(rightGradientMask)

        adjustGradientMaskColor()
    }
}

// MARK: - 布局
extension LXMarqueeLabel {

    override var bounds: CGRect {
        didSet {
            guard bounds != oldValue else { return }
            layoutSubviews2()
        }
    }

    override var frame: CGRect {
        didSet {
            guard frame != oldValue else { return }
            layoutSubviews2()
        }
    }

    private func layoutSubviews2() {
        layoutContainerView()
        layoutGradientMasks()
        layoutOnscreenTextLabels()
    }

    private func layoutContainerView() {
        textLabelContainerView.frame = bounds
    }

    private func layoutGradientMasks() {
        leftGradientMask.frame = CGRect(x: 0, y: 0, width: fadeWidth, height: bounds.height)
        rightGradientMask.frame = CGRect(x: bounds.maxX - fadeWidth, y: 0, width: fadeWidth, height: bounds.height)
    }

    private func layoutOnscreenTextLabels() {
        onscreenTextLabels.forEach { $0.center.y = bounds.midY }
    }

    private func resetContainerViewBounds() {
        textLabelContainerView.bounds.origin = .zero
    }
}

// MARK: - 字体
private extension LXMarqueeLabel {

    func adjustTextLabelFont() {
        onscreenTextLabels.forEach { $0.font = textFont }
        offscreenTextLabels.forEach { $0.font = textFont }
    }
}

// MARK: - 颜色
private extension LXMarqueeLabel {

    func adjustGradientMaskColor() {
        guard let startColor = backgroundColor?.cgColor, startColor.alpha > 0 else {
            setGradientMaskHidden(true)
            return
        }

        let endColor = startColor.copy(alpha: 0)!

        leftGradientMask.isHidden = fadeWidth <= 0
        leftGradientMask.colors = [startColor, endColor]

        rightGradientMask.isHidden = fadeWidth <= 0
        rightGradientMask.colors = [endColor, startColor]
    }

    func adjustTextLabelColor() {
        onscreenTextLabels.forEach { $0.textColor = textColor }
        offscreenTextLabels.forEach { $0.textColor = textColor }
    }

    func adjustContentBackgroundColor() {
        textLabelContainerView.backgroundColor = backgroundColor

        let clipsToBounds: Bool = {
            if let color = backgroundColor?.cgColor, color.alpha > 0 {
                return true
            }
            return false
        }()

        onscreenTextLabels.forEach {
            $0.clipsToBounds = clipsToBounds
            $0.backgroundColor = backgroundColor
        }

        offscreenTextLabels.forEach {
            $0.clipsToBounds = clipsToBounds
            $0.backgroundColor = backgroundColor
        }
    }

    func isGradientMaskColorVisible() -> Bool {
        if let color = backgroundColor?.cgColor, color.alpha > 0 {
            return true
        }
        return false
    }
}

// MARK: - 渐变遮罩
private extension LXMarqueeLabel {

    func setGradientMaskHidden(_ hidden: Bool) {
        leftGradientMask.isHidden = hidden
        rightGradientMask.isHidden = hidden
    }
}

// MARK: - 更新索引
private extension LXMarqueeLabel {

    func increaseIndex() {
        nextIndex = (nextIndex + 1) % textList.count
    }

    func resetIndex() {
        nextIndex = textList.isEmpty ? NSNotFound : 0
    }
}

// MARK: - 循环利用
private extension LXMarqueeLabel {
    
    func dequeueReusableTextLabel() -> TextLabel {
        if let textLabel = offscreenTextLabels.popLast() {
            return textLabel
        }

        let textLabel = TextLabel()
        textLabel.font = textFont
        textLabel.textColor = textColor
        textLabel.backgroundColor = backgroundColor

        if let color = backgroundColor?.cgColor, color.alpha > 0 {
            textLabel.clipsToBounds = true
        } else {
            textLabel.clipsToBounds = false
        }

        return textLabel
    }

    func recycle(_ textLabel: TextLabel) {
        offscreenTextLabels.append(textLabel)
    }
}

// MARK: - 添加移除标签
private extension LXMarqueeLabel {

    func addOnscreenTextLabel() {
        let currentIndex = nextIndex
        increaseIndex()

        let textLabel = dequeueReusableTextLabel()
        textLabel.text = textList[currentIndex]
        textLabel.sizeToFit()
        textLabel.center.y = frame.height * 0.5
        if let lastLabelFrame = onscreenTextLabels.last?.frame {
            textLabel.frame.origin.x = lastLabelFrame.maxX + textSpacing
        } else {
            textLabel.frame.origin.x = textLabelContainerView.bounds.maxX
        }

        onscreenTextLabels.append(textLabel)
        textLabelContainerView.addSubview(textLabel)
    }

    func clearOnscreenTextLabels() {
        onscreenTextLabels.forEach {
            $0.removeFromSuperview()
            recycle($0)
        }
        onscreenTextLabels.removeAll(keepingCapacity: true)
    }

    func removeOffscreenTextLabel() {
        let textLabel = onscreenTextLabels.removeFirst()
        textLabel.removeFromSuperview()
        recycle(textLabel)
    }
}

// MARK: - 定时器
private extension LXMarqueeLabel {
    
    func invalidateDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    func resumeDisplayLink() {
        if displayLink == nil {
            let target = DisplayLinkTarget(owner: self)
            let displayLink = CADisplayLink(target: target, selector: #selector(DisplayLinkTarget.step))
            displayLink.add(to: .main, forMode: .common)
            self.displayLink = displayLink
        }
        displayLink?.isPaused = false
    }

    func pauseDisplayLink() {
        displayLink?.isPaused = true
    }

    class DisplayLinkTarget {

        weak var owner: LXMarqueeLabel?

        init(owner: LXMarqueeLabel) {
            self.owner = owner
        }

        @objc func step(_ displayLink: CADisplayLink) {
            guard let marqueeLabel = owner else { return }

            let originXOffset = marqueeLabel.textScrollSpeed * CGFloat(displayLink.duration)
            marqueeLabel.textLabelContainerView.bounds.origin.x += originXOffset

            if let firstLabel = marqueeLabel.onscreenTextLabels.first,
                firstLabel.frame.maxX <= marqueeLabel.textLabelContainerView.bounds.minX
            {
                marqueeLabel.removeOffscreenTextLabel()
            }

            if let lastLabelMaxX = marqueeLabel.onscreenTextLabels.last?.frame.maxX,
                marqueeLabel.textLabelContainerView.bounds.maxX - lastLabelMaxX >= marqueeLabel.textSpacing
            {
                marqueeLabel.addOnscreenTextLabel()
            }
        }
    }
}

// MARK: - 视图关系变更
extension LXMarqueeLabel {

	override func willMove(toWindow newWindow: UIWindow?) {
		if newWindow == nil {
			pauseDisplayLink()
		} else if isRunning {
			resumeDisplayLink()
		}
	}
}
