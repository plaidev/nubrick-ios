Pod::Spec.new do |spec|
  spec.name         = "Nubrick"
  spec.version      = "0.18.0"
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

  spec.source       = { :http => "https://github.com/plaidev/nubrick-ios/releases/download/v0.18.0/Nubrick.xcframework.zip",
                        :sha256 => "f59ceaeb15a9430e4a30683ae168dccc76f15d75f45b8f056b89d2e704ba07d7" }

  spec.vendored_frameworks = "Nubrick.xcframework"
end
