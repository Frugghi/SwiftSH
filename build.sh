config=Debug
includessh=false
while test x$1 != x; do
    case $1 in
	--includessh)
	    includessh=true
	    ;;
	--config=*)
	    config=`echo $1 | sed 's/--config=//'`
	    ;;
	--help)
	    echo "--config=[Debug|Release] Specifies the build configuration"
	    echo "--includessh             To include a fresh build of iSSH2"
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
    ./iSSH2.sh --platform=iphoneos  --no-clean  --min-version=11.0
    ./iSSH2.sh --platform=macosx  --no-clean --sdk-version=10.15 --min-version=10.15
fi

cp ../iSSH2/libssh2_iphoneos/include/* libssh2/libssh2
cp ../iSSH2/libssh2_iphoneos/lib/* libssh2/
cp ../iSSH2/*_macosx/lib/* macoslib


# Could be empty, for now use this, since we do not have armv7 builds of libssh2 copied
IOS_ARCHS="-arch arm64 -arch arm64e"

# Parameters
#  $1 name used to construct the archivePath (local-build/$1.xcarchive)
#  $2 sdk to use
xcode_platform_archive_build()
{
    _name=$1; shift
    _sdk=$1; shift
    xcodebuild archive -scheme SwiftSH 			\
	       -project SwiftSH.xcodeproj 		\
	       ONLY_ACTIVE_ARCH=NO 			\
	       SKIP_INSTALL=NO 				\
	       BUILD_LIBRARIES_FOR_DISTRIBUTION=YES 	\
	       -sdk $_sdk 				\
	       -archivePath local-build/$_name.xcarchive\
	       -derivedDataPath /tmp/build-$_name	\
	       $*
}

xcode_platform_archive_build ios iphoneos $IOS_ARCHS
xcode_platform_archive_build iossimulator iphonesimulator
xcode_platform_archive_build mac macosx LIBRARY_SEARCH_PATHS=`pwd`/macoslib

frameworks=`for x in $(echo local-build/*xcarchive/Products/Library/Frameworks/SwiftSH.framework); do echo -n "-framework $x "; done`

xcodebuild -create-xcframework $frameworks -output SwiftSH.xcframework
