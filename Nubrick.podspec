Pod::Spec.new do |spec|
  spec.name         = "Nubrick"
  spec.version      = "0.18.2"
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

  spec.source       = { :http => "https://github.com/plaidev/nubrick-ios/releases/download/v0.18.2/Nubrick.xcframework.zip",
                        :sha256 => "2bd50bf24a912aa09addfabb83e367526ff3efbe071c660be98d8a1441734683" }

  spec.vendored_frameworks = "Nubrick.xcframework"
end
