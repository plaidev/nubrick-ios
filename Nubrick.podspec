Pod::Spec.new do |spec|
  spec.name         = "Nubrick"
  spec.version      = "0.16.3"
  spec.summary      = "Nubrick SDK for iOS"
  spec.description  = <<-DESC
                   Nubrick SDK for iOS.
                   DESC

  spec.homepage     = "https://docs.nativebrik.com"
  # spec.screenshots  = "www.example.com/screenshots_1.gif", "www.example.com/screenshots_2.gif"
  spec.license      = { :type => "Apache-2.0", :file => "LICENSE" }
  spec.author       = { "Nubrick" => "nubrick-support@plaid.co.jp" }

  spec.platform     = :ios
  spec.ios.deployment_target = "13.4"

  spec.source       = { :http => "https://github.com/plaidev/nubrick-ios/releases/download/v0.16.3/Nubrick.xcframework.zip",
                        :sha256 => "0d1e21a3da3254db02847a31550e39aaf5679f719ab84c4ec3da8533ddb59a87" }

  spec.vendored_frameworks = "Nubrick.xcframework"
end
