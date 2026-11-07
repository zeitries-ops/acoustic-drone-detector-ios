Pod::Spec.new do |s|
  s.name             = 'drone_audio'
  s.version          = '1.0.0'
  s.summary          = 'Background microphone capture and alerts for Drone Kulagi.'
  s.description      = 'Captures the microphone at 16 kHz in the background and posts local notifications.'
  s.homepage         = 'https://github.com/zeitries-ops/acoustic-drone-detector-ios'
  s.license          = { :type => 'Proprietary', :text => 'All rights reserved.' }
  s.author           = { 'Drone Kulagi' => 'dronekulagi@users.noreply.github.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '13.0'
  s.frameworks       = 'AVFoundation', 'AudioToolbox', 'UserNotifications'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version    = '5.0'
end
