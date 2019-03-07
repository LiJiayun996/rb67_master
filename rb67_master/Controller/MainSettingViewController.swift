//
//  MainSettingViewController.swift
//  rb67_master
//
//  Created by Jiayun Li on 3/3/19.
//  Copyright © 2019 Jiayun Li. All rights reserved.
//

import UIKit

class MainSettingViewController: UITableViewController {

    @IBOutlet var settingTableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        print("setting vc loaded")

        // Do any additional setup after loading the view.
    }
   
    
    @IBAction func backButtonPressed(_ sender: Any) {
        
        print("Back Button Pressed")
        
        self.dismiss(animated: true, completion: nil)
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
