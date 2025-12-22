Pod::Spec.new do |spec|
  spec.name         = "Nubrick"
  spec.version      = "0.14.4"
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

  spec.source       = { :http => "https://github.com/plaidev/nubrick-ios/releases/download/v0.14.4/Nubrick.xcframework.zip",
                        :sha256 => "b23c3104194b320182158cc34ab130f0c02e67f4f4376fcdcf074be4d01d4223" }

  spec.vendored_frameworks = "Nubrick.xcframework"
end
