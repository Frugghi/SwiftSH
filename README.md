# SwiftSH
[![Build Status](https://travis-ci.org/Frugghi/SwiftSH.svg?branch=master)](https://travis-ci.org/Frugghi/SwiftSH)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![Pods](https://img.shields.io/cocoapods/v/SwiftSH.svg)](https://cocoapods.org/pods/SwiftSH)
[![Pod platforms](https://img.shields.io/cocoapods/p/SwiftSH.svg)](https://cocoapods.org/pods/SwiftSH)

A Swift SSH framework that wraps [libssh2](https://www.libssh2.org/).

**Features:**
- [x] Thread-safety
- [x] SSH shell
- [x] SSH command
- [ ] SCP
- [ ] SFTP
- [ ] Tests
- [ ] Documentation

## :package: Installation

### CocoaPods
[CocoaPods](https://cocoapods.org) is the dependency manager for Swift and Objective-C Cocoa projects. It has over ten thousand libraries and can help you scale your projects elegantly.

Add this to your *Podfile*:
```Ruby
use_frameworks!

pod 'SwiftSH'
```

### Carthage
[Carthage](https://github.com/Carthage/Carthage) builds your dependencies and provides you with binary frameworks, but you retain full control over your project structure and setup.

Add this to your *Cartfile*:
```Ruby
github "Frugghi/SwiftSH"
```

## :book: Documentation
The API documentation is available [here](https://frugghi.github.io/SwiftSH/).

## :computer: Usage
Import the framework:
```Swift
import SwiftSH
```

Execute a SSH command:
```Swift
let command = Command(host: "localhost", port: 22)
// ...
command.connect()
       .authenticate(.byPassword(username: "username", password: "password"))
       .execute(command) { (command, result: String?, error) in
           if let result = result {
               print("\(result)")
           } else {
               print("ERROR: \(error)")
           }
       }
```

Open a SSH shell:
```Swift
let shell = Shell(host: "localhost", port: 22)
// ...
shell.withCallback { (string: String?, error: String?) in
         print("\(string ?? error!)")
     }
     .connect()
     .authenticate(.byPassword(username: "username", password: "password"))
     .open { (error) in
         if let error = error {
             print("\(error)")
         }
     }
// ...
shell.write("ls -lA") { (error) in
    if let error = error {
        print("\(error)")
    }
}
// ...
shell.disconnect()
```

## :warning: OpenSSL and Libssh2 binaries
*SwiftSH* includes precompiled binaries of Libssh2 and OpenSSL generated with [this script](https://github.com/Frugghi/iSSH2). For security reasons, you are strongly encouraged to recompile the libraries and replace the binaries.

## :page_facing_up: License [![LICENSE](https://img.shields.io/cocoapods/l/SwiftSH.svg)](https://raw.githubusercontent.com/Frugghi/SwiftSH/master/LICENSE)
*SwiftSH* is released under the MIT license. See [LICENSE](https://raw.githubusercontent.com/Frugghi/SwiftSH/master/LICENSE) for details.
