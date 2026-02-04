Pod::Spec.new do |spec|
  spec.name         = "Nubrick"
  spec.version      = "0.15.3"
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

  spec.source       = { :http => "https://github.com/plaidev/nubrick-ios/releases/download/v0.15.3/Nubrick.xcframework.zip",
                        :sha256 => "b769c01d4944256fa2d5af10a98ed63efc21320ce94c0d38b2af4f890c627fe0" }

  spec.vendored_frameworks = "Nubrick.xcframework"
end
