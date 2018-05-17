//
//  ViewController.swift
//  LXMarqueeLabel
//
//  Created by 冠霖环如 on 2017/11/16.
//  Copyright © 2017年 冠霖环如. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    private let textList: [String] = ["新浪手机讯", "11月16日上午消息，", "苹果公司近期推出的iOS 11测试版", "已经支持iPhone 8、8 Plus", "以及iPhone X的无线快充功能，", "但实测发现", "其实它的效果没有想象那么好。"]

    @IBOutlet private var containerView: UIView!
    @IBOutlet private var marqueeLabel: LXMarqueeLabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        marqueeLabel.textList = textList
    }

//    override func viewDidAppear(_ animated: Bool) {
//        super.viewDidAppear(animated)
//        marqueeLabel.run()
//    }
//
//    override func viewDidDisappear(_ animated: Bool) {
//        super.viewDidAppear(animated)
//        marqueeLabel.pause()
//    }

    @IBAction func controlButtonTapped(_ sender: UIButton) {
        switch sender.tag {
        case 0:
            marqueeLabel.run()
        case 1:
            marqueeLabel.pause()
        case 2:
            marqueeLabel.stop()
        default:
            fatalError()
        }
    }
}
