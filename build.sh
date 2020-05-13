config=Debug
mac=false
ios=true
includessh=false
while test x$1 != x; do
    case $1 in
	--includessh)
	    includessh=true
	    ;;
	--config=*)
	    config=`echo $1 | sed 's/--config=//'`
	    ;;
	--mac)
	    ios=false
	    mac=true
	    ;;
	--help)
	    echo "--config=[Debug|Release] Specifies the build configuration"
	    echo "--includessh             To include a fresh build of iSSH2"
	    echo "--mac                    Build for Mac, default is for iOS"
	    exit 0
    esac
    shift
done
    
build_dir=local-build
rm -rf $build_dir macoslib
if $mac; then
    mkdir macoslib
fi
if $includessh; then
    cd ../iSSH2
    $ios && ./iSSH2.sh --platform=iphoneos  --no-clean  --min-version=11.0
    $mac && ./iSSH2.sh --platform=macosx  --no-clean --sdk-version=10.15 --min-version=10.15
fi

$ios && cp ../iSSH2/libssh2_iphoneos/include/* libssh2/libssh2
$ios && cp ../iSSH2/libssh2_iphoneos/lib/* libssh2/
$mac && cp ../iSSH2/*_macosx/lib/* macoslib

$ios && xcodebuild -project SwiftSH.xcodeproj ONLY_ACTIVE_ARCH=NO -configuration $config -scheme SwiftSH  -sdk iphoneos -arch arm64 -arch arm64e BUILD_DIR=local-build
$ios && xcodebuild -project SwiftSH.xcodeproj ONLY_ACTIVE_ARCH=NO -configuration $config -scheme SwiftSH  -sdk iphonesimulator BUILD_DIR=local-build
$mac && xcodebuild -project SwiftSH.xcodeproj ONLY_ACTIVE_ARCH=NO -configuration $config -scheme SwiftSH  -sdk macosx BUILD_DIR=local-build LIBRARY_SEARCH_PATHS=`pwd`/macoslib

rm -rf SwiftSH.framework
if $ios; then
  cp -R $build_dir/$config-iphoneos/SwiftSH.framework .
  cp -Ri $build_dir/$config-iphonesimulator/SwiftSH.framework/Modules/SwiftSH.swiftmodule/ SwiftSH.framework/Modules/SwiftSH.swiftmodule/
  lipo -create -output SwiftSH.framework/SwiftSH $build_dir/$config-*/SwiftSH.framework/SwiftSH
  echo Framework in ./SwiftSH.framework
fi
if $mac; then
    echo Framework in $build-dir/
fi
