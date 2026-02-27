Pod::Spec.new do |spec|
  spec.name         = "Nubrick"
  spec.version      = "0.16.2"
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

  spec.source       = { :http => "https://github.com/plaidev/nubrick-ios/releases/download/v0.16.2/Nubrick.xcframework.zip",
                        :sha256 => "7a58ca46a4d20760fdf2035f2384f88169684ce4f778a6f1f8ae8bcc5eb5406c" }

  spec.vendored_frameworks = "Nubrick.xcframework"
end
