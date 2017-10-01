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

public enum SSHError: Error {
    case unknown

    case bannerReceive
    case bannerSend
    case invalidMessageAuthenticationCode
    case decrypt
    case methodNone
    case requestDenied
    case methodNotSupported
    case invalid
    case agentProtocol
    case encrypt

    // Common
    case allocation
    case timeout
    case `protocol`
    case again
    case bufferTooSmall
    case badUse
    case compress
    case outOfBoundary

    // Connection
    case alreadyConnected
    case hostResolutionFailed
    case keyExchangeFailure
    case hostkey

    // Authentication
    case authenticationFailed
    case passwordExpired
    case publicKeyUnverified
    case publicKeyProtocol
    case publicKeyFile
    case unsupportedAuthenticationMethod
    case knownHosts

    // Socket
    public enum Socket: Error {
        case write
        case read
        case disconnected
        case timeout
        case invalid
    }

    // Channel
    public enum Channel: Error {
        case unknown
        case alreadyOpen
        case invalid
        case outOfOrder
        case failure
        case requestDenied
        case windowExceeded
        case packetExceeded
        case closed
        case sentEndOfFile
    }

    // SFTP
    public enum SFTP: Error {
        case unknown
        case invalidSession
        case endOfFile
        case noSuchFile
        case permissionDenied
        case failure
        case badMessage
        case noConnection
        case connectionLost
        case operationUnsupported
        case invalidHandle
        case noSuchPath
        case fileAlreadyExists
        case writeProtect
        case noMedia
        case noSpaceOnFilesystem
        case quotaExceeded
        case unknownPrincipal
        case lockConflict
        case directoryNotEmpty
        case notADirectory
        case invalidFilename
        case linkLoop
    }

    // SCP
    public enum SCP: Error {
        case `protocol`
        case invalidPath
    }

    // Command
    public enum Command: Error {
        case execError(String?, Data)
    }
}

public enum SSHDisconnectionCode: Int {
    case hostNotAllowedToConnect = 1
    case protocolError = 2
    case keyExchangeFailed = 3
    case reserved = 4
    case macError = 5
    case compressionError = 6
    case serviceNotAvailable = 7
    case protocolVersionNotSupported = 8
    case hostKeyNotVerifiable = 9
    case connectionLost = 10
    case byApplication = 11
    case tooManyConnections = 12
    case authenticationCancelledByUser = 13
    case noMoreAuthenticationMethodsAvailable = 14
    case illegalUserName = 15
}
