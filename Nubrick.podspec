Pod::Spec.new do |spec|
  spec.name         = "Nubrick"
  spec.version      = "0.17.1"
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

  spec.source       = { :http => "https://github.com/plaidev/nubrick-ios/releases/download/v0.17.1/Nubrick.xcframework.zip",
                        :sha256 => "efd5b0a09db8973b413ad4a036cdb918cd7f40e5d0f346cadbfcd95a8b5e66c5" }

  spec.vendored_frameworks = "Nubrick.xcframework"
end
