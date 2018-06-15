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

internal class Queue {

    fileprivate static var specific = DispatchSpecificKey<ObjectIdentifier>()
    fileprivate var objectIdentifier: ObjectIdentifier!

    let queue: DispatchQueue
    let callbackQueue: DispatchQueue = DispatchQueue.main
    var current: Bool {
        guard let specific = DispatchQueue.getSpecific(key: Queue.specific) else {
            return false
        }

        return specific == self.objectIdentifier
    }

    init(label: String, concurrent: Bool) {
        self.queue = DispatchQueue(label: label, qos: DispatchQoS.background, attributes: concurrent ? DispatchQueue.Attributes.concurrent : DispatchQueue.Attributes())

        self.objectIdentifier = ObjectIdentifier(self)
        self.queue.setSpecific(key: Queue.specific, value: self.objectIdentifier)
    }

    func async(_ block: @escaping () -> Void) {
        if self.current {
            block()
        } else {
            self.queue.async(execute: block)
        }
    }

    func async(completion: ((Error?) -> Void)?, block: @escaping () throws -> Void) {
        if self.current {
            do {
                try block()
                if let completion = completion {
                    self.callbackQueue.async(execute: {
                        completion(nil)
                    })
                }
            } catch let error {
                if let completion = completion {
                    self.callbackQueue.async(execute: {
                        completion(error)
                    })
                }
            }
        } else {
            self.queue.async(execute: { [weak self] in
                do {
                    try block()
                    if let completion = completion {
                        self?.callbackQueue.async(execute: {
                            completion(nil)
                        })
                    }
                } catch let error {
                    if let completion = completion {
                        self?.callbackQueue.async(execute: {
                            completion(error)
                        })
                    }
                }
            })
        }
    }

    func sync(_ block: @escaping () -> Void)  {
        if self.current {
            return block()
        } else {
            self.queue.sync(execute: block)
        }
    }

    func sync(_ block: @escaping () throws -> Void) throws {
        if self.current {
            try block()
        } else {
            try self.queue.sync(block)
        }
    }

    func sync<T>(_ block: @escaping () -> T) -> T {
        if self.current {
            return block()
        } else {
            var result: T!
            
            self.queue.sync(execute: {
                result = block()
            })

            return result
        }
    }

    func sync<T>(_ block: @escaping () throws -> T) throws -> T {
        if self.current {
            return try block()
        } else {
            var result: T!

            try self.queue.sync {
                result = try block()
            }

            return result
        }
    }

}
