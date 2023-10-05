
# how to archive with xcode 14.3

```sh
cd ./ios/Example
pod install
```

1. patch Yoga.cpp with ./Yoga.cpp.patch after pods installation. see post_install in ./Podfile.
2. patch frameworks.sh with ./frameworks.sh.patch after pods intstallation.
3. then, archive.

## Troubleshooting

> SDK does not contain 'libarclite' at the path '/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/arc/libarclite_iphonesimulator.a'; try increasing the minimum deployment target

```
cd /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/
sudo mkdir arc
cd arc
sudo git clone https://github.com/kamyarelyasi/Libarclite-Files.git .
sudo chmod +x *
```

## References
- https://stackoverflow.com/questions/16821838/how-to-patch-a-library-imported-with-cocoapods
- https://github.com/facebook/react-native/issues/36758
- https://stackoverflow.com/a/75924853