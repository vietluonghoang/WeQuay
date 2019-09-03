//
//  HomeIndicatorListionerViewController.swift
//  NightOwlCam
//
//  Created by VietLH on 9/3/19.
//  Copyright © 2019 VietLH. All rights reserved.
//

import UIKit

class HomeIndicatorListionerViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if #available(iOS 11.0, *) {
            print("set update home indicator")
            setNeedsUpdateOfHomeIndicatorAutoHidden()
            setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
        } else {
            // Fallback on earlier versions
        }
    }
    
    override var prefersHomeIndicatorAutoHidden: Bool {
        print("return autohide 2")
        return true
    }
    
    //@available(iOS 11, *)
    override var childForHomeIndicatorAutoHidden: UIViewController? {
        print("check child view 2")
        return nil
    }
    
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge {
        print("deffer edge")
        return .all
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
