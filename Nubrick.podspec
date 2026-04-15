Pod::Spec.new do |spec|
  spec.name         = "Nubrick"
  spec.version      = "0.17.2"
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

  spec.source       = { :http => "https://github.com/plaidev/nubrick-ios/releases/download/v0.17.2/Nubrick.xcframework.zip",
                        :sha256 => "41bbcb5bc1e0b3dc3e098245502311dfca95abb80bac8b801d3ba721152e905a" }

  spec.vendored_frameworks = "Nubrick.xcframework"
end
