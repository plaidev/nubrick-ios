Pod::Spec.new do |spec|
  spec.name         = "Nubrick"
  spec.version      = "0.14.2"
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

  spec.source       = { :http => "https://github.com/plaidev/nubrick-ios/releases/download/v0.14.2/Nubrick.xcframework.zip",
                        :sha256 => "f38c4b8daba4aea1ab9ac2aa0eba1bcad2564b3751fcb48dbc7a2335fe22003c" }

  spec.vendored_frameworks = "Nubrick.xcframework"
end
