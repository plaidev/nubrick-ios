Pod::Spec.new do |spec|
  spec.name         = "Nubrick"
  spec.version      = "0.19.5"
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

  spec.source       = { :http => "https://github.com/plaidev/nubrick-ios/releases/download/v0.19.5/Nubrick.xcframework.zip",
                        :sha256 => "7aa184224eec3d9e55843dc154734844b04a38ea50e94b3fe0a741a188c29da8" }

  spec.vendored_frameworks = "Nubrick.xcframework"
end
