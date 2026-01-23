Pod::Spec.new do |spec|
  spec.name         = "Nubrick"
  spec.version      = "0.15.1"
  spec.summary      = "Nubrick SDK for iOS"
  spec.description  = <<-DESC
                   Nubrick SDK for iOS.
                   DESC

  spec.homepage     = "https://docs.nativebrik.com"
  # spec.screenshots  = "www.example.com/screenshots_1.gif", "www.example.com/screenshots_2.gif"
  spec.license      = { :type => "Apache-2.0", :file => "LICENSE" }
  spec.author       = { "Nubrick" => "dev.share+nubrick@plaid.co.jp" }

  spec.platform     = :ios
  spec.ios.deployment_target = "13.4"

  spec.source       = { :http => "https://github.com/plaidev/nubrick-ios/releases/download/v0.15.1/Nubrick.xcframework.zip",
                        :sha256 => "6065f86f3881c006ee3899b8e56e6115a74aa56174734ca87030d968abef6087" }

  spec.vendored_frameworks = "Nubrick.xcframework"
end
