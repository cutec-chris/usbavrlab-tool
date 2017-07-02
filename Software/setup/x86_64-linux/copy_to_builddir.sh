#!/bin/bash
cp ../../output/$1-linux/usbavrlabtool $2
chmod 777 $2/usbavrlabtool
#cp ../../output/$1-linux/usbavrlabavrprogrammer $2
#chmod 777 $2/usbavrlabavrprogrammer
#strip --strip-all $2/usbavrlabtool
cp ../../output/$1-linux/hexencode /tmp
chmod 777 /tmp/hexencode
