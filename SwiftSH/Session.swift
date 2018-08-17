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

public typealias SSHCompletionBlock = (Error?) -> Void

open class SSHSession<T: RawLibrary> {

    // MARK: - Internal variables

    internal let queue: Queue
    internal var session: RawSession
    internal var socket: CFSocket?

    // MARK: - Initialization

    /// The server host to connect to.
    public let host: String
    
    /// The server port to connect to.
    public let port: UInt16
    
    /// The logger.
    public var log: Logger

    /// The version of the underlying SSH library.
    public var version: String? {
        return T.version
    }

    public init?(host: String, port: UInt16 = 22) {
        self.host = host
        self.port = port
        self.log = ConsoleLogger(level: .debug, enabled: true)
        self.queue = Queue(label: "SSH Queue", concurrent: false)
        guard let session = T.newSession() else {
            return nil
        }

        self.session = session
        self.timeout = 10

        if let version = T.version {
            self.log.info("\(T.name) v\(version)")
        }
    }

    deinit {
        self.disconnect()
    }

    // MARK: - Connection

    /**
     * The banner that will be sent to the remote host when the SSH session is started.
     *
     * If `nil`, the default banner of the SSH library will be used.
     */
    public var banner: String?

    /// A boolean value indicating whether the session connected successfully.
    public fileprivate(set) var connected: Bool = false

    /// The banner received from the remote host.
    public fileprivate(set) var remoteBanner: String?
    
    /// The fingerprint received from the remote host.
    public fileprivate(set) var fingerprint: [FingerprintHashType: String] = [:]

    /// The timeout for the internal SSH operations.
    public var timeout: TimeInterval {
        set {
            self.session.timeout = max(0, Int(newValue * 1000))
            self.log.debug("Timeout set to \(self.timeout) seconds")
        }
        get {
            return TimeInterval(self.session.timeout / 1000)
        }
    }

    public func connect() -> Self {
        self.connect(nil)

        return self
    }

    public func connect(_ completion: SSHCompletionBlock?) {
        self.queue.async(completion: completion) {
            defer {
                if !self.connected {
                    self.disconnect()
                }
            }

            guard !self.connected else {
                throw SSHError.alreadyConnected
            }

            // Resolve the hostname synchronously
            let addresses: [Data]
            do {
                addresses = try DNS(hostname: self.host).lookup(timeout: self.timeout) as [Data]
                self.log.debug("\(self.host) resolved. \(addresses.count) addresses")
            } catch {
                throw SSHError.hostResolutionFailed
            }

            for address in addresses {

                let ipAddress: String
                let addressFamily: Int32
                let dataAddress: Data

                switch address.count {
                    case MemoryLayout<sockaddr_in>.size:
                        // IPv4
                        var socketAddress: sockaddr_in = address.withUnsafeBytes {
                            UnsafeRawPointer($0).bindMemory(to: sockaddr_in.self, capacity: address.count).pointee
                        }
                        socketAddress.sin_port = CFSwapInt16HostToBig(self.port)

                        ipAddress = socketAddress.sin_addr.description
                        addressFamily = AF_INET
                        dataAddress = Data(bytes: &socketAddress, count: MemoryLayout.size(ofValue: socketAddress))

                    case MemoryLayout<sockaddr_in6>.size:
                        // IPv6
                        var socketAddress: sockaddr_in6 = address.withUnsafeBytes {
                            UnsafeRawPointer($0).bindMemory(to: sockaddr_in6.self, capacity: address.count).pointee
                        }
                        socketAddress.sin6_port = CFSwapInt16HostToBig(self.port)

                        ipAddress = socketAddress.sin6_addr.description
                        addressFamily = AF_INET6
                        dataAddress = Data(bytes: &socketAddress, count: MemoryLayout.size(ofValue: socketAddress))

                    default:
                        self.log.warn("Unknown address, it's not IPv4 or IPv6!")
                        continue
                }

                // Try to create the socket
                guard let socket = CFSocketCreate(kCFAllocatorDefault, addressFamily, SOCK_STREAM, IPPROTO_IP, 0, nil, nil) else {
                    continue
                }

                // Set NOSIGPIPE
                guard socket.setSocketOption(1, level: SOL_SOCKET, name: SO_NOSIGPIPE) else {
                    continue
                }

                // Try to connect to resolved address
                if CFSocketConnectToAddress(socket, dataAddress as CFData, Double(self.timeout)/1000) == .success {
                    self.log.info("Connection to \(ipAddress) on port \(self.port) successful")
                    self.socket = socket
                    break
                } else {
                    self.log.warn("Connection to \(ipAddress) on port \(self.port) failed")
                }
            }

            // Check if we are connected to the host
            guard let socket = self.socket else {
                throw SSHError.Socket.invalid
            }

            // Set blocking mode
            self.session.blocking = true

            // Set custom banner
            if let banner = self.banner {
                do {
                    try self.session.setBanner(banner)
                } catch {
                    self.log.error("Unable to set the banner")
                }
            }

            // Start the session
            do {
                try self.session.handshake(socket)
            } catch let error {
                self.log.error("Handshake failed: \(error)")
                throw error
            }

            // Connection completed successfully
            self.connected = true
            
            // Get the remote banner
            self.remoteBanner = self.session.banner
            if let remoteBanner = self.remoteBanner {
                self.log.debug("Remote banner is \(remoteBanner)")
            }
            
            // Get the host's fingerprint
            self.fingerprint = [:]
            for hashType: FingerprintHashType in [.md5, .sha1] {
                self.fingerprint[hashType] = self.session.fingerprint(hashType)
            }
            self.log.debug("Fingerprint is \(self.fingerprint)")
        }
    }

    public func disconnect(_ completion: (() -> ())?) {
        self.queue.async {
            self.disconnect()

            if let completion = completion {
                self.queue.callbackQueue.async {
                    completion()
                }
            }
        }
    }

    fileprivate func disconnect() {
        self.queue.sync {
            self.log.info("Bye bye")

            // Disconnect the session
            if self.connected {
                do {
                    try self.session.disconnect()
                } catch {
                    self.log.error("\(error)")
                }
            }

            // Invalidate the socket
            if let socket = self.socket, CFSocketIsValid(socket) {
                CFSocketInvalidate(socket)
            }
            
            // Clean up state
            self.socket = nil
            self.connected = false
            self.remoteBanner = nil
            self.fingerprint = [:]
            
            self.log.debug("Disconnected")
        }
    }

    // MARK: - Authentication

    /// A boolean value indicating whether the session has been successfully authenticated.
    public var authenticated: Bool {
        return self.queue.sync { self.session.authenticated }
    }

    public func supportedAuthenticationMethods(_ username: String) throws -> [AuthenticationMethod] {
        return try self.queue.sync {
            try self.session.authenticationList(username).map { AuthenticationMethod($0) }
        }
    }

    public func authenticate(_ challenge: AuthenticationChallenge?) -> Self {
        self.authenticate(challenge, completion: nil)

        return self
    }

    public func authenticate(_ challenge: AuthenticationChallenge?, completion: SSHCompletionBlock?) {
        self.queue.async(completion: completion) {
            guard let challenge = challenge, !self.authenticated else {
                return
            }

            // Get the list of supported authentication methods
            let authenticationMethods = try self.supportedAuthenticationMethods(challenge.username)
            self.log.debug("Supported authentication methods: \(authenticationMethods)")

            // self.authenticated is true if the server supports SSH_USERAUTH_NONE
            guard !self.authenticated else {
                return
            }

            // Check if the required authentication method is available
            guard authenticationMethods.contains(challenge.requiredAuthenticationMethod) else {
                throw SSHError.unsupportedAuthenticationMethod
            }

            self.log.debug("Authenticating by \(challenge.requiredAuthenticationMethod)")

            switch challenge {
                case .byPassword(let username, let password):
                    // Password authentication
                    try self.session.authenticateByPassword(username, password: password)

                case .byKeyboardInteractive(let username, let callback):
                    // Keyboard Interactive authentication
                    try self.session.authenticateByKeyboardInteractive(username, callback: callback)

                case .byPublicKeyFromFile(let username, let password, let publicKey, let privateKey):
                    // Public Key authentication
                    let publicKey  = (publicKey as NSString?)?.expandingTildeInPath
                    let privateKey = (privateKey as NSString).expandingTildeInPath

                    try self.session.authenticateByPublicKeyFromFile(username, password: password, publicKey: publicKey, privateKey: privateKey)
                
                case .byPublicKeyFromMemory(let username, let password, let publicKey, let privateKey):
                    // Public Key authentication
                    try self.session.authenticateByPublicKeyFromMemory(username, password: password, publicKey: publicKey, privateKey: privateKey)
            }
        }
    }
    
    public func checkFingerprint(_ callback: @escaping ([FingerprintHashType: String]) -> Bool) -> Self {
        self.queue.async {
            guard self.connected else {
                return
            }
            
            let fingerprint = self.fingerprint
            var disconnect = false

            // Call the callback to verify the fingerprint
            DispatchQueue.syncOnMain {
                disconnect = !callback(fingerprint)
            }

            if disconnect {
                self.disconnect()
            }
        }

        return self
    }

    public func checkFingerprint(_ validFingerprints: String...) -> Self {
        return self.checkFingerprint { fingerprint in
            return fingerprint.values.contains(where: { validFingerprints.contains($0) })
        }
    }

}
