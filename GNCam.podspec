
#
# Be sure to run `pod lib lint GNCam.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'GNCam'
  s.version          = '0.2.2'
  s.summary          = 'A Swift 3 library that uses AVFoundation to interact with the camera on iOS.'
  s.description      = <<-DESC
GNCam is a Swift 3 library that uses AVFoundation to interact with the camera on iOS.
                        DESC

  s.documentation_url = 'https://gonzalonunez.github.io/GNCam'
  s.homepage          = 'https://github.com/gonzalonunez/GNCam'
  s.license           = { :type => 'MIT', :file => 'LICENSE' }
  s.author            = { 'gonzalonunez' => 'hello@gonzalonunez.me' }
  s.source            = { :git => 'https://github.com/gonzalonunez/GNCam.git', :tag => s.version.to_s }
  s.social_media_url  = 'https://twitter.com/gonzalo__nunez'

  s.ios.deployment_target = '9.0'

  s.source_files = 'GNCam/Source/**/*'
  s.resources = 'GNCam/Assets/**/*'

  s.frameworks = 'UIKit', 'AVFoundation', 'CoreMedia'

end
