Pod::Spec.new do |spec|
  spec.name         = "Nubrick"
  spec.version      = "0.19.18"
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

  spec.source       = { :http => "https://github.com/plaidev/nubrick-ios/releases/download/v0.19.18/Nubrick.xcframework.zip",
                        :sha256 => "92efccf9f52ab8cdfb9a4b66147d17b466cada2e6335a7a904efa88a883b93ea" }

  spec.vendored_frameworks = "Nubrick.xcframework"
end
