Pod::Spec.new do |spec|
  spec.name         = "Nubrick"
  spec.version      = "0.19.21"
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

  spec.source       = { :http => "https://github.com/plaidev/nubrick-ios/releases/download/v0.19.21/Nubrick.xcframework.zip",
                        :sha256 => "4fd22486eb2960e40e2ce27c12c95f69090661754d0bead9881e2c257a3597a9" }

  spec.vendored_frameworks = "Nubrick.xcframework"
end
