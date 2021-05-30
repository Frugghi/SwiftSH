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

public class SSHShell: SSHChannel {

    // MARK: - Internal variables

    internal var readSource: DispatchSourceRead?
    internal var writeSource: DispatchSourceWrite?
    internal var writing: Bool = false

    // MARK: - Private variables

    fileprivate var messageQueue: [Message] = []

    // MARK: - Initialization

    public override init(sshLibrary: SSHLibrary.Type = Libssh2.self, host: String, port: UInt16 = 22, environment: [Environment] = [], terminal: Terminal? = nil) throws {
        try super.init(sshLibrary: sshLibrary, host: host, port: port, environment: environment, terminal: terminal)
    }

    deinit {
        if let readSource = self.readSource, !readSource.isCancelled {
            readSource.cancel()
        }
        
        if let writeSource = self.writeSource, !writeSource.isCancelled {
            writeSource.cancel()
        }
    }

    // MARK: - Callback

    public fileprivate(set) var readStringCallback: ((_ string: String?, _ error: String?) -> Void)?
    public fileprivate(set) var readDataCallback: ((_ data: Data?, _ error: Data?) -> Void)?
    
    @discardableResult
    public func withCallback(_ callback: ((_ string: String?, _ error: String?) -> Void)?) -> Self {
        self.readStringCallback = callback

        return self
    }
    
    @discardableResult
    public func withCallback(_ callback: ((_ data: Data?, _ error: Data?) -> Void)?) -> Self {
        self.readDataCallback = callback

        return self
    }

    // MARK: - Open/Close
    @discardableResult
    public func open() -> Self {
        self.open(nil)

        return self
    }

    public func open(_ completion: SSHCompletionBlock?) {
        self.queue.async(completion: completion) {
            // Open the channel
            try super.open()
            
            self.log.debug("Opening the shell...")

            // Read the received data
            self.readSource = DispatchSource.makeReadSource(fileDescriptor: CFSocketGetNative(self.socket), queue: self.queue.queue)
            guard let readSource = self.readSource else {
                throw SSHError.allocation
            }

            readSource.setEventHandler { [weak self] in
                guard let self = self else {
                    return
                }
                
                self.log.debug("Handle socket read")
                
                // Set non-blocking mode
                self.session.blocking = false

                // Read the response
                var response: Data?
                do {
                    response = try self.channel.read()
                    self.log.debug("Read \(response?.count ?? 0) bytes")
                } catch let error {
                    self.log.error("[STD] \(error)")
                }

                // Read the error
                var error: Data?
                do {
                    let data = try self.channel.readError()
                    if data.count > 0 {
                        error = data
                    }
                } catch let error {
                    self.log.error("[ERR] \(error)")
                }

                // Call the callbacks
                if let callback = self.readStringCallback {
                    self.queue.callbackQueue.async {
                        var responseString: String?
                        if let data = response {
                            responseString = String(data: data, encoding: .utf8)
                        }

                        var errorString: String?
                        if let data = error {
                            errorString = String(data: data, encoding: .utf8)
                        }

                        callback(responseString, errorString)
                    }
                }
                if let callback = self.readDataCallback, response != nil || error != nil {
                    self.queue.callbackQueue.async {
                        callback(response, error)
                    }
                }

                // Check if the host has closed the channel
                let receivedEOF = self.channel.receivedEOF
                let socketClosed = (response == nil && error == nil)
                if receivedEOF || socketClosed {
                    if receivedEOF {
                        self.log.info("Received EOF")
                    } else if socketClosed {
                        self.log.info("Socket has been closed without EOF")
                    }
                    self.close()
                }
            }

            // Write the input data
            self.writeSource = DispatchSource.makeWriteSource(fileDescriptor: CFSocketGetNative(self.socket), queue: self.queue.queue)
            guard let writeSource = self.writeSource else {
                throw SSHError.allocation
            }

            writeSource.setEventHandler { [weak self] in
                guard let self = self else {
                    return
                }
                
                self.log.debug("Handle socket write")
                
                // Set non-blocking mode
                self.session.blocking = false

                while !self.messageQueue.isEmpty {
                    // Get the message and send it
                    var message = self.messageQueue.last!
                    self.log.debug("Sending a message of \(message.data.count) bytes")
                    let result = self.channel.write(message.data)

                    switch result {
                        // We'll send the remaining bytes when the socket is ready
                        case (SSHError.again?, let bytesSent):
                            message.data.removeFirst(bytesSent)
                            self.log.debug("Sent \(bytesSent) bytes (\(message.data.count) bytes remaining)")

                        // Done, call the callback
                        case (let error, _):
                            self.messageQueue.removeLast()
                            self.log.debug("Message sent (\(self.messageQueue.count) remaining)")
                            if let completion = message.callback {
                                self.queue.callbackQueue.async {
                                    completion(error)
                                }
                            }
                    }
                }

                // If the message queue is empty suspend the source
                if let writeSource = self.writeSource, self.messageQueue.isEmpty {
                    writeSource.suspend()
                    self.writing = false
                }
            }
            writeSource.setCancelHandler { [weak self] in
                guard let self = self else {
                    return
                }

                if !self.writing {
                    writeSource.resume()
                }
            }
            
            // Set blocking mode
            self.session.blocking = true
            
            // Open a shell
            try self.channel.shell()
            
            // Set non-blocking mode
            self.session.blocking = false
            
            // Start listening for new data
            readSource.resume()
            
            self.log.debug("Shell opened successfully")
        }
    }

    public func close(_ completion: (() -> Void)?) {
        self.queue.async {
            self.close()

            if let completion = completion {
                self.queue.callbackQueue.async {
                    completion()
                }
            }
        }
    }

    internal override func close() {
        assert(self.queue.current)
        
        self.log.debug("Closing the shell...")
        
        // Cancel the socket sources
        if let readSource = self.readSource, !readSource.isCancelled {
            readSource.cancel()
        }
        if let writeSource = self.writeSource, !writeSource.isCancelled {
            writeSource.cancel()
        }

        // Set blocking mode
        self.session.blocking = true

        // Send EOF
        do {
            try self.channel.sendEOF()
        } catch {
            self.log.error("\(error)")
        }

        // Close the channel
        super.close()
    }

    // MARK: - Write
    @discardableResult
    public func write(_ data: Data) -> Self {
        self.write(data, completion: nil)

        return self
    }

    public func write(_ data: Data, completion: ((Error?) -> Void)?) {
        self.queue.async {
            // Insert the message in the message queue
            let message = Message(data: data, callback: completion)
            self.messageQueue.insert(message, at: 0)

            // Start the write source if necessary
            if let writeSource = self.writeSource, !self.messageQueue.isEmpty, !self.writing {
                self.writing = true
                writeSource.resume()
            }
        }
    }

    @discardableResult
    public func write(_ command: String) -> Self {
        self.write(command, completion: nil)
        
        return self
    }

    public func write(_ command: String, completion: ((Error?) -> Void)?) {
        guard let data = command.data(using: .utf8) else {
            if let completion = completion {
                self.queue.callbackQueue.async {
                    completion(SSHError.invalid)
                }
            }
            return
        }
        
        self.write(data, completion: completion)
    }
}

private struct Message {

    var data: Data
    let callback: ((Error?) -> Void)?

}
