//
//  ViewController.swift
//  Example-UIKit
//
//  Created by Ryosuke Suzuki on 2023/11/28.
//

import UIKit
import Nubrick

let nubrick = {
    return NubrickClient(projectId: "cgv3p3223akg00fod19g")
}()

final class ViewController: UIViewController {
    private var button: UIButton?
    private var count: Int = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        // add Nativebrik.overlay at first
        let overlay = nubrick.experiment.overlayViewController()
        self.addChild(overlay)
        self.view.addSubview(overlay.view)
        overlay.didMove(toParent: self)
        overlay.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            overlay.view.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            overlay.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        // embed nativebrik TOP_COMPONENT
        let topComponent = nubrick.experiment.embeddingUIView("TOP_COMPONENT")
        self.view.addSubview(topComponent)

        topComponent.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            topComponent.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            topComponent.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topComponent.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topComponent.heightAnchor.constraint(equalToConstant: 230)
        ])

        // add a button
        let button = UIButton(type: .system)
        button.backgroundColor = .black
        button.setTitle("Click me!", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.addTarget(self, action: #selector(self.onButtonTapped(sender:)), for: .touchUpInside)
        button.layer.cornerRadius = 8
        button.center = CGPoint(x: self.view.center.x, y: 348)
        self.view.addSubview(button)
        self.button = button

        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: topComponent.bottomAnchor, constant: 16),
            button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            button.widthAnchor.constraint(equalToConstant: 120),
            button.heightAnchor.constraint(equalToConstant: 40)
        ])
    }

    
    @objc private func onButtonTapped(sender: UIButton) {
        self.count += 1
        self.button?.setTitle("\(count) clicked!", for: .normal)
    }
}
