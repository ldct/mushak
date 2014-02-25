#!/bin/bash

m=$1
for i in $* 
do
   if [ $i -gt $m ] 
   then
         m=$i
   fi
done
echo $m









