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

protocol SSHViewController: class {
    
    var requiresAuthentication: Bool { get set }
    var hostname: String! { get set }
    var port: UInt16? { get set }
    var username: String! { get set }
    var password: String? { get set }
    
}

class LoginViewController: UIViewController {
    
    @IBOutlet var connectButton: UIBarButtonItem!
    @IBOutlet var hostnameTextField: UITextField!
    @IBOutlet var portTextField: UITextField!
    @IBOutlet var usernameTextField: UITextField!
    @IBOutlet var passwordTextField: UITextField!
    @IBOutlet var authenticationMethodControl: UISegmentedControl!
    
    var segue: String!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        let userDefaults = UserDefaults.standard
        userDefaults.register(defaults: [ "auth": 0 ])
        self.hostnameTextField.text = userDefaults.string(forKey: "hostname")
        self.portTextField.text = userDefaults.string(forKey: "port")
        self.usernameTextField.text = userDefaults.string(forKey: "username")
        self.passwordTextField.text = userDefaults.string(forKey: "password")
        self.authenticationMethodControl.selectedSegmentIndex = userDefaults.integer(forKey: "auth")
        self.authenticationMethodControl.sendActions(for: .valueChanged)
        
        self.connectButton.isEnabled = self.isValidConfiguration()
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let viewController = segue.destination as? SSHViewController else {
            return
        }
        
        let userDefaults = UserDefaults.standard
        userDefaults.set(self.hostnameTextField.text, forKey: "hostname")
        userDefaults.set(self.portTextField.text, forKey: "port")
        userDefaults.set(self.usernameTextField.text, forKey: "username")
        userDefaults.set(self.passwordTextField.text, forKey: "password")
        userDefaults.set(self.authenticationMethodControl.selectedSegmentIndex, forKey: "auth")
        userDefaults.synchronize()
        
        viewController.requiresAuthentication = self.authenticationMethodControl.selectedSegmentIndex != 0
        viewController.hostname = self.hostnameTextField.text
        viewController.username = self.usernameTextField.text
        if self.passwordTextField.isEnabled {
            viewController.password = self.passwordTextField.text
        }
        if let portString = self.portTextField.text, let port = UInt16(portString), port > 0 {
            viewController.port = port
        }
    }
    
    @IBAction func tapBackground() {
        self.hostnameTextField.resignFirstResponder()
        self.portTextField.resignFirstResponder()
        self.usernameTextField.resignFirstResponder()
        self.passwordTextField.resignFirstResponder()
    }
    
    @IBAction func authenticationMethodChanged() {
        self.passwordTextField.isEnabled = self.authenticationMethodControl.selectedSegmentIndex == 1
        self.usernameTextField.returnKeyType = self.passwordTextField.isEnabled ? .next : .go
    }
    
    @IBAction func connect(_ sender: AnyObject!) {
        self.performSegue(withIdentifier: self.segue, sender: sender)
    }
    
    func isValidConfiguration() -> Bool {
        guard !self.hostnameTextField.text!.isEmpty else { return false }
        guard self.portTextField.text!.isEmpty || (!self.portTextField.text!.isEmpty && Int(self.portTextField.text!) != nil) else { return false }
        guard !self.usernameTextField.text!.isEmpty else { return false }
        guard !self.passwordTextField.isEnabled || (self.passwordTextField.isEnabled && !self.passwordTextField.text!.isEmpty) else { return false }
        
        return true
    }

}

extension LoginViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField === self.hostnameTextField {
            self.usernameTextField.becomeFirstResponder()
        } else if textField === self.portTextField {
            self.usernameTextField.becomeFirstResponder()
        } else if textField === self.usernameTextField && self.passwordTextField.isEnabled {
            self.passwordTextField.becomeFirstResponder()
        } else if textField.returnKeyType == .go && self.isValidConfiguration() {
            self.performSegue(withIdentifier: self.segue, sender: textField)
        }
        
        return false
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        self.connectButton.isEnabled = self.isValidConfiguration()
    }
    
    @IBAction func textFiedTextChanged(_ textFiled: UITextField!) {
        self.connectButton.isEnabled = self.isValidConfiguration()
    }
    
}
