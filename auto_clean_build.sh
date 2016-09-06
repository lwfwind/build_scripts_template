#!/usr/bin/env bash
SELF=$(cd $(dirname $0); pwd -P)/$(basename $0)
CURRENTDIR=$(cd $(dirname $0); pwd -P)
test -d $CURRENTDIR/log/ || mkdir -p $CURRENTDIR/log/
LOGFILE=$CURRENTDIR/log/cleanDaily.log
if ps -C sh -o %a | grep $SELF 2>&1 > /dev/null; then
	echo "another $SELF is running"
	exit -1
fi
if [ $# -lt 1 ]; then 
	echo "the number of parameter is not correct"
	exit
fi
desdirs=$*
echo "desdirs $desdirs" | tee -a $LOGFILE

if [ "$(uname)" == "Darwin" ]; then
    # Do something under Mac OS X platform
	basetime=`date -v-6d "+%Y%m%d"`
elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
    # Do something under GNU/Linux platform
	basetime=`date -d '6 days ago' "+%Y%m%d"`
elif [ "$(expr substr $(uname -s) 1 10)" == "MINGW32_NT" ]; then
    # Do something under Windows NT platform
	echo "Do something under Windows NT platform" | tee -a $LOGFILE
fi

echo $basetime | tee -a $LOGFILE
for desDir in $desdirs; do
	if [ "$(uname)" == "Darwin" ]; then
		maxDepth=`find $desDir -type d | sed 's|[^/]||g' | sort | tail -n1 | tr -d " \t\n\r" | wc -m | awk '{print $1}'`
		echo "$desDir maxdepth $maxDepth" | tee -a $LOGFILE
		desDirSelfDepth=`echo $desDir | sed 's|[^/]||g' | tr -d " \t\n\r" | wc -m | awk '{print $1}'`
		echo "$desDir desDirSelfDepth $desDirSelfDepth" | tee -a $LOGFILE
		depth=`expr $maxDepth - $desDirSelfDepth`
		echo "$desDir depth $depth" | tee -a $LOGFILE
	elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
		depth=`find $desDir -type d -printf '%d:%p\n' | sort -n | tail -1 | awk -F: '{print $1}'`
		echo "$desDir depth $depth" | tee -a $LOGFILE
	elif [ "$(expr substr $(uname -s) 1 10)" == "MINGW32_NT" ]; then
		# Do something under Windows NT platform
		echo "Do something under Windows NT platform" | tee -a $LOGFILE
		
	fi
	
	for dir in $(find $desDir -mindepth $depth -type d); do
		echo "dir $dir" 
		dirtime=`stat $dir | tail -1 | awk  '{print $2}'`
		dirtime=${dirtime//-/}
		if [ "$dirtime" -lt "$basetime" ] 
		then
			echo "del dir $dir -> $dirtime at $(date)" | tee -a $LOGFILE
			rm -rf $dir
		fi	
	done
	for file in $(find $desDir -mindepth $depth -type f); do
		echo "file $file" 
		filetime=`stat $file | tail -1 | awk  '{print $2}'`
		filetime=${filetime//-/}
		if [ "$filetime" -lt "$basetime" ] 
		then
			echo "del file $file -> $filetime at $(date)" | tee -a $LOGFILE
			rm -rf $file
		fi	
	done
done


