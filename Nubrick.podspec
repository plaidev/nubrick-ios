Pod::Spec.new do |spec|
  spec.name         = "Nubrick"
  spec.version      = "0.19.20"
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

  spec.source       = { :http => "https://github.com/plaidev/nubrick-ios/releases/download/v0.19.20/Nubrick.xcframework.zip",
                        :sha256 => "8c0a063374eba0ff79516f4896bc6ab73a89e1718136d1db09797fbd3bf5d45e" }

  spec.vendored_frameworks = "Nubrick.xcframework"
end
