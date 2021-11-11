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

open class SSHChannel {

    // MARK: - Public variables

    public fileprivate(set) var terminal: Terminal?
    public fileprivate(set) var channel: SSHLibraryChannel!

    public private(set) var session: SSHSession
    
    // MARK: - Internal variables

    internal let environment: [Environment]

    // MARK: - Initialization

    internal init(sshLibrary: SSHLibrary.Type = Libssh2.self, host: String, port: UInt16 = 22, environment: [Environment] = [], terminal: Terminal? = nil) throws {
        self.environment = environment
        self.terminal = terminal

        self.session = try SSHSession(sshLibrary: sshLibrary, host: host, port: port)

        self.channel = session.session.makeChannel()
    }

    internal init(sshLibrary: SSHLibrary.Type = Libssh2.self, session: SSHSession, environment: [Environment] = [], terminal: Terminal? = nil) throws {
        self.environment = environment
        self.terminal = terminal

        self.session = session

        self.channel = session.session.makeChannel()
    }

    // MARK: - Open/Close

    internal func open() throws {
        assert(session.queue.current)
        
        // Check if we are authenticated
        guard session.authenticated else {
            throw SSHError.authenticationFailed(detail: "Open attempted, but we are not authenticated")
        }
        
        // Check if the channel is already open
        guard !self.channel.opened else {
            throw SSHError.Channel.alreadyOpen
        }
        
        session.log.debug("Opening the channel...")
        
        // Set blocking mode
        session.session.blocking = true
        
        // Opening the channel
        try self.channel.openChannel()
        
        do {
            // Set the environment's variables
            session.log.debug("Environment: \(self.environment)")
            for variable in self.environment {
                try self.channel.setEnvironment(variable)
            }
            
            // Request the pseudo terminal
            if let terminal = self.terminal {
                session.log.debug("\(terminal) pseudo terminal requested")
                try self.channel.requestPseudoTerminal(terminal)
            }
        } catch {
            self.close()
            throw error
        }
    }

    internal func close() {
        assert(session.queue.current)
        
        session.log.debug("Closing the channel...")
        
        // Set blocking mode
        session.session.blocking = true

        // Close the channel
        do {
            try self.channel.closeChannel()
        } catch {
            session.log.error("\(error)")
        }
    }
    
    public func disconnect(_ completion: (() -> Void)?) {
        session.queue.async {
            self.close()
            
            self.session.disconnect(completion)
        }
    }

    // MARK: - Terminal
    @discardableResult
    public func setTerminalSize(width: UInt, height: UInt) -> Self {
        self.setTerminalSize(width: width, height: height, completion: nil)

        return self
    }

    public func setTerminalSize(width: UInt, height: UInt, completion: SSHCompletionBlock?) {
        session.queue.async(completion: completion) {
            guard let terminal = self.terminal else {
                throw SSHError.badUse(detail:"Terminal set size attempted, but the terminal has not been created yet"
                )
            }

            // Check if the new size is different from the old one
            if terminal.width != width || terminal.height != height {
                var resizedTerminal = terminal
                resizedTerminal.width = width
                resizedTerminal.height = height

                // Update the terminal size
                try self.channel.setPseudoTerminalSize(resizedTerminal)

                // Set the new terminal
                self.terminal = resizedTerminal
            }
        }
    }

}
