Pod::Spec.new do |spec|
  spec.name         = "Nubrick"
  spec.version      = "0.15.2"
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

  spec.source       = { :http => "https://github.com/plaidev/nubrick-ios/releases/download/v0.15.2/Nubrick.xcframework.zip",
                        :sha256 => "02a3bbb6039b7b5fa259db4704a62db37e7c3dd7877d8f5304c53c27ba17d177" }

  spec.vendored_frameworks = "Nubrick.xcframework"
end
