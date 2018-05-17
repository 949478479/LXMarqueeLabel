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

    /// 文本间距，只能在 stopped 状态下设置
    @IBInspectable var textSpacing: CGFloat = 50 {
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
        willSet {
            offscreenTextLabels.forEach { $0.textColor = newValue }
        }
    }

    /// 文本字体，默认 15 system font，只能在 stopped 状态下设置
    var font: UIFont = .systemFont(ofSize: 15) {
        willSet {
            precondition(state == .stopped)
            offscreenTextLabels.forEach { $0.font = newValue }
        }
    }

    /// 文本列表
    var textList: [String] = [] {
        willSet {
            stop()
            nextIndex = newValue.isEmpty ? -1 : 0
        }
    }

    override var backgroundColor: UIColor? {
        didSet {
            offscreenTextLabels.forEach { $0.backgroundColor = backgroundColor }
        }
    }

    private var nextIndex: Int = -1 {
        didSet {
            if nextIndex > textList.count - 1 {
                nextIndex = 0
            }
        }
    }

    private var onscreenTextLabels: [TextLabel] = []
    private var offscreenTextLabels: [TextLabel] = []

    private var displayLink: CADisplayLink?

    deinit {
        invalidateDisplayLink()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        clipsToBounds = true
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        onscreenTextLabels.forEach { $0.center.y = frame.height * 0.5 }
    }
}

private extension LXMarqueeLabel {
    class TextLabel: UILabel {}
}

// MARK: - 滚动控制
extension LXMarqueeLabel {

    /// 开始滚动
    func run() {
        guard !isRunning else { return }
        guard !textList.isEmpty else { return }

        if state == .stopped {
            addNextTextLabel()
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
        nextIndex = 0
        pauseDisplayLink()
        onscreenTextLabels.forEach { $0.removeFromSuperview() }
        onscreenTextLabels.removeAll(keepingCapacity: true)
        state = .stopped
    }
}

// MARK: - 循环利用
extension LXMarqueeLabel {
    
    private func dequeueReusableTextLabel() -> TextLabel {
        if let textLabel = offscreenTextLabels.popLast() {
            return textLabel
        }
        let textLabel = TextLabel()
        textLabel.font = font
        textLabel.clipsToBounds = true
        textLabel.textColor = textColor
        textLabel.backgroundColor = backgroundColor
        return textLabel
    }

    private func recycle(_ textLabel: TextLabel) {
        offscreenTextLabels.append(textLabel)
    }
}

// MARK: - 添加标签
private extension LXMarqueeLabel {

    func addNextTextLabel() {
        let currentIndex = nextIndex
        nextIndex += 1

        let textLabel = dequeueReusableTextLabel()
        textLabel.text = textList[currentIndex]
        textLabel.sizeToFit()
        textLabel.center.y = frame.height * 0.5
        if let lastLabelFrame = onscreenTextLabels.last?.frame {
            textLabel.frame.origin.x = lastLabelFrame.maxX + textSpacing
        } else {
            textLabel.frame.origin.x = bounds.maxX
        }

        addSubview(textLabel)
        onscreenTextLabels.append(textLabel)
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
            displayLink.add(to: .main, forMode: .commonModes)
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
            marqueeLabel.bounds.origin.x += marqueeLabel.textScrollSpeed * CGFloat(displayLink.duration)
            if let firstLabelMaxX = marqueeLabel.onscreenTextLabels.first?.frame.maxX, firstLabelMaxX <= marqueeLabel.bounds.minX {
                marqueeLabel.onscreenTextLabels.removeFirst().removeFromSuperview()
            }
            if let lastLabelMaxX = marqueeLabel.onscreenTextLabels.last?.frame.maxX, marqueeLabel.bounds.maxX - lastLabelMaxX >= marqueeLabel.textSpacing {
                marqueeLabel.addNextTextLabel()
            }
        }
    }
}

// MARK: - 视图关系变更
extension LXMarqueeLabel {

    override func willRemoveSubview(_ subview: UIView) {
        if let textLabel = subview as? TextLabel {
            recycle(textLabel)
        }
    }

	override func willMove(toWindow newWindow: UIWindow?) {
		if newWindow == nil {
			pauseDisplayLink()
		} else if isRunning {
			resumeDisplayLink()
		}
	}
}
