Pod::Spec.new do |s|
  s.name             = 'Nativebrik'
  s.version          = '0.11.1'
  s.summary          = 'Nativebrik SDK'
  s.description      = <<-DESC
Nativebrik SDK for iOS.
                       DESC

  s.homepage         = 'https://nativebrik.com'
  s.license          = { :type => 'Apache', :file => 'LICENSE' }
  s.author           = { 'Nativebrik' => 'dev.share+nativebrik@plaid.co.jp' }
  s.source           = { :git => 'https://github.com/plaidev/nativebrik-sdk.git', :tag => 'v' + s.version.to_s }

  s.swift_version = '5'
  s.platform = :ios
  s.ios.deployment_target = '14.0'

  s.source_files = 'ios/Nativebrik/Nativebrik/**/*'

  # common deps
  s.frameworks = 'UIKit', 'Foundation', 'SwiftUI', 'Combine', 'ImageIO', 'SafariServices'

  # >= ios 17.0
  s.weak_frameworks = 'TipKit'
  s.dependency 'YogaKit', '~> 2.0.0'
end
