Pod::Spec.new do |spec|
  spec.name         = "Nubrick"
  spec.version      = "0.15.0"
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

  spec.source       = { :http => "https://github.com/plaidev/nubrick-ios/releases/download/v0.15.0/Nubrick.xcframework.zip",
                        :sha256 => "72015102a48fa88256f6aec27acc9a0bad273c3d47ae1d2400584c4a347fc98f" }

  spec.vendored_frameworks = "Nubrick.xcframework"
end
