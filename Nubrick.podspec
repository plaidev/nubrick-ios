Pod::Spec.new do |spec|
  spec.name         = "Nubrick"
  spec.version      = "0.12.4"
  spec.summary      = "Nubrick SDK for iOS"
  spec.description  = <<-DESC
                   Nubrick SDK for iOS.
                   DESC

  spec.homepage     = "https://docs.nativebrik.com"
  # spec.screenshots  = "www.example.com/screenshots_1.gif", "www.example.com/screenshots_2.gif"
  spec.license      = { :type => "Apache-2.0", :file => "LICENSE" }
  spec.author             = { "Nubrick" => "dev.share+nubrick@plaid.co.jp" }

  spec.platform     = :ios
  spec.ios.deployment_target = "13.4"

  spec.source       = { :git => "https://github.com/plaidev/nubrick-ios.git", :tag => "v#{spec.version}" }

  spec.source_files  = "Sources/Nubrick/**/*.{swift,h,m}", "Sources/YogaKit/**/*.{h,m,mm,cpp}"
  spec.preserve_paths = "Sources/YogaKit/module.modulemap"
  spec.private_header_files = "Sources/YogaKit/include/YogaKit/**/*.h"

  spec.resource_bundles = {
    'Nubrick' => ['Sources/Nubrick/PrivacyInfo.xcprivacy']
  }

  spec.requires_arc = true
  spec.swift_version = "5.9"

  # Frameworks
  spec.frameworks = "UIKit", "Foundation", "SwiftUI", "Combine", "ImageIO", "SafariServices"
  spec.weak_frameworks = "TipKit"

  spec.xcconfig = {
    'HEADER_SEARCH_PATHS' => '"$(PODS_TARGET_SRCROOT)/Sources/YogaKit/include"',
    'SWIFT_INCLUDE_PATHS' => '"$(PODS_TARGET_SRCROOT)/Sources/YogaKit"'
  }

  spec.dependency "Yoga", "~> 3.2.1"
end
