Pod::Spec.new do |spec|
  spec.name         = "Nubrick"
  spec.version      = "0.17.0"
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

  spec.source       = { :http => "https://github.com/plaidev/nubrick-ios/releases/download/v0.17.0/Nubrick.xcframework.zip",
                        :sha256 => "0887c4e9e645fb5fcd2dbbc4709c53d81bfa5446a3f6f380c55d699251436c4f" }

  spec.vendored_frameworks = "Nubrick.xcframework"
end
