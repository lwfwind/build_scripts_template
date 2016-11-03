#!/bin/bash
# this is config for daily build

source /etc/profile

SELF=$(cd $(dirname $0); pwd -P)/$(basename $0)
CURRENTDIR=$(cd $(dirname $0); pwd -P)
DATE=$(date +%y-%m-%d-%H-%M)
PGY_USER_KEY=XXXXXXXXXXXXXXXXXXXX
PGY_API_KEY=XXXXXXXXXXXXXXXXXXXXX
APP_SOURCE_ROOTDIR=/Users/mactest/Documents/git/develop/XXXXX
APP_MAIN_MODULE=XXXXXXXXXX
SDK_NAME=iphoneos10.0
PRODUCT_BUNDLE_IDENTIFIER='XXXXXXXXXXXXXXXXX'
CODE_SIGN_IDENTITY='XXXXXXXXXX'
PROVISIONING_PROFILE_NAME='XXXXXX'
TEAM_IDENTIFIER='XXXXXXXXXXXX'
PROVISIONING_PROFILE_UUID='XXXXXXXXXXXXXXXXXXXXXX'
APP_BUILD_DIR=$CURRENTDIR/build
APP_BUILD_LOGFILE=$CURRENTDIR/log/log.log
GIT_URL=git@XXXXX:xxxxxxxxxxx/XXXXX.git
GIT_HTTP_URL=http://XXXXX/XXXXXXXXXXX
rm -rf $CURRENTDIR/log/
rm -rf $APP_BUILD_DIR
test -d $CURRENTDIR/log || mkdir -p $CURRENTDIR/log
test -f $APP_BUILD_LOGFILE || touch $APP_BUILD_LOGFILE
test -d $APP_BUILD_DIR || mkdir -p $APP_BUILD_DIR

do_pre() {
	echo "do pre start at $(date)" | tee -a $APP_BUILD_LOGFILE
	test -d $APP_SOURCE_ROOTDIR || mkdir -p $APP_SOURCE_ROOTDIR
	cd $APP_SOURCE_ROOTDIR/
	git checkout -- $APP_SOURCE_ROOTDIR/$APP_MAIN_MODULE/$APP_MAIN_MODULE/Info.plist
	git checkout -- $APP_SOURCE_ROOTDIR/$APP_MAIN_MODULE/$APP_MAIN_MODULE.xcodeproj/project.pbxproj
	rm -rf $APP_BUILD_DIR/* | tee -a $APP_BUILD_LOGFILE
	rm -rf $APP_SOURCE_ROOTDIR/$APP_MAIN_MODULE/bin | tee -a $APP_BUILD_LOGFILE
	mkdir -p $APP_SOURCE_ROOTDIR/$APP_MAIN_MODULE/bin | tee -a $APP_BUILD_LOGFILE
	rm -rf $CURRENTDIR/log/*.txt
	echo "do pre end at $(date)" | tee -a $APP_BUILD_LOGFILE
}


do_git() {
	echo "do git start at $(date)" | tee -a $APP_BUILD_LOGFILE
	cd $APP_SOURCE_ROOTDIR
	branch=$*
	currentBranch=`git branch`
	if [ "$currentBranch" = "* $branch" ]; then
		echo "do git pull at $(date)" | tee -a $APP_BUILD_LOGFILE
		git pull --recurse-submodules 2>&1 | tee -a $APP_BUILD_LOGFILE
	else
		cd ..
		rm -rf $APP_SOURCE_ROOTDIR
		git clone --recursive $GIT_URL -b $branch 2>&1 | tee -a $APP_BUILD_LOGFILE
		echo "do git clone at $(date)" | tee -a $APP_BUILD_LOGFILE
	fi
	echo "do git end at $(date)" | tee -a $APP_BUILD_LOGFILE
}

do_build() {
	echo "do build start at $(date)" | tee -a $APP_BUILD_LOGFILE
	cd $APP_SOURCE_ROOTDIR/$APP_MAIN_MODULE
	export LANG=GBK.UTF-8
	lineNum=`sed -n '/CFBundleVersion/=' $APP_MAIN_MODULE/Info.plist`
	echo $(($lineNum+1)) | tee -a $APP_BUILD_LOGFILE
	sed -i "" "$(($lineNum+1))s#<string>.*</string>#<string>$(date +%y%m%d)</string>#" $APP_MAIN_MODULE/Info.plist
	sed -i "" "s#ProvisioningStyle = Automatic;#ProvisioningStyle = Manual;#g" $APP_MAIN_MODULE.xcodeproj/project.pbxproj
	sed -i "" "s#LaunchImage_release#LaunchImage_dev#g" $APP_MAIN_MODULE.xcodeproj/project.pbxproj
	sed -i "" "s#PRODUCT_BUNDLE_IDENTIFIER = .*;#PRODUCT_BUNDLE_IDENTIFIER = $PRODUCT_BUNDLE_IDENTIFIER;#g" $APP_MAIN_MODULE.xcodeproj/project.pbxproj
	sed -i "" "s#PROVISIONING_PROFILE = \".*\"#PROVISIONING_PROFILE = \"$PROVISIONING_PROFILE_UUID\"#g" $APP_MAIN_MODULE.xcodeproj/project.pbxproj
	sed -i "" "s#DevelopmentTeam = .*;#DevelopmentTeam = $TEAM_IDENTIFIER;#g" $APP_MAIN_MODULE.xcodeproj/project.pbxproj
	sed -i "" "s#DEVELOPMENT_TEAM = .*;#DEVELOPMENT_TEAM = $TEAM_IDENTIFIER;#g" $APP_MAIN_MODULE.xcodeproj/project.pbxproj
	sed -i "" "s#PROVISIONING_PROFILE_SPECIFIER = \".*\"#PROVISIONING_PROFILE_SPECIFIER = \"$PROVISIONING_PROFILE_NAME\"#g" $APP_MAIN_MODULE.xcodeproj/project.pbxproj
	sed -i "" "s#CODE_SIGN_IDENTITY = \".*\"#CODE_SIGN_IDENTITY = \"$CODE_SIGN_IDENTITY\"#g" $APP_MAIN_MODULE.xcodeproj/project.pbxproj
	sed -i "" "s#\"CODE_SIGN_IDENTITY\[sdk=iphoneos\*\]\" = \".*\"#\"CODE_SIGN_IDENTITY\[sdk=iphoneos\*\]\" = \"$CODE_SIGN_IDENTITY\"#g" $APP_MAIN_MODULE.xcodeproj/project.pbxproj
	export LANG=en_US.UTF-8
	config=$*
	cd $APP_SOURCE_ROOTDIR/$APP_MAIN_MODULE
	xcodebuild -workspace $APP_MAIN_MODULE.xcworkspace -sdk $SDK_NAME -scheme $APP_MAIN_MODULE -configuration $config clean
	xcodebuild -workspace $APP_MAIN_MODULE.xcworkspace -sdk $SDK_NAME -scheme $APP_MAIN_MODULE -configuration $config archive -archivePath bin/$APP_MAIN_MODULE.xcarchive 2>&1 | tee -a $APP_BUILD_LOGFILE
	xcodebuild -exportArchive -exportFormat IPA -archivePath bin/$APP_MAIN_MODULE.xcarchive -exportPath bin/$APP_MAIN_MODULE.ipa -exportProvisioningProfile "$PROVISIONING_PROFILE_NAME" 2>&1 | tee -a $APP_BUILD_LOGFILE
	echo "do build end at $(date)" | tee -a $APP_BUILD_LOGFILE
}

do_sync() {
	echo "do sync start at $(date)" | tee -a $APP_BUILD_LOGFILE
	config=$*
	for i in `find $APP_SOURCE_ROOTDIR/$APP_MAIN_MODULE -name '*.ipa' -print`
	do
		cp $i $APP_BUILD_DIR/IOS-$config.ipa
	done
	for i in `find $APP_SOURCE_ROOTDIR/$APP_MAIN_MODULE -name '*.dSYM' -print`
	do
		zip -r $APP_BUILD_DIR/dSYM.zip $i
	done
	test -f $APP_BUILD_DIR/IOS-$config.ipa && echo "<br>Build Successfully" >> $CURRENTDIR/log/email.txt
	test -f $APP_BUILD_DIR/IOS-$config.ipa || echo "<br>Build Failed" >> $CURRENTDIR/log/email.txt
	test -f $APP_BUILD_DIR/IOS-$config.ipa || exit 1
	echo "<br>" >> $CURRENTDIR/log/email.txt
	curHour=$(date +%H)
	if [ $curHour -lt 9 ]; then
		git log --pretty=format:"<a alt='' href='$GIT_HTTP_URL/commit/%H'>%h</a> -%an,%ad : %s"  --since="`date -d yesterday +%Y-%m-%d` 00:00" --before="`date -d yesterday +%Y-%m-%d` 23:59" >> $CURRENTDIR/log/email.txt
	else
		git log --pretty=format:"<a alt='' href='$GIT_HTTP_URL/commit/%H'>%h</a> -%an,%ad : %s"  --since="`date +%Y-%m-%d` 00:00" --before="`date '+%Y-%m-%d %H-%M'`" >> $CURRENTDIR/log/email.txt
	fi
	echo "\n<br>curl -F \"file=@$APP_BUILD_DIR/IOS-$config.ipa\" -F \"uKey=$PGY_USER_KEY\" -F \"_api_key=$PGY_API_KEY\" https://www.pgyer.com/apiv1/app/upload" | tee -a $APP_BUILD_LOGFILE
	result=`curl -F "file=@$APP_BUILD_DIR/IOS-$config.ipa" -F "uKey=$PGY_USER_KEY" -F "_api_key=$PGY_API_KEY" https://www.pgyer.com/apiv1/app/upload`
	echo $result | tee -a $APP_BUILD_LOGFILE
	appQRCodeURL=`echo $result | grep -o "\"appQRCodeURL\":\".*\"" | awk -F: '{print $2":"$3}' | sed 's/^"//g' | sed 's/\"//g'`
	echo $appQRCodeURL
	appQRCodeURL_c=$(echo $appQRCodeURL | sed 's#\\##g')
	echo $appQRCodeURL_c
	echo "curl -o $APP_BUILD_DIR/appQRCode.png $appQRCodeURL_c" | tee -a $APP_BUILD_LOGFILE
	curl -o $APP_BUILD_DIR/appQRCode.png $appQRCodeURL_c
	echo "\n<br><img src='$appQRCodeURL_c'>" >> $CURRENTDIR/log/email.txt
	echo "do sync end at $(date)" | tee -a $APP_BUILD_LOGFILE
}

#the main
main() {
	if ps -C sh -o %a | grep $SELF 2>&1 > /dev/null; then
   		echo "another $SELF is running"
   		exit -1
	fi
	
	if [ $# -eq 2 ]; then
		local all_parameters=$*
		echo "--> parameters:$all_parameters" | tee -a $APP_BUILD_LOGFILE
		arr=($@)
		OPERATION=${arr[0]}
		BRANCH=${arr[1]}
	else
		echo "invalid parameters" | tee -a $APP_BUILD_LOGFILE
		exit -1
	fi
	
	for op in $OPERATION
	do
		echo "--> doing operation:" $op | tee -a $LOGFILE
		case "$op" in
			
			'DEBUG')
				APP_SOURCE_ROOTDIR=/Users/mactest/Documents/git/debug/XXXXX
				PRODUCT_BUNDLE_IDENTIFIER='XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'
				CODE_SIGN_IDENTITY='XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'
				PROVISIONING_PROFILE_NAME='XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'
				TEAM_IDENTIFIER='XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'
				PROVISIONING_PROFILE_UUID='XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'
				do_pre
				do_git $BRANCH
				do_build Debug
				do_sync Debug
			;;
			
			'AUTOMATION')
				APP_SOURCE_ROOTDIR=/Users/mactest/Documents/git/automation/XXXXX
				PRODUCT_BUNDLE_IDENTIFIER='XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'
				CODE_SIGN_IDENTITY='XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'
				PROVISIONING_PROFILE_NAME='XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'
				TEAM_IDENTIFIER='XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'
				PROVISIONING_PROFILE_UUID='XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'
				do_pre
				do_git $BRANCH
				do_build Debug
				do_sync Debug
			;;


			'RELEASE')
				APP_SOURCE_ROOTDIR=/Users/mactest/Documents/git/release/XXXXX
				PRODUCT_BUNDLE_IDENTIFIER='XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'
				CODE_SIGN_IDENTITY='XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'
				PROVISIONING_PROFILE_NAME='XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'
				TEAM_IDENTIFIER='XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'
				PROVISIONING_PROFILE_UUID='XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'
				do_pre
				do_git $BRANCH
				do_build Internal
				do_sync Internal
			;;
			
			*)
				echo "unsupported operation"
			;;
		esac
	done
}

main $*
