#
# junglEngine's audio engine. The pod compiles the Rust crate and vendors what
# comes out; there is no Objective-C in it and no plugin class, because
# everything the app asks the engine goes over dart:ffi.
#
Pod::Spec.new do |s|
  s.name             = 'junglengine_engine'
  s.version          = '0.1.0'
  s.summary          = "junglEngine's audio engine."
  s.description      = <<-DESC
The mixer, the sub synth, the device and the C ABI between them, in Rust.
                       DESC
  s.homepage         = 'https://hawkstreak.app'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Hawkstreak' => 'hello@hawkstreak.app' }
  s.source           = { :path => '.' }
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'

  # There has to be a source file or CocoaPods will not build a target for the
  # pod at all, and then nothing links the engine in.
  s.source_files = 'Classes/**/*'

  # An xcframework rather than a plain archive: a device slice and a simulator
  # slice are different platforms, so they cannot share one static library.
  s.vendored_frameworks = 'junglengine_engine.xcframework'

  # `pod install` gets the framework built before it tries to vendor it.
  s.prepare_command = 'sh ../rust/build_apple.sh ios'

  # And every Xcode build rebuilds it, so editing Rust and hitting run works
  # the way editing Dart does. Cargo does nothing when nothing changed.
  s.script_phase = {
    :name => 'Build the junglEngine audio engine',
    :script => 'sh "$PODS_TARGET_SRCROOT/../rust/build_apple.sh" ios',
    :execution_position => :before_compile,
    :output_files => ['$(DERIVED_FILE_DIR)/junglengine_engine.stamp'],
  }

  # What cpal's CoreAudio backend calls into. A Rust static library carries no
  # link dependencies of its own, so the pod has to name them.
  s.frameworks = 'AudioToolbox', 'AVFoundation', 'CoreAudio', 'CoreFoundation', 'Foundation'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
  }
  s.swift_version = '5.0'
end
