Pod::Spec.new do |spec|
  spec.name         = "Nubrick"
  spec.version      = "0.13.3"
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

  spec.source       = { :http => "https://storage.googleapis.com/cdn.nativebrik.com/sdk/spm/Nubrick/Nubrick.xcframework.zip",
                        :sha256 => "2d0d5151ca4954d131224b6d909c2df1d112064ec5ddb77cc25da326eee2b9f0" }

  spec.vendored_frameworks = "Nubrick.xcframework"
end
