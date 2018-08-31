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

import Libssh2

public typealias SSH = SSHSession<Libssh2>
public typealias Channel = SSHChannel<Libssh2>
public typealias Command = SSHCommand<Libssh2>
public typealias Shell = SSHShell<Libssh2>
//public typealias SCP = SCPSession<Libssh2>
//public typealias SFTP = SFTPSession<Libssh2>

public class Libssh2: RawLibrary {

    public private(set) static var name: String = "Libssh2"
    public private(set) static var version: String?

    public class func newSession() -> RawSession? {
        return Libssh2.Session()
    }

    public class func newChannel(_ session: RawSession) -> RawChannel? {
        if let session = session as? Libssh2.Session {
            return Libssh2.Channel(session: session.session)
        } else {
            return nil
        }
    }

}

fileprivate extension Int {
    
    var error: Error {
        return Int32(self).error(sftp: nil)
    }
    
}

fileprivate extension Int32 {
    
    var error: Error {
        return self.error(sftp: nil)
    }
    
    func error(sftp: OpaquePointer?) -> Error {
        if let error = self.soketError() {
            return error
        } else if let error = self.channelError() {
            return error
        } else if let error = self.scpError() {
            return error
        } else if let error = self.sftpError(sftp: sftp) {
            return error
        }
        
        return self.genericSSHError()
    }
    
    private func genericSSHError() -> SSHError {
        switch self {
        case LIBSSH2_ERROR_BANNER_RECV: return .bannerReceive
        case LIBSSH2_ERROR_BANNER_SEND: return .bannerSend
        case LIBSSH2_ERROR_INVALID_MAC: return .invalidMessageAuthenticationCode
        case LIBSSH2_ERROR_KEX_FAILURE: return .keyExchangeFailure
        case LIBSSH2_ERROR_ALLOC: return .allocation
        case LIBSSH2_ERROR_KEY_EXCHANGE_FAILURE: return .keyExchangeFailure
        case LIBSSH2_ERROR_TIMEOUT: return .timeout
        case LIBSSH2_ERROR_HOSTKEY_INIT: return .hostkey
        case LIBSSH2_ERROR_HOSTKEY_SIGN: return .hostkey
        case LIBSSH2_ERROR_DECRYPT: return .decrypt
        case LIBSSH2_ERROR_PROTO: return .protocol
        case LIBSSH2_ERROR_PASSWORD_EXPIRED: return .passwordExpired
        case LIBSSH2_ERROR_FILE: return .publicKeyFile
        case LIBSSH2_ERROR_METHOD_NONE: return .methodNone
        case LIBSSH2_ERROR_AUTHENTICATION_FAILED: return .authenticationFailed
        case LIBSSH2_ERROR_PUBLICKEY_UNVERIFIED: return .publicKeyUnverified
        case LIBSSH2_ERROR_ZLIB: return .unknown
        case LIBSSH2_ERROR_REQUEST_DENIED: return .requestDenied
        case LIBSSH2_ERROR_METHOD_NOT_SUPPORTED: return .methodNotSupported
        case LIBSSH2_ERROR_INVAL: return .invalid
        case LIBSSH2_ERROR_INVALID_POLL_TYPE: return .unknown
        case LIBSSH2_ERROR_PUBLICKEY_PROTOCOL: return .publicKeyProtocol
        case LIBSSH2_ERROR_EAGAIN: return .again
        case LIBSSH2_ERROR_BUFFER_TOO_SMALL: return .bufferTooSmall
        case LIBSSH2_ERROR_BAD_USE: return .badUse
        case LIBSSH2_ERROR_COMPRESS: return .compress
        case LIBSSH2_ERROR_OUT_OF_BOUNDARY: return .outOfBoundary
        case LIBSSH2_ERROR_AGENT_PROTOCOL: return .agentProtocol
        case LIBSSH2_ERROR_ENCRYPT: return .encrypt
        case LIBSSH2_ERROR_KNOWN_HOSTS: return .knownHosts
        default: return .unknown
        }
    }
    
    private func channelError() -> SSHError.Channel? {
        switch self {
        case LIBSSH2_ERROR_CHANNEL_OUTOFORDER: return .outOfOrder
        case LIBSSH2_ERROR_CHANNEL_FAILURE: return .failure
        case LIBSSH2_ERROR_CHANNEL_REQUEST_DENIED: return .requestDenied
        case LIBSSH2_ERROR_CHANNEL_UNKNOWN: return .unknown
        case LIBSSH2_ERROR_CHANNEL_WINDOW_EXCEEDED: return .windowExceeded
        case LIBSSH2_ERROR_CHANNEL_PACKET_EXCEEDED: return .packetExceeded
        case LIBSSH2_ERROR_CHANNEL_CLOSED: return .closed
        case LIBSSH2_ERROR_CHANNEL_EOF_SENT: return .sentEndOfFile
        default: return nil
        }
    }
    
    private func soketError() -> SSHError.Socket? {
        switch self {
        case LIBSSH2_ERROR_SOCKET_RECV: return .read
        case LIBSSH2_ERROR_SOCKET_SEND: return .write
        case LIBSSH2_ERROR_SOCKET_TIMEOUT: return .timeout
        case LIBSSH2_ERROR_BAD_SOCKET: return .invalid
        case LIBSSH2_ERROR_SOCKET_DISCONNECT: return .disconnected
        default: return nil
        }
    }
    
    private func scpError() -> SSHError.SCP? {
        switch self {
        case LIBSSH2_ERROR_SCP_PROTOCOL: return .protocol
        default: return nil
        }
    }
    
    private func sftpError(sftp: OpaquePointer?) -> SSHError.SFTP? {
        guard self == LIBSSH2_ERROR_SFTP_PROTOCOL else {
            return nil
        }
        
        guard let sftp = sftp else {
            return .invalidSession
        }

        switch Int32(libssh2_sftp_last_error(sftp)) {
        case LIBSSH2_FX_EOF: return .endOfFile
        case LIBSSH2_FX_NO_SUCH_FILE: return .noSuchFile
        case LIBSSH2_FX_PERMISSION_DENIED: return .permissionDenied
        case LIBSSH2_FX_FAILURE: return .failure
        case LIBSSH2_FX_BAD_MESSAGE: return .badMessage
        case LIBSSH2_FX_NO_CONNECTION: return .noConnection
        case LIBSSH2_FX_CONNECTION_LOST: return .connectionLost
        case LIBSSH2_FX_OP_UNSUPPORTED: return .operationUnsupported
        case LIBSSH2_FX_INVALID_HANDLE: return .invalidHandle
        case LIBSSH2_FX_NO_SUCH_PATH: return .noSuchPath
        case LIBSSH2_FX_FILE_ALREADY_EXISTS: return .fileAlreadyExists
        case LIBSSH2_FX_WRITE_PROTECT: return .writeProtect
        case LIBSSH2_FX_NO_MEDIA: return .noMedia
        case LIBSSH2_FX_NO_SPACE_ON_FILESYSTEM: return .noSpaceOnFilesystem
        case LIBSSH2_FX_QUOTA_EXCEEDED: return .quotaExceeded
        case LIBSSH2_FX_UNKNOWN_PRINCIPAL: return .unknownPrincipal
        case LIBSSH2_FX_LOCK_CONFLICT: return .lockConflict
        case LIBSSH2_FX_DIR_NOT_EMPTY: return .directoryNotEmpty
        case LIBSSH2_FX_NOT_A_DIRECTORY: return .notADirectory
        case LIBSSH2_FX_INVALID_FILENAME: return .invalidFilename
        case LIBSSH2_FX_LINK_LOOP: return .linkLoop
        default: return .unknown
        }
    }
    
}

extension Libssh2 {

    fileprivate class Session: RawSession {

        var session: OpaquePointer!
        var keyboardInteractiveCallback: ((String) -> String)?
        var lastError: Error {
            return libssh2_session_last_errno(self.session).error
        }

        init?() {
            // Initialize libssh2
            guard libssh2_init(0) == 0 else {
                return nil
            }

            // Create session instance
            self.session = libssh2_session_init_ex(nil, nil, nil, UnsafeMutableRawPointer(mutating: Unmanaged.passUnretained(self).toOpaque()))
            guard self.session != nil else {
                return nil
            }

            // Get the libssh2 version
            Libssh2.version = String(cString: libssh2_version(0))
            
            // Set libssh2 callbacks
            libssh2_setup_session_callbacks(UnsafeMutableRawPointer(self.session))
        }

        var authenticated: Bool {
            guard let session = self.session else {
                return false
            }

            return libssh2_userauth_authenticated(session) == 1
        }

        var blocking: Bool {
            set {
                if let session = self.session  {
                    libssh2_session_set_blocking(session, newValue ? 1 : 0)
                }
            }
            get {
                guard let session = self.session else {
                    return false
                }

                return libssh2_session_get_blocking(session) == 1
            }
        }

        var timeout: Int {
            set {
                if let session = self.session  {
                    libssh2_session_set_timeout(session, newValue)
                }
            }
            get {
                guard let session = self.session else {
                    return Int.max
                }

                return libssh2_session_get_timeout(session)
            }
        }

        var banner: String? {
            guard let session = self.session else {
                return nil
            }

            return String(cString: libssh2_session_banner_get(session))
        }

        func setBanner(_ banner: String) throws {
            try libssh2_function {
                banner.withCString({ libssh2_session_banner_set(self.session, $0) })
            }
        }

        func handshake(_ socket: CFSocket) throws {
            try libssh2_function {
                libssh2_session_handshake(self.session, CFSocketGetNative(socket))
            }
        }

        func fingerprint(_ hashType: FingerprintHashType) -> String? {
            let type: Int32
            let length: Int

            switch hashType {
                case .md5:
                    type = LIBSSH2_HOSTKEY_HASH_MD5
                    length = 16
                case .sha1:
                    type = LIBSSH2_HOSTKEY_HASH_SHA1
                    length = 20
            }

            guard let hashPointer = libssh2_hostkey_hash(self.session, type) else {
                return nil
            }
            
            let hash = UnsafeRawPointer(hashPointer).assumingMemoryBound(to: UInt8.self)
            
            return (0..<length).map({ String(hash[$0], radix: 16, uppercase: true) }).joined(separator: ":")
        }

        func authenticationList(_ username: String) throws -> [String] {
            assert(self.session != nil)
            assert(self.blocking)
            
            guard let authenticationList = libssh2_userauth_list(self.session, username, UInt32(username.utf8.count)), let authenticationString = String(validatingUTF8: authenticationList) else {
                if self.authenticated {
                    return []
                } else {
                    throw self.lastError
                }
            }

            return authenticationString.components(separatedBy: ",")
        }

        func authenticateByPassword(_ username: String, password: String) throws {
            try libssh2_function {
                libssh2_userauth_password_ex(self.session, username, UInt32(username.utf8.count), password, UInt32(password.utf8.count), nil)
            }
        }

        func authenticateByKeyboardInteractive(_ username: String, callback: @escaping ((String) -> String)) throws {
            self.keyboardInteractiveCallback = callback

            try libssh2_function {
                libssh2_userauth_keyboard_interactive_ex(self.session, username, UInt32(username.utf8.count), { (name, nameLength, instruction, instructionLength, numberOfPrompts, prompts, responses, abstract) in
                    for i in 0..<Int(numberOfPrompts) {
                        guard let prompt = prompts?[i], let text = prompt.text else {
                            continue
                        }
                        
                        let data = Data(bytes: UnsafeRawPointer(text), count: Int(prompt.length))
                        
                        guard let challenge = String(data: data, encoding: .utf8) else {
                            continue
                        }
                        
                        let abstractSelf = UnsafeRawPointer(abstract!).assumingMemoryBound(to: Libssh2.Session.self).pointee
                        guard let keyboardInteractiveCallback = abstractSelf.keyboardInteractiveCallback else {
                            print("Keyboard interactive callback is nil")
                            return
                        }

                        let password = keyboardInteractiveCallback(challenge)
                        let response = password.withCString {
                             LIBSSH2_USERAUTH_KBDINT_RESPONSE(text: strdup($0), length: UInt32(strlen(password)))
                        }
                        
                        responses?[i] = response
                    }
                })
            }
        }

        func authenticateByPublicKeyFromFile(_ username: String, password: String, publicKey: String?, privateKey: String) throws {
            try libssh2_function {
                libssh2_userauth_publickey_fromfile_ex(self.session, username, UInt32(username.utf8.count), publicKey, privateKey, password)
            }
        }
        
        func authenticateByPublicKeyFromMemory(_ username: String, password: String, publicKey: Data?, privateKey: Data) throws {
            try libssh2_function {
                privateKey.withUnsafeBytes { (privateKeyPointer: UnsafePointer<Int8>) -> Int32 in
                    if let publicKey = publicKey {
                        return publicKey.withUnsafeBytes { publicKeyPointer in
                            libssh2_userauth_publickey_frommemory(self.session, username, username.utf8.count, publicKeyPointer, publicKey.count, privateKeyPointer, privateKey.count, password)
                        }
                    } else {
                        return libssh2_userauth_publickey_frommemory(self.session, username, username.utf8.count, nil, 0, privateKeyPointer, privateKey.count, password)
                    }
                }
            }
        }

        func disconnect() throws {
            try libssh2_function {
                libssh2_session_disconnect_ex(self.session, SSH_DISCONNECT_BY_APPLICATION, "SwiftSH: Disconnect", "")
            }
        }

    }

}

extension Libssh2 {

    fileprivate class Channel: RawChannel {

        var session: OpaquePointer
        var channel: OpaquePointer?
        var bufferSize: Int = 32_768

        var opened: Bool {
            return self.channel != nil
        }

        var receivedEOF: Bool {
            guard let channel = self.channel else {
                return false
            }
            return libssh2_channel_eof(channel) == 1
        }

        init(session: OpaquePointer) {
            self.session = session
        }

        deinit {
            if let channel = self.channel {
                libssh2_channel_free(channel)
            }
        }

        func openChannel() throws {
            let channelType = "session"
            self.channel = try libssh2_function(self.session) { session in
                libssh2_channel_open_ex(session, channelType, UInt32(channelType.utf8.count), 2 * 1024 * 1024, UInt32(LIBSSH2_CHANNEL_PACKET_DEFAULT), nil, 0)
            }
        }
        
        func openSCPChannel(remotePath path: String) throws {
            var fileInfo = libssh2_struct_stat()
            self.channel = try libssh2_function(self.session) { session in
                libssh2_scp_recv2(session, path, &fileInfo)
            }
        }

        func setEnvironment(_ environment: Environment) throws {
            guard let channel = self.channel else {
                throw SSHError.Channel.invalid
            }

            try libssh2_function {
                libssh2_channel_setenv_ex(channel, environment.name, UInt32(environment.name.utf8.count), environment.variable, UInt32(environment.variable.utf8.count))
            }
        }

        func requestPseudoTerminal(_ terminal: Terminal) throws {
            guard let channel = self.channel else {
                throw SSHError.Channel.invalid
            }

            try libssh2_function {
                libssh2_channel_request_pty_ex(channel, terminal.name, UInt32(terminal.name.utf8.count), nil, 0, Int32(terminal.width), Int32(terminal.height), LIBSSH2_TERM_WIDTH_PX, LIBSSH2_TERM_HEIGHT_PX)
            }
        }

        func setPseudoTerminalSize(_ terminal: Terminal) throws {
            guard let channel = self.channel else {
                throw SSHError.Channel.invalid
            }

            try libssh2_function {
                libssh2_channel_request_pty_size_ex(channel, Int32(terminal.width), Int32(terminal.height), 0, 0)
            }
        }

        func closeChannel() throws {
            if let channel = self.channel {
                do {
                    try libssh2_function { libssh2_channel_close(channel) }
                    try libssh2_function { libssh2_channel_wait_closed(channel) }
                } catch {

                }

                try libssh2_function { libssh2_channel_free(channel) }
            }

            self.channel = nil
        }

        func exec(_ command: String) throws {
            try self.processStartup("exec", message: command)
        }

        func shell() throws {
            try self.processStartup("shell", message: nil)
        }

        func processStartup(_ type: String, message: String?) throws {
            guard let channel = self.channel else {
                throw SSHError.Channel.invalid
            }

            if let message = message {
                try libssh2_function {
                    message.withCString {
                        libssh2_channel_process_startup(channel, type, UInt32(type.utf8.count), $0, UInt32(message.utf8.count))
                    }
                }
            } else {
                try libssh2_function {
                    libssh2_channel_process_startup(channel, type, UInt32(type.utf8.count), nil, 0)
                }
            }
        }

        func read() throws -> Data {
            return try self.read(0)
        }

        func readError() throws -> Data {
            return try self.read(SSH_EXTENDED_DATA_STDERR)
        }

        func read(_ streamID: Int32) throws -> Data {
            guard let channel = self.channel else {
                throw SSHError.Channel.invalid
            }

            let bufferSize = self.bufferSize
            let buffer = UnsafeMutablePointer<Int8>.allocate(capacity: bufferSize)
            defer {
                buffer.deallocate()
            }

            var data = Data()

            var returnCode: Int
            repeat {
                returnCode = libssh2_channel_read_ex(channel, streamID, buffer, bufferSize)

                guard returnCode >= 0 || returnCode == Int(LIBSSH2_ERROR_EAGAIN) else {
                    throw returnCode.error
                }

                if returnCode > 0 {
                    buffer.withMemoryRebound(to: UInt8.self, capacity: returnCode) {
                        data.append(UnsafePointer($0), count: returnCode)
                    }
                }
            } while returnCode > 0 || (returnCode == 0 && libssh2_channel_eof(channel) == 0)

            return data
        }

        func write(_ data: Data) -> (error: Error?, bytesSent: Int) {
            guard let channel = self.channel else {
                return (error: SSHError.Channel.invalid, bytesSent: 0)
            }

            var bytesSent = 0
            repeat {
                let length = min(data.count - bytesSent, self.bufferSize)
                let returnCode = data.withUnsafeBytes { buffer in
                    libssh2_channel_write_ex(channel, 0, buffer + bytesSent, length)
                }

                guard returnCode >= 0 || returnCode == Int(LIBSSH2_ERROR_EAGAIN) else {
                    return (error: returnCode.error, bytesSent: bytesSent)
                }

                if returnCode > 0 {
                    bytesSent += returnCode
                }
            } while bytesSent < data.count
            
            return (error: nil, bytesSent: bytesSent)
        }

        func exitStatus() -> Int? {
            guard let channel = self.channel else {
                return nil
            }

            let exitStatus = libssh2_channel_get_exit_status(channel)

            return exitStatus == 0 ? nil : Int(exitStatus)
        }

        func sendEOF() throws {
            guard let channel = self.channel else {
                throw SSHError.Channel.invalid
            }

            try libssh2_function {
                libssh2_channel_send_eof(channel)
            }
        }

    }

}

private func libssh2_success(_ function: () -> Int32) -> Bool {
    var returnCode: Int32
    repeat {
        returnCode = function()
    } while returnCode == LIBSSH2_ERROR_EAGAIN

    return returnCode == 0
}

private func libssh2_function(_ function: () -> Int32) throws {
    var returnCode: Int32
    repeat {
        returnCode = function()
    } while returnCode == LIBSSH2_ERROR_EAGAIN

    guard returnCode == 0 else {
        throw returnCode.error
    }
}

private func libssh2_function<T>(_ session: OpaquePointer, function: (OpaquePointer) -> T?) throws -> T {
    var result: T?
    var returnCode: Int32
    repeat {
        result = function(session)
        returnCode = libssh2_session_last_errno(session)
    } while returnCode == LIBSSH2_ERROR_EAGAIN

    guard result != nil else {
        throw returnCode.error
    }

    return result!
}
