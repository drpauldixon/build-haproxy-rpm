#!/bin/bash

function help(){
  echo "Usage: mkvagrantfile.sh <5|6>"
  exit
}

if [ -z $1 ]
then
  help
fi

case $1 in
5)
  [ -f Vagrantfile ] && rm -f Vagrantfile
  vagrant init -m hansode/centos-5.11-x86_64
  ;;
6)
  [ -f Vagrantfile ] && rm -f Vagrantfile
  vagrant init -m puppetlabs/centos-6.6-64-puppet
  ;;
*)
  help
  ;;
esac

echo
echo "Now run:"
echo "vagrant up"
echo "vagrant ssh"
echo "/vagrant/build.sh"
