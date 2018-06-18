Pod::Spec.new do |spec|
  spec.name             = 'SwiftSH'
  spec.version          = '0.1.2'
  spec.summary          = 'A Swift SSH framework that wraps libssh2.'
  spec.homepage         = 'https://github.com/Frugghi/SwiftSH'
  spec.license          = 'MIT'
  spec.authors          = { 'Tommaso Madonia' => 'tommaso@madonia.me' }
  spec.source           = { :git => 'https://github.com/Frugghi/SwiftSH.git', :tag => spec.version.to_s }

  spec.requires_arc     = true
  spec.default_subspec  = 'Libssh2'
  spec.swift_version    = '4.1'

  spec.ios.deployment_target = '8.0'

  spec.subspec 'Core' do |core|
      core.source_files = 'SwiftSH/*.swift'
      core.exclude_files = 'SwiftSH/Libssh2*'
  end

  spec.subspec 'Libssh2' do |libssh2|
      libssh2.dependency 'SwiftSH/Core'
      libssh2.libraries = 'z'
      libssh2.preserve_paths = 'libssh2'
      libssh2.source_files = 'SwiftSH/Libssh2*.{h,m,swift}'
      libssh2.pod_target_xcconfig = {
        'VALID_ARCHS[sdk=iphonesimulator*]' => 'x86_64',
        'SWIFT_INCLUDE_PATHS' => '$(PODS_ROOT)/SwiftSH/libssh2',
        'LIBRARY_SEARCH_PATHS' => '$(PODS_ROOT)/SwiftSH/libssh2',
        'HEADER_SEARCH_PATHS' => '$(PODS_ROOT)/SwiftSH/libssh2'
      }
  end

end
