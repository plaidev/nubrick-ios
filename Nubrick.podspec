Pod::Spec.new do |spec|
  spec.name         = "Nubrick"
  spec.version      = "0.19.7"
  spec.summary      = "Nubrick SDK for iOS"
  spec.description  = <<-DESC
                   Nubrick SDK for iOS.
                   DESC

  spec.homepage     = "https://docs.nativebrik.com"
  # spec.screenshots  = "www.example.com/screenshots_1.gif", "www.example.com/screenshots_2.gif"
  spec.license      = { :type => "Apache-2.0", :file => "LICENSE" }
  spec.author       = { "Nubrick" => "nubrick-support@plaid.co.jp" }

  spec.platform     = :ios
  spec.ios.deployment_target = "15.0"

  spec.source       = { :http => "https://github.com/plaidev/nubrick-ios/releases/download/v0.19.7/Nubrick.xcframework.zip",
                        :sha256 => "d54bb69bb9d5f406d2cab8c1e6e736fce5ab480cbabf9d65a92de95eab1e9af6" }

  spec.vendored_frameworks = "Nubrick.xcframework"
end
