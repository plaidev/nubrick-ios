Pod::Spec.new do |spec|
  spec.name         = "Nubrick"
  spec.version      = "0.16.0"
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

  spec.source       = { :http => "https://github.com/plaidev/nubrick-ios/releases/download/v0.16.0/Nubrick.xcframework.zip",
                        :sha256 => "459e3d2d5edb9d67228c45c652710e9eb42bc37be1e7b097d82650c8c578af3a" }

  spec.vendored_frameworks = "Nubrick.xcframework"
end
