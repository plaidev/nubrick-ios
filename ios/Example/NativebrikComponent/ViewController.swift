//
//  ViewController.swift
//  NativebrikComponent
//
//  Created by 14113526 on 03/28/2023.
//  Copyright (c) 2023 14113526. All rights reserved.
//

import UIKit
import NativebrikComponent

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        let url: String = "http://localhost:8060/client"
        let apiKey: String = "1G67fRWJlE9dNZoJffmLTFzAhHhMRh7R"
        let blockController = Nativebrik(apiKey: apiKey, environment: url).ComponentVC(id: "cgqeu8et3eust2slcvc0")
        self.addChildViewController(blockController)
        self.view.addSubview(blockController.view)
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

