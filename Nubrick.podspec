Pod::Spec.new do |spec|
  spec.name         = "Nubrick"
  spec.version      = "0.14.0"
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

  spec.source       = { :http => "https://github.com/plaidev/nubrick-ios/releases/download/v0.14.0/Nubrick.xcframework.zip",
                        :sha256 => "314094e84355ecc7f5159aa8d00db8594e6c15513653cb7bf3cd6a4eef1c38f5" }

  spec.vendored_frameworks = "Nubrick.xcframework"
end
