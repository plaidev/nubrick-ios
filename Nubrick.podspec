Pod::Spec.new do |spec|
  spec.name         = "Nubrick"
  spec.version      = "0.18.5"
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

  spec.source       = { :http => "https://github.com/plaidev/nubrick-ios/releases/download/v0.18.5/Nubrick.xcframework.zip",
                        :sha256 => "9a1c489f2f16bfb287e66e01d17bfe4e907d05703008e82f418beb74f1c477d5" }

  spec.vendored_frameworks = "Nubrick.xcframework"
end
