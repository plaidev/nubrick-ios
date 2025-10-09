//
//  ViewController.swift
//  Example-UIKit
//
//  Created by Ryosuke Suzuki on 2023/11/28.
//

import UIKit
import Nubrick

let nativebrik = {
    return NubrickClient(projectId: "cgv3p3223akg00fod19g")
}()

class ViewController: UIViewController {
    var button: UIButton? = nil
    var count: Int = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        // add Nativebrik.overlay at first
        let overlay = nativebrik.experiment.overlayViewController()
        self.addChild(overlay)
        self.view.addSubview(overlay.view)
        
        // embed nativebrik TOP_COMPONENT
        let topComponent = nativebrik.experiment.embeddingUIView("TOP_COMPONENT")
        topComponent.frame = .init(x: 0, y: 100, width: self.view.frame.width, height: 230)
        self.view.addSubview(topComponent)
        
        // add a button
        let button = UIButton(frame: CGRect(x: 0, y: 0, width: 120, height: 40))
        button.backgroundColor = .black
        button.setTitle("Click me!", for: .normal)
        button.addTarget(self, action: #selector(self.onButtonTapped(sender:)), for: .touchUpInside)
        button.layer.cornerRadius = 8
        button.center = CGPoint(x: self.view.center.x, y: 348)
        self.view.addSubview(button)
        self.button = button
    }
    
    @objc func onButtonTapped(sender:UIButton) {
        self.count += 1
        self.button?.setTitle(String(self.count) + " clicked!", for: .normal)
    }
}
