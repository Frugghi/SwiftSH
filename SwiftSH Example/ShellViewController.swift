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

class ShellViewController: UIViewController, SSHViewController {
    
    @IBOutlet var textView: UITextView!
    
    var shell: SSHShell!
    var authenticationChallenge: AuthenticationChallenge?
    var semaphore: DispatchSemaphore!
    var lastCommand = ""
    
    var requiresAuthentication = false
    var hostname: String!
    var port: UInt16?
    var username: String!
    var password: String?
    
    // This is an example showing how to use your own callback, and it is tightly coupled with your code
    // when this is set, you should create your keys, and bring the .externalRepresentation() of those
    // here, and then you can see how this is used with the signing code below
    var optPubKey: Data? = Data (base64Encoded: "AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBJ2tKFedFj5BuevFKzyX4WsQCRdrywVX+w1xVcA5vaGXvn15wsKydh/yRp6FDqSsNfguWHgKOLy65FoH5ih794I=")
    let privateKey = Data (base64Encoded: "BJ2tKFedFj5BuevFKzyX4WsQCRdrywVX+w1xVcA5vaGXvn15wsKydh/yRp6FDqSsNfguWHgKOLy65FoH5ih794LgJuzbVceIWIi+GMCuCkMKilM2Nq5DHQM626wYuzrTig==")!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.textView.text = ""
        self.textView.isEditable = false
        self.textView.isSelectable = false
        
        if self.requiresAuthentication {
            if let publicKey = optPubKey {
                
                // Turn the nice privateKey above from the data blob into a SecKey
                var error: Unmanaged<CFError>? = nil
                guard let key = SecKeyCreateWithData (privateKey as NSData, [
                    kSecAttrKeyType as String:            kSecAttrKeyTypeECSECPrimeRandom,
                    kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
                    kSecAttrKeySizeInBits as String:      256,
                ] as NSDictionary, &error) else {
                    let errMsg = error!.takeRetainedValue() as Error
                    print ("This should really never happen, it should be able to create a SecKey from the above base64 encoded privateKey\(errMsg)")
                    abort ()
                }

                self.authenticationChallenge = .byCallback(username: self.username, publicKey: publicKey, signCallback: { dataToSign in
                    guard let signed = SecKeyCreateSignature(key, .ecdsaSignatureMessageX962SHA256, dataToSign as CFData, &error) else {
                        return nil
                    }
                    return signed as NSData as Data
                })
            } else if let password = self.password {
                self.authenticationChallenge = .byPassword(username: self.username, password: password)
            } else {
                self.authenticationChallenge = .byKeyboardInteractive(username: self.username) { [unowned self] challenge in
                    DispatchQueue.main.async {
                        self.appendToTextView(challenge)
                        self.textView.isEditable = true
                    }
                    
                    self.semaphore = DispatchSemaphore(value: 0)
                    _ = self.semaphore.wait(timeout: DispatchTime.distantFuture)
                    self.semaphore = nil
                    
                    return self.password ?? ""
                }
            }
        }
        
        self.shell = try? SSHShell(host: self.hostname, port: self.port ?? 22, terminal: "vanilla")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.connect()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        self.disconnect()
    }
    
    @IBAction func connect() {
        self.shell
            .withCallback { [unowned self] (string: String?, error: String?) in
                DispatchQueue.main.async {
                    if let string = string {
                        self.appendToTextView(string)
                    }
                    if let error = error {
                        self.appendToTextView("[ERROR] \(error)")
                    }
                }
            }
            .connect()
            .authenticate(self.authenticationChallenge)
            .open { [unowned self] (error) in
                if let error = error {
                    self.appendToTextView("[ERROR] \(error)")
                    self.textView.isEditable = false
                } else {
                    self.textView.isEditable = true
                }                
            }
    }
    
    @IBAction func disconnect() {
        self.shell?.disconnect { [unowned self] in
            self.textView.isEditable = false
            self.navigationController?.popViewController(animated: true)
        }
    }
    
    func appendToTextView(_ text: String) {
        self.textView.text = "\(self.textView.text!)\(text)"
        self.textView.scrollRangeToVisible(NSRange(location: self.textView.text.utf8.count - 1, length: 1))
    }
    
    func performCommand() {
        if let semaphore = self.semaphore {
            self.password = self.lastCommand.trimmingCharacters(in: .newlines)
            semaphore.signal()
        } else {
            print("Last command is '\(self.lastCommand)'")
            self.shell.write(self.lastCommand) { [unowned self] (error) in
                if let error = error {
                    self.appendToTextView("[ERROR] \(error)")
                }
            }
        }
        
        self.lastCommand = ""
    }
    
}

extension ShellViewController: UITextViewDelegate {
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        self.textView.resignFirstResponder()
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        guard !text.isEmpty else {
            guard !self.lastCommand.isEmpty else {
                return false
            }
            
            let endIndex = self.lastCommand.endIndex
            self.lastCommand.removeSubrange(self.lastCommand.index(before: endIndex)..<endIndex)
            
            return true
        }
        
        self.lastCommand.append(text)
        
        if text == "\n" {
            self.performCommand()
        }
        
        return true
    }
    
}
