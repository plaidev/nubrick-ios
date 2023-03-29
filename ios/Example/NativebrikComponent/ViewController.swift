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
        let blockController = Nativebrik(apiKey: "02JfQkulJJXyvgHHZHr3CCmgiJcG3gVo").ComponentVC(id: "cgetcniq5o2ctv8nlh2g")
        self.addChildViewController(blockController)
        self.view.addSubview(blockController.view)
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

