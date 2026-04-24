Pod::Spec.new do |spec|
  spec.name         = "Nubrick"
  spec.version      = "0.18.1"
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

  spec.source       = { :http => "https://github.com/plaidev/nubrick-ios/releases/download/v0.18.1/Nubrick.xcframework.zip",
                        :sha256 => "c5f6be2681a3adbd79159b35022237b814601b6b166da71b9baeade6156a7cae" }

  spec.vendored_frameworks = "Nubrick.xcframework"
end
