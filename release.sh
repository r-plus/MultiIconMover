#!/bin/sh

NAME=$1

rm -rf release
cp -a package release
cp ${NAME}.dylib release/Library/MobileSubstrate/DynamicLibraries/
find release -iname .svn -exec rm -rf {} \;
find release -iname .gitignore -exec rm -rf {} \;
sudo chown -R root:root release
sudo dpkg-deb -b release
sudo rm -rf release
