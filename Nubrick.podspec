Pod::Spec.new do |spec|
  spec.name         = "Nubrick"
  spec.version      = "0.14.3"
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

  spec.source       = { :http => "https://github.com/plaidev/nubrick-ios/releases/download/v0.14.3/Nubrick.xcframework.zip",
                        :sha256 => "4ea54bcdb92f6cb9b8e7637e69fe55a679a9581f47470e4829fe15b8c53b35f4" }

  spec.vendored_frameworks = "Nubrick.xcframework"
end
