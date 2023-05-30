Pod::Spec.new do |s|
  s.name             = 'Nativebrik'
  s.version          = '0.1.0'
  s.summary          = 'Nativebrik SDK'
  s.description      = <<-DESC

                       DESC

  s.homepage         = 'https://github.com/14113526/Nativebrik'
  s.license          = { :type => 'Apache', :file => 'LICENSE' }
  s.author           = { '14113526' => 'RyosukeCla@users.noreply.github.com' }
  s.source           = { :git => 'https://github.com/plaidev/nativebrik-sdk.git', :tag => s.version.to_s }

  s.ios.deployment_target = '16.4'

  s.source_files = 'ios/Nativebrik/Classes/**/*'

  s.frameworks = 'UIKit', 'Foundation'
  s.dependency 'YogaKit', '~> 1.18'
end
