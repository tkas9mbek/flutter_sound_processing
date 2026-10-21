#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_sound_processing.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_sound_processing'
  s.version          = '1.0.0'
  s.summary          = 'Calculate MFCCs natively from samples, 16-bit PCM or audio files.'
  s.description      = <<-DESC
Flutter plugin that calculates MFCCs natively on Android and iOS from samples,
16-bit PCM or audio files (mp3, wav, m4a, flac).
                       DESC
  s.homepage         = 'https://github.com/tkas9mbek/flutter_sound_processing'
  s.license          = { :file => '../LICENSE' }
  s.author           = 'Kasymbek Tashbaev'
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.frameworks = 'AVFoundation'
  s.dependency 'RosaKit', '~> 0.0.11'
  s.platform = :ios, '15.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
