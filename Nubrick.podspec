Pod::Spec.new do |spec|
  spec.name         = "Nubrick"
  spec.version      = "0.14.6"
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

  spec.source       = { :http => "https://github.com/plaidev/nubrick-ios/releases/download/v0.14.6/Nubrick.xcframework.zip",
                        :sha256 => "7befd9443b7926c2302ae6aee8c673b344336d92894750bb23670b0731a936cd" }

  spec.vendored_frameworks = "Nubrick.xcframework"
end
