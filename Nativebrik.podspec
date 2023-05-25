Pod::Spec.new do |s|
  s.name             = 'Nativebrik'
  s.version          = '0.1.0'
  s.summary          = 'A short description of Nativebrik.'
  s.description      = <<-DESC
TODO: Add long description of the pod here.
                       DESC

  s.homepage         = 'https://github.com/14113526/Nativebrik'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { '14113526' => 'RyosukeCla@users.noreply.github.com' }
  s.source           = { :git => 'https://github.com/plaidev/nativebrik-sdk.git', :tag => s.version.to_s }

  s.ios.deployment_target = '15.0'

  s.source_files = 'ios/Nativebrik/Classes/**/*'

  s.frameworks = 'UIKit', 'Foundation'
  s.dependency 'YogaKit', '~> 1.7'
end
