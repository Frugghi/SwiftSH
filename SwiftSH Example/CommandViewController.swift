//
// The MIT License (MIT)
//
// Copyright (c) 2017 Tommaso Madonia
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//

import Foundation
import UIKit
import SwiftSH

class CommandViewController: UIViewController, SSHViewController {
    
    @IBOutlet var commandTextField: UITextField!
    @IBOutlet var textView: UITextView!
    
    var command: Command!
    var authenticationChallenge: AuthenticationChallenge?
    var semaphore: DispatchSemaphore!
    var passwordTextField: UITextField?
    
    var requiresAuthentication = false
    var hostname: String!
    var port: UInt16?
    var username: String!
    var password: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if self.requiresAuthentication {
            if let password = self.password {
                self.authenticationChallenge = .byPassword(username: self.username, password: password)
            } else {
                self.authenticationChallenge = .byKeyboardInteractive(username: self.username) { [unowned self] challenge in
                    DispatchQueue.main.async {
                        self.askForPassword(challenge)
                    }
                    
                    self.semaphore = DispatchSemaphore(value: 0)
                    _ = self.semaphore.wait(timeout: DispatchTime.distantFuture)
                    self.semaphore = nil
                    
                    return self.password ?? ""
                }
            }
        }
        
        self.textView.text = ""
        
        self.command = Command(host: self.hostname, port: self.port ?? 22)
    }
    
    @IBAction func disconnect() {
        self.command?.disconnect { [unowned self] in
            self.navigationController?.popViewController(animated: true)
        }
    }
    
    func performCommand(_ command: String) {
        self.commandTextField.resignFirstResponder()
        
        self.command
            .connect()
            .authenticate(self.authenticationChallenge)
            .execute(command) { [unowned self] (command, result: String?, error) in
                if let result = result {
                    self.textView.text = result
                } else {
                    self.textView.text = "ERROR: \(String(describing: error))"
                }
            }
    }
    
    func askForPassword(_ challenge: String) {
        let alertController = UIAlertController(title: "Authetication challenge", message: challenge, preferredStyle: .alert)
        alertController.addTextField { [unowned self] (textField) in
            textField.placeholder = challenge
            textField.isSecureTextEntry = true
            self.passwordTextField = textField
        }
        alertController.addAction(UIAlertAction(title: "OK", style: .default) { [unowned self] _ in
            self.password = self.passwordTextField?.text
            if let semaphore = self.semaphore {
                semaphore.signal()
            }
        })
        self.present(alertController, animated: true, completion: nil)
    }
    
}

extension CommandViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if let command = textField.text, !command.isEmpty {
            self.performCommand(command)
        }
        
        return true
    }
    
}
