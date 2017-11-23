//
//  LXMarqueeLabel.swift
//  LXMarqueeLabel
//
//  Created by 冠霖环如 on 2017/11/16.
//  Copyright © 2017年 冠霖环如. All rights reserved.
//

import UIKit

class LXMarqueeLabel: UIView {

    enum State {
        case scrolling, paused, stopped
    }

    var isPaused: Bool { return state == .paused }
    var isStopped: Bool { return state == .stopped }
    var isScrolling: Bool { return state == .scrolling }
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

    /// 文本颜色，默认 black，只能在 stopped 状态下设置
    @IBInspectable var textColor: UIColor = .black {
        willSet {
            precondition(state == .stopped)
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

    /// 只能在 stopped 状态下设置
    override var backgroundColor: UIColor? {
        didSet {
            precondition(state == .stopped)
            offscreenTextLabels.forEach { $0.backgroundColor = backgroundColor }
        }
    }

    /// 文本列表
    var textList: [String] = [] {
        willSet {
            stopScrolling()
            nextIndex = newValue.isEmpty ? -1 : 0
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

    private var displayLink: CADisplayLink!
}

// MARK: - 开始|停止滚动
extension LXMarqueeLabel {

    /// 开始滚动
    func startScrolling() {
        if state == .scrolling { return }
        if textList.isEmpty { return }
        if window == nil { return }
        if state == .stopped {
            addNextTextLabel()
        }
        resumeDisplayLink()
        state = .scrolling
    }

    /// 暂停滚动
    func pauseScrolling() {
        if state != .scrolling { return }
        pauseDisplayLink()
        state = .paused
    }

    /// 停止滚动
    func stopScrolling() {
        if state == .stopped { return }
        nextIndex = 0
        pauseDisplayLink()
        onscreenTextLabels.forEach { $0.removeFromSuperview() }
        onscreenTextLabels.removeAll(keepingCapacity: true)
        state = .stopped
    }
}

// MARK: - 循环利用
private extension LXMarqueeLabel {
    
    func dequeueReusableTextLabel() -> TextLabel {
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

    func recycle(_ textLabel: TextLabel) {
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
        textLabel.center.y = bounds.midY
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

    func initDisplayLink() {
        precondition(displayLink == nil)
        displayLink = CADisplayLink(target: self, selector: #selector(step))
        displayLink.isPaused = (state != .scrolling)
        displayLink.add(to: RunLoop.main, forMode: .commonModes)
    }

    func invalidateDisplayLink() {
        displayLink.invalidate()
        displayLink = nil
    }

    func resumeDisplayLink() {
        displayLink.isPaused = false
    }

    func pauseDisplayLink() {
        displayLink.isPaused = true
    }

    @objc func step(_ displayLink: CADisplayLink) {
        bounds.origin.x += textScrollSpeed * CGFloat(displayLink.duration)
        if let firstLabelMaxX = onscreenTextLabels.first?.frame.maxX, firstLabelMaxX <= bounds.minX {
            onscreenTextLabels.removeFirst().removeFromSuperview()
        }
        if let lastLabelMaxX = onscreenTextLabels.last?.frame.maxX, bounds.maxX - lastLabelMaxX >= textSpacing {
            addNextTextLabel()
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
            invalidateDisplayLink()
        } else {
            initDisplayLink()
        }
    }
}

private class TextLabel: UILabel {}
