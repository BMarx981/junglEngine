#
# Platform audio decoding for junglEngine. See ../README.md.
#
Pod::Spec.new do |s|
  s.name             = 'junglengine_decode'
  s.version          = '0.1.0'
  s.summary          = 'Platform audio decoding for junglEngine.'
  s.description      = <<-DESC
Decodes audio files to interleaved 32 bit float PCM with AVFoundation.
                       DESC
  s.homepage         = 'https://hawkstreak.app'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Hawkstreak' => 'b.marx981@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'junglengine_decode/Sources/junglengine_decode/**/*.swift'
  s.swift_version    = '5.0'

  s.ios.dependency 'Flutter'
  s.osx.dependency 'FlutterMacOS'
  s.ios.deployment_target = '15.0'
  s.osx.deployment_target = '10.14'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }
end
