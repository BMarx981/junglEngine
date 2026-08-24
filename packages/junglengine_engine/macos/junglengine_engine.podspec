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
  s.dependency 'FlutterMacOS'
  s.platform = :osx, '10.15'

  # There has to be a source file or CocoaPods will not build a target for the
  # pod at all, and then nothing links the engine in.
  s.source_files = 'Classes/**/*'

  # A plain fat archive: macOS has no simulator, so one library covers both
  # architectures.
  s.vendored_libraries = 'libjunglengine_engine.a'

  # `pod install` gets the framework built before it tries to vendor it.
  s.prepare_command = 'sh ../rust/build_apple.sh macos'

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
  s.frameworks = 'AudioToolbox', 'AudioUnit', 'CoreAudio', 'CoreFoundation', 'Foundation'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    
  }
  s.swift_version = '5.0'
end
