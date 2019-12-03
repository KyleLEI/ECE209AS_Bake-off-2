//
//  viewController.swift
//  PoseEstimation-CoreML
//
//  Created by Yifei CHEN on 2019/12/2.
//  Copyright © 2019 tucan9389. All rights reserved.
//

import Foundation
import UIKit

class ViewController: UIViewController,StreamDelegate {
    @IBOutlet weak var addr_input: UITextField!
    @IBOutlet weak var page_up_button: UIButton!
    @IBOutlet weak var page_down_button: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }
    func page_up() {
        print("page up")
        outputStream?.write("u",maxLength: 1)
    }
    func page_down() {
        print("page down")
        outputStream?.write("d",maxLength: 1)
    }
    
    var addr = "127.0.0.1"
    let port = 7673
    var inputStream: InputStream?
    var outputStream: OutputStream?
    
    @IBAction func connect(_ sender: Any) {
        view.endEditing(true)
        addr = addr_input.text!;
        print("Connecting to server @ " + addr)
        Stream.getStreamsToHost(withName: addr, port: port, inputStream: &inputStream, outputStream: &outputStream)
        
        outputStream?.delegate = self
        outputStream?.schedule(in: .current, forMode: .common)
        outputStream?.open()
    }
    
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        if (eventCode == Stream.Event.hasSpaceAvailable) {
            print("Server connected")
            page_down_button.isEnabled = true
            page_up_button.isEnabled = true
        }else{
            page_up_button.isEnabled = false
            page_down_button.isEnabled = false
        }
    }
}
