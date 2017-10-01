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

internal enum DNSError: Error {

    case failed
    case timeout
    case inProgress

}

internal class DNS {

    let hostname: String
    fileprivate(set) var resolving: Bool = false
    fileprivate let host: CFHost

    init(hostname: String) {
        self.hostname = hostname
        self.host = CFHostCreateWithName(kCFAllocatorDefault, hostname as CFString).takeRetainedValue()
    }

    deinit {
        CFHostSetClient(self.host, nil, nil)
    }

    func lookup(timeout: TimeInterval = 10.0) throws -> [Data] {
        guard !self.resolving else {
            throw DNSError.inProgress
        }

        var mutableSelf = self
        var context = CFHostClientContext()
        context.info = Unmanaged.passRetained(self).toOpaque()
        CFHostSetClient(self.host, {
            (theHost: CFHost, typeInfo: CFHostInfoType, error: UnsafePointer<CFStreamError>?, info: UnsafeMutableRawPointer?) -> () in
            Unmanaged<DNS>.fromOpaque(info!).takeUnretainedValue().resolving = false
            }, &context)

        let runLoop = CFRunLoopGetCurrent()
        CFHostScheduleWithRunLoop(self.host, runLoop!, CFRunLoopMode.defaultMode.rawValue)

        defer {
            self.resolving = false
            CFHostUnscheduleFromRunLoop(self.host, runLoop!, CFRunLoopMode.defaultMode.rawValue)
        }

        var error = CFStreamError()
        self.resolving = CFHostStartInfoResolution(self.host, .addresses, &error)

        let deadline = Date().addingTimeInterval(timeout)
        while self.resolving && Date() < deadline {
            CFRunLoopRunInMode(.defaultMode, 0.05, true)
        }

        guard !self.resolving else {
            throw DNSError.timeout
        }

        var hasBeenResolved: DarwinBoolean = false
        guard let rawAddresses = CFHostGetAddressing(self.host, &hasBeenResolved)?.takeUnretainedValue(),
              let addresses = rawAddresses as NSArray as? [Data], hasBeenResolved.boolValue else {
            throw DNSError.failed
        }
        
        return addresses
    }
    
}
