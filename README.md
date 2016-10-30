![Icon](https://github.com/gonzalonunez/GNCam/blob/master/GNCam%20Icon.png)
# GNCam

[![CI Status](http://img.shields.io/travis/gonzalonunez/GNCam.svg?style=flat)](https://travis-ci.org/gonzalonunez/GNCam)
[![Version](https://img.shields.io/cocoapods/v/GNCam.svg?style=flat)](http://cocoapods.org/pods/GNCam)
[![License](https://img.shields.io/cocoapods/l/GNCam.svg?style=flat)](http://cocoapods.org/pods/GNCam)
[![Platform](https://img.shields.io/cocoapods/p/GNCam.svg?style=flat)](http://cocoapods.org/pods/GNCam)

Part of a larger effort to open source [Giffy](https://appsto.re/us/gSgd2.i).

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Installation

GNCam is available through [CocoaPods](http://cocoapods.org). To use it, simply add `pod 'GNCam'` to your Podfile. Make sure that `use_frameworks!` is also in your Podfile.

It should look something like this:

```ruby
use_frameworks!

target '<MY_TARGET_NAME>' do
  pod 'GNCam'

  target '<MY_TEST_TARGET_NAME>' do
    inherit! :search_paths

  end
end
``````

## Author

Gonzalo Nuñez, hello@gonzalonunez.me

Twitter: [@gonzalo__nunez](https://twitter.com/gonzalo__nunez)

## License

GNCam is available under the MIT license. See the LICENSE file for more info.

## Notes

As of right now, this is simply a direct Swift 3 port of existing code that I had – the original code is like 2+ years old. In the future, I plan on ditching the "CaptureManager" approach and going with a more protocol-oriented compositional approach. Along with that change, there will need to be a few more things before I can call this v1.0:

1. Unit Tests with extensive code coverage
2. A cleaner example app that showcases the supported features

Also, more than anything this library gives me the ability to start up a photo/video app in a matter of seconds. With that being said, many of the features added to this will be influenced by goals I have with apps that use this. If for some reason this actually gets starred and used, other developers will be influencing that as well :)
