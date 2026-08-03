Pod::Spec.new do |spec|
  spec.name         = "Nubrick"
  spec.version      = "0.19.4"
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

  spec.source       = { :http => "https://github.com/plaidev/nubrick-ios/releases/download/v0.19.4/Nubrick.xcframework.zip",
                        :sha256 => "ec81776d1bf11fc9d8eeb3a5fd34698c781c4d12119dd93064a1d9ed64acf31f" }

  spec.vendored_frameworks = "Nubrick.xcframework"
end
