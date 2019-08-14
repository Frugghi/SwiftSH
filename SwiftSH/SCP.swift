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

@available(*, unavailable)
public class SCPSession: SSHChannel {

    // MARK: - Download
    
    public func download(_ from: String, to path: String) -> Self {
        self.download(from, to: path, completion: nil)

        return self
    }

    public func download(_ from: String, to path: String, completion: SSHCompletionBlock?) {
        if let stream = OutputStream(toFileAtPath: path, append: false) {
            self.download(from, to: stream, completion: completion)
        } else if let completion = completion {
            self.queue.callbackQueue.async {
                completion(SSHError.SCP.invalidPath)
            }
        }
    }

    
    public func download(_ from: String, to stream: OutputStream) -> Self {
        self.download(from, to: stream, completion: nil)

        return self
    }

    public func download(_ from: String, to stream: OutputStream, completion: SSHCompletionBlock?) {
        self.queue.async(completion: completion) {
            stream.open()
            do {
                stream.close()
            }
        }
    }

    public func download(_ from: String, completion: @escaping ((Data?, Error?) -> Void)) {
        let stream = OutputStream.toMemory()
        self.download(from, to: stream) { error in
            if let data = stream.property(forKey: Stream.PropertyKey.dataWrittenToMemoryStreamKey) as? Data {
                completion(data, error)
            } else {
                completion(nil, error ?? SSHError.unknown)
            }
        }
    }

    // MARK: - Upload

}
