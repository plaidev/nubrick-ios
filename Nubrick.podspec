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
                        :sha256 => "1993c1092c158a691591304f774e6ae2a43deaa405218c860d7b1e5f5533d8ca" }

  spec.vendored_frameworks = "Nubrick.xcframework"
end
