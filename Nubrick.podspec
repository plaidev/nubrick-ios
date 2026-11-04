Pod::Spec.new do |spec|
  spec.name         = "Nubrick"
  spec.version      = "0.20.0"
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

  spec.source       = { :http => "https://github.com/plaidev/nubrick-ios/releases/download/v0.20.0/Nubrick.xcframework.zip",
                        :sha256 => "9da2f79b794c502deff71282faf72ea2bbb74a9cf0782f6c0196a8b0ef2fe069" }

  spec.vendored_frameworks = "Nubrick.xcframework"
end
