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

// MARK: - CFSocket

internal extension CFSocket {

    func setSocketOption<T: BinaryInteger>(_ value: T, level: Int32, name: Int32) -> Bool {
        var value = value
        if setsockopt(CFSocketGetNative(self), level, name, &value, socklen_t(MemoryLayout.size(ofValue: value))) == -1 {
            return false
        }

        return true
    }

}

// MARK: - C Address

internal extension in_addr {

    var description: String? {
        var mutableSelf = self
        var address: String?
        let addressLength = Int(INET_ADDRSTRLEN)
        let stringBuffer = UnsafeMutablePointer<CChar>.allocate(capacity: addressLength)

        if inet_ntop(AF_INET, &mutableSelf, stringBuffer, socklen_t(addressLength)) != nil {
            address = String(cString: stringBuffer)
        }

        stringBuffer.deallocate()

        return address
    }

}

internal extension in6_addr {

    var description: String? {
        var mutableSelf = self
        var address: String?
        let addressLength = Int(INET6_ADDRSTRLEN)
        let stringBuffer = UnsafeMutablePointer<CChar>.allocate(capacity: addressLength)

        if inet_ntop(AF_INET6, &mutableSelf, stringBuffer, socklen_t(addressLength)) != nil {
            address = String(cString: stringBuffer)
        }

        stringBuffer.deallocate()

        return address
    }
    
}

// MARK: - GCD

internal extension DispatchQueue {

    func sync(_ block: () throws -> Void) throws {
        var error: Error?
        self.sync(execute: {
            do {
                try block()
            } catch let e {
                error = e
            }
        })
        if let error = error {
            throw error
        }
    }
    
    class func syncOnMain(_ block: () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.sync(execute: block)
        }
    }

}
