Pod::Spec.new do |spec|
  spec.name         = "Nubrick"
  spec.version      = "0.16.4"
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

  spec.source       = { :http => "https://github.com/plaidev/nubrick-ios/releases/download/v0.16.4/Nubrick.xcframework.zip",
                        :sha256 => "6089c3af92740a175dc20e4fa987ce5d9f33df653e179d59b21a675dae72e5db" }

  spec.vendored_frameworks = "Nubrick.xcframework"
end
