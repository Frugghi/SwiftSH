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

public class SSHShell<T: RawLibrary>: SSHChannel<T> {

    // MARK: - Internal variables

    internal var readSource: DispatchSourceRead?
    internal var writeSource: DispatchSourceWrite?
    internal var writing: Bool = false

    // MARK: - Private variables

    fileprivate var messageQueue = [Message]()

    // MARK: - Initialization

    public override init?(host: String, port: UInt16 = 22, environment: [Environment] = [], terminal: Terminal? = nil) {
        super.init(host: host, port: port, environment: environment, terminal: terminal)
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
    
    public func withCallback(_ callback: ((_ string: String?, _ error: String?) -> Void)?) -> Self {
        self.readStringCallback = callback

        return self
    }
    
    public func withCallback(_ callback: ((_ data: Data?, _ error: Data?) -> Void)?) -> Self {
        self.readDataCallback = callback

        return self
    }

    // MARK: - Open/Close

    public func open() -> Self {
        self.open(nil)

        return self
    }

    public func open(_ completion: SSHCompletionBlock?) {

        self.queue.async(completion: completion) { [weak self] in

            try self?.openInQueue(completion: completion)
        }
    }

    private func openInQueue(completion: SSHCompletionBlock?) throws {

        // Open the channel
        try super.open()

        log.debug("Opening the shell...")

        // Set blocking mode
        session.blocking = true

        // Open a shell
        try channel.shell()

        // Read the received data
        readSource = DispatchSource.makeReadSource(fileDescriptor: CFSocketGetNative(socket), queue: queue.queue)
        guard let readSource = readSource else {
            throw SSHError.allocation
        }

        readSource.setEventHandler { [weak self] in

            self?.handleReadEvent()
        }
        readSource.resume()

        // Write the input data
        writeSource = DispatchSource.makeWriteSource(fileDescriptor: CFSocketGetNative(socket), queue: queue.queue)
        guard let writeSource = writeSource else {
            throw SSHError.allocation
        }

        writeSource.setEventHandler { [weak self] in

            self?.handleWriteEvent()

        }
        writeSource.setCancelHandler { [weak self] in
            if self?.writing == false {
                writeSource.resume()
            }
        }

        log.debug("Shell opened successfully")

    }

    private func handleReadEvent() {

        log.debug("Handle socket read")

        // Set non-blocking mode
        session.blocking = false

        // Read the response
        var response: Data?
        do {
            response = try channel.read() as Data
            log.debug("Read \((response ?? Data()).count) bytes")
        } catch let error {
            log.error("[STD] \(error)")
        }

        // Read the error
        var error: Data?
        do {
            let data = try channel.readError()
            if data.count > 0 {
                error = data
            }
        } catch let error{
            log.error("[ERR] \(error)")
        }

        // Call the callbacks
        if let callback = readStringCallback {
            queue.callbackQueue.async {
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
        if let callback = readDataCallback {
            queue.callbackQueue.async {
                callback(response, error)
            }
        }

        // Check if the host has closed the channel
        if channel.receivedEOF {
            log.info("Received EOF")
            close()
        }
    }

    private func handleWriteEvent() {

        log.debug("Handle socket write")

        // Set non-blocking mode
        session.blocking = false

        while messageQueue.isEmpty == false,
            var message = messageQueue.last {

                // Get the message and send it
                self.log.debug("Sending a message of \(message.data.count) bytes")
                let result = channel.write(message.data)

                switch result {
                // We'll send the remaining bytes when the socket is ready
                case (.some(SSHError.again), let bytesSent):
                    message.data.removeFirst(bytesSent)
                    self.log.debug("Sent \(bytesSent) bytes (\(message.data.count) bytes remaining)")

                // Done, call the callback
                case (let error, _):
                    messageQueue.removeLast()
                    log.debug("Message sent (\(self.messageQueue.count) remaining)")
                    if let completion = message.callback {
                        self.queue.callbackQueue.async {
                            completion(error)
                        }
                    }
                }
        }

        // If the message queue is empty suspend the source
        if let writeSource = writeSource, self.messageQueue.isEmpty {
            writeSource.suspend()
            writing = false
        }

    }

    public func close(_ completion: (() -> ())?) {
        self.queue.async { [weak self] in
            self?.close()

            if let completion = completion {
                self?.queue.callbackQueue.async {
                    completion()
                }
            }
        }
    }

    internal override func close() {
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
    
    public func write(_ data: Data) -> Self {
        self.write(data, completion: nil)

        return self
    }

    public func write(_ data: Data, completion: ((Error?) -> Void)?) {
        self.queue.async { [weak self] in
            // Insert the message in the message queue
            let message = Message(data: data, callback: completion)
            self?.messageQueue.insert(message, at: 0)

            // Start the write source if necessary
            if let writeSource = self?.writeSource, self?.messageQueue.isEmpty == false, self?.writing == false {
                self?.writing = true
                writeSource.resume()
            }
        }
    }

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
