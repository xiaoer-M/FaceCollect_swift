//
//  ViewController.swift
//  FaceCollect
//
//  Created by 小二 on 2019/11/21.
//  Copyright © 2019 小二. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let vc = CPFaceRecViewController()
        self.present(vc, animated: true, completion: nil);
    }
}

