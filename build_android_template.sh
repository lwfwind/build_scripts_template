#!/bin/bash
# this is config for daily build

source /etc/profile

SELF=$(cd $(dirname $0); pwd -P)/$(basename $0)
CURRENTDIR=$(cd $(dirname $0); pwd -P)
DATE=$(date +%y-%m-%d-%H-%M)
PGY_USER_KEY=ec36bc42bab3733a4f82840bffbf497e
PGY_API_KEY=8697e51e3159272a081c3d1084be2274
APP_SOURCE_ROOTDIR=/home/git/develop/platform
APP_MAIN_MODULE=tool
APP_BUILD_DIR=$CURRENTDIR/build
APP_BUILD_LOGFILE=$CURRENTDIR/log/log.log
GIT_URL=git@xx.xx.xx.xx:pc-developer/platform.git
GIT_HTTP_URL=http://xx.xx.xx.xx/pc-developer/platform
rm -rf $CURRENTDIR/log/
rm -rf $APP_BUILD_DIR
test -d $CURRENTDIR/log || mkdir -p $CURRENTDIR/log
test -f $APP_BUILD_LOGFILE || touch $APP_BUILD_LOGFILE
test -d $APP_BUILD_DIR || mkdir -p $APP_BUILD_DIR

do_pre() {
	echo "do pre start at $(date)" | tee -a $APP_BUILD_LOGFILE
	test -d $APP_SOURCE_ROOTDIR || mkdir -p $APP_SOURCE_ROOTDIR
	cd $APP_SOURCE_ROOTDIR/
	git checkout -- $APP_SOURCE_ROOTDIR/$APP_MAIN_MODULE/build.gradle
	./gradlew clean 2>&1 | tee -a $APP_BUILD_LOGFILE
	rm -rf $APP_BUILD_DIR/* | tee -a $APP_BUILD_LOGFILE
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
		git pull 2>&1 | tee -a $APP_BUILD_LOGFILE
	else
		cd ..
		rm -rf $APP_SOURCE_ROOTDIR
		git clone $GIT_URL -b $branch 2>&1 | tee -a $APP_BUILD_LOGFILE
		echo "do git clone at $(date)" | tee -a $APP_BUILD_LOGFILE
	fi
	echo "do git end at $(date)" | tee -a $APP_BUILD_LOGFILE
}

do_build() {
	echo "do build start at $(date)" | tee -a $APP_BUILD_LOGFILE
	applicationId=$(cat $APP_SOURCE_ROOTDIR/$APP_MAIN_MODULE/build.gradle | grep "applicationId " | awk  '{print $2}' | sed 's/\"//g')
	echo "applicationId:$applicationId" | tee -a $APP_BUILD_LOGFILE
	newApplicationId=$applicationId.$OPERATION
	echo "newApplicationId:$newApplicationId" | tee -a $APP_BUILD_LOGFILE
	sed -i "s/applicationId .*/applicationId \"$newApplicationId\"/g" $APP_SOURCE_ROOTDIR/$APP_MAIN_MODULE/build.gradle
	cd $APP_SOURCE_ROOTDIR
	./gradlew $* 2>&1 | tee -a $APP_BUILD_LOGFILE
	echo "do build end at $(date)" | tee -a $APP_BUILD_LOGFILE
}

do_sync() {
	echo "do sync start at $(date)" | tee -a $APP_BUILD_LOGFILE
	config=$*
	versionName=$(cat $APP_SOURCE_ROOTDIR/$APP_MAIN_MODULE/build.gradle | grep "versionName " | awk  '{print $2}' | sed 's/\"//g')
	cp $APP_SOURCE_ROOTDIR/$APP_MAIN_MODULE/build/outputs/apk/$APP_MAIN_MODULE-$config-$versionName.apk $APP_BUILD_DIR/Android-$config-$versionName.apk
	cp $APP_SOURCE_ROOTDIR/$APP_MAIN_MODULE/build/outputs/mapping/$config/mapping.txt $APP_BUILD_DIR/mapping.txt
	test -f $APP_BUILD_DIR/Android-$config-$versionName.apk && echo "<br>Build Successfully" >> $CURRENTDIR/log/email.txt
	test -f $APP_BUILD_DIR/Android-$config-$versionName.apk || echo "<br>Build Failed, please refer to the attach log" >> $CURRENTDIR/log/email.txt
	test -f $APP_BUILD_DIR/Android-$config-$versionName.apk || exit 1
	echo "<br>" >> $CURRENTDIR/log/email.txt
	curHour=$(date +%H)
	if [ $curHour -lt 9 ]; then
		git log --pretty=format:"<a alt='' href='$GIT_HTTP_URL/commit/%H'>%h</a> -%an,%ad : %s"  --since="`date -d yesterday +%Y-%m-%d` 00:00" --before="`date -d yesterday +%Y-%m-%d` 23:59" >> $CURRENTDIR/log/email.txt
	else
		git log --pretty=format:"<a alt='' href='$GIT_HTTP_URL/commit/%H'>%h</a> -%an,%ad : %s"  --since="`date +%Y-%m-%d` 00:00" --before="`date '+%Y-%m-%d %H-%M'`" >> $CURRENTDIR/log/email.txt
	fi
	echo "\n<br>curl -F \"file=@$APP_BUILD_DIR/Android-$config-$versionName.apk\" -F \"uKey=$PGY_USER_KEY\" -F \"_api_key=$PGY_API_KEY\" https://www.pgyer.com/apiv1/app/upload" | tee -a $APP_BUILD_LOGFILE
	result=`curl -F "file=@$APP_BUILD_DIR/Android-$config-$versionName.apk" -F "uKey=$PGY_USER_KEY" -F "_api_key=$PGY_API_KEY" https://www.pgyer.com/apiv1/app/upload`
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
				do_pre
				do_git $BRANCH
				do_build assembleRelease
				do_sync release
			;;
			
			'AUTOMATION')
				APP_SOURCE_ROOTDIR=/home/git/automation/platform
				do_pre
				do_git $BRANCH
				cd $APP_SOURCE_ROOTDIR && git checkout -- $APP_SOURCE_ROOTDIR/tool/src/main/java/com/xxx.java
				sed -i "s#xx.xx.xx.xx/api-https/abc360/#xx.xx.xx.xx/abc360dev/#g" $APP_SOURCE_ROOTDIR/tool/src/main/java/com/xxx.java
				do_build assembleDebug
				do_sync debug
			;;


			'RELEASE')
				APP_SOURCE_ROOTDIR=/home/git/release/platform
				do_pre
				do_git $BRANCH
				do_build assembleRelease
				do_sync release
			;;
			
			*)
				echo "unsupported operation"
			;;
		esac
	done
}

main $*
