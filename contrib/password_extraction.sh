#!/bin/bash
#
# Date 05/10/2012
# Arjun R P, Pranav M, Amrita University. 
#

d=$1
fname="/login.xls"
dir="/tmp/pass"
tname="/passwords.tgz"
tname=`echo "$d$tname"`
fname=`echo "$d$fname"`
rm -r $dir 2>/dev/null
if [ -f $fname ]
then
	rm $fname
fi
if [ ! -f $tname ]
then
	#echo file missing : $tname
	exit 1	
fi	
mkdir $dir
if [ $? -eq 0 ]
then
	tar -C $dir -xvzf $tname > /dev/null
	if [ $? -eq 0  ]
	then
		for file in $dir/*.ps
		do
			set `grep -o 'WB(.*)}' $file | cut --complement -c 1-3 | cut -d ')' -f 1|tail -n 4`
			echo "$2 $4" >> $fname 
		done
	else	
		#echo  "Error in extracting files."
		exit 1
	fi
else
	#echo "Error in creating file."
	exit 1
fi
exit 0
