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

public class SSHCommand: SSHChannel {

    // MARK: - Internal variables

    internal var socketSource: DispatchSourceRead?
    internal var timeoutSource: DispatchSourceTimer?

    // MARK: - Initialization

    public override init(sshLibrary: SSHLibrary.Type = Libssh2.self, host: String, port: UInt16 = 22, environment: [Environment] = [], terminal: Terminal? = nil) throws {
        try super.init(sshLibrary: sshLibrary, host: host, port: port, environment: environment, terminal: terminal)
    }

    deinit {
        self.cancelSources()
    }

    public override func close() {
        self.cancelSources()

        self.queue.async {
            super.close()
        }
    }
    
    private func cancelSources() {
        if let timeoutSource = self.timeoutSource, !timeoutSource.isCancelled {
            timeoutSource.cancel()
        }
        
        if let socketSource = self.socketSource, !socketSource.isCancelled {
            socketSource.cancel()
        }
    }

    // MARK: - Execute

    private var response: Data?
    private var error: Data?

    public func execute(_ command: String, completion: ((String, Data?, Error?) -> Void)?) {
        self.queue.async(completion: { (error: Error?) in
            if let error = error {
                self.close()

                if let completion = completion {
                    completion(command, nil, error)
                }
            }
        }, block: {
            self.response = nil
            self.error = nil

            // Open the channel
            try self.open()

            // Read the received data
            self.socketSource = DispatchSource.makeReadSource(fileDescriptor: CFSocketGetNative(self.socket), queue: self.queue.queue)
            guard let socketSource = self.socketSource else {
                throw SSHError.allocation
            }

            socketSource.setEventHandler { [weak self] in
                guard let self = self, let timeoutSource = self.timeoutSource else {
                    return
                }
                
                // Suspend the timer to prevent calling completion two times
                timeoutSource.suspend()
                defer {
                    timeoutSource.resume()
                }

                // Set non-blocking mode
                self.session.blocking = false

                // Read the result
                var socketClosed = true
                do {
                    let data = try self.channel.read()
                    if self.response == nil {
                        self.response = Data()
                    }

                    self.response!.append(data)
                    
                    socketClosed = false
                } catch let error {
                    self.log.error("[STD] \(error)")
                }

                // Read the error
                do {
                    let data = try self.channel.readError()
                    if data.count > 0 {
                        if self.error == nil {
                            self.error = Data()
                        }

                        self.error!.append(data)
                    }
                    
                    socketClosed = false
                } catch let error {
                    self.log.error("[ERR] \(error)")
                }

                // Check if we can return the response
                if self.channel.receivedEOF || self.channel.exitStatus() != nil || socketClosed {
                    defer {
                        self.cancelSources()
                    }

                    if let completion = completion {
                        let result = self.response
                        var error: Error?
                        if let message = self.error {
                            error = SSHError.Command.execError(String(data: message, encoding: .utf8), message)
                        }

                        self.queue.callbackQueue.async {
                            completion(command, result, error)
                        }
                    }
                }
            }
            socketSource.setCancelHandler { [weak self] in
                self?.close()
            }

            // Create the timeout handler
            self.timeoutSource = DispatchSource.makeTimerSource(queue: self.queue.queue)
            guard let timeoutSource = self.timeoutSource else {
                throw SSHError.allocation
            }

            timeoutSource.setEventHandler { [weak self] in
                guard let self = self else {
                    return
                }
                
                self.cancelSources()

                if let completion = completion {
                    let result = self.response
                    
                    self.queue.callbackQueue.async {
                        completion(command, result, SSHError.timeout)
                    }
                }
            }
            timeoutSource.schedule(deadline: .now() + self.timeout, repeating: self.timeout, leeway: .seconds(10))
            
            // Set blocking mode
            self.session.blocking = true
            
            // Execute the command
            try self.channel.exec(command)
            
            // Set non-blocking mode
            self.session.blocking = false
            
            // Start listening for new data
            timeoutSource.resume()
            socketSource.resume()
        })
    }

    public func execute(_ command: String, completion: ((String, String?, Error?) -> Void)?) {
        self.execute(command) { (command: String, result: Data?, error: Error?) -> Void in
            guard let completion = completion else {
                return
            }

            var stringResult: String?
            if let result = result {
                stringResult = String(data: result, encoding: .utf8)
            }

            completion(command, stringResult, error)
        }
    }

}
