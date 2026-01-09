Pod::Spec.new do |spec|
  spec.name         = "Nubrick"
  spec.version      = "0.14.5"
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

  spec.source       = { :http => "https://github.com/plaidev/nubrick-ios/releases/download/v0.14.5/Nubrick.xcframework.zip",
                        :sha256 => "21166ed92b038e37e055d6f888b332a0b07b9e4c0b40bf6bd1ae0f5bb93dbc7a" }

  spec.vendored_frameworks = "Nubrick.xcframework"
end
