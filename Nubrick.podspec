Pod::Spec.new do |spec|
  spec.name         = "Nubrick"
  spec.version      = "0.16.1"
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

  spec.source       = { :http => "https://github.com/plaidev/nubrick-ios/releases/download/v0.16.1/Nubrick.xcframework.zip",
                        :sha256 => "96006e9482ac29e678f73d8f89012927170b63d027487aa7dfebd39f20ae2b85" }

  spec.vendored_frameworks = "Nubrick.xcframework"
end
