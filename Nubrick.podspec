Pod::Spec.new do |spec|
  spec.name         = "Nubrick"
  spec.version      = "0.19.6"
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

  spec.source       = { :http => "https://github.com/plaidev/nubrick-ios/releases/download/v0.19.6/Nubrick.xcframework.zip",
                        :sha256 => "5fa773132daae9e68cd387fc2792ead980984224b3f0086e76fb6b92ac19e176" }

  spec.vendored_frameworks = "Nubrick.xcframework"
end
