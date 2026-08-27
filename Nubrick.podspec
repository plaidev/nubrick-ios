Pod::Spec.new do |spec|
  spec.name         = "Nubrick"
  spec.version      = "0.19.11"
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

  spec.source       = { :http => "https://github.com/plaidev/nubrick-ios/releases/download/v0.19.11/Nubrick.xcframework.zip",
                        :sha256 => "ff8f5d1b03fa9545e05d41e7c6797d3db63ced69536383d71179e733c42239fd" }

  spec.vendored_frameworks = "Nubrick.xcframework"
end
