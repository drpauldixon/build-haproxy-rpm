#!/bin/bash
set -e

# If running as root (e.g. under Docker)
if [[ $EUID -eq 0 ]]
then
  SUDO=
  RVM_SCRIPT=/etc/profile.d/rvm.sh
else
  SUDO=sudo
  RVM_SCRIPT=$HOME/.rvm/scripts/rvm
fi

# Build an HAProxy RPM with ssl and lua support

# Set the workspace directory if not set
if [ -z $WORKSPACE ]
then
  WORKSPACE=$HOME
fi

INSTALL_ROOT="${INSTALL_ROOT:-${WORKSPACE}/oss}"
BUILD_ROOT="${BUILD_ROOT:-${WORKSPACE}/build}"
HAPROXY_VERSION="${HAPROXY_VERSION:-1.6.6}"
LUA_VERSION="${LUA_VERSION:-5.3.3}"
RVM_VERSION="${RVM_VERSION:-2.2.1}"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

REDHAT_VERSION=$(awk '{print substr ($3, 0, 1)}' /etc/redhat-release)

# Install development tools and libraries
$SUDO yum -y groupinstall "Development tools"  
$SUDO yum -y install openssl-devel pcre-devel zlib-devel readline-devel libtermcap-devel wget curl

# Install fpm (this is used to build the RPM)
if [ ! -f $RVM_SCRIPT ]
then
  if [ $REDHAT_VERSION -gt 5 ]
  then
    gpg2 --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3
  else
    $SUDO yum -y install gpg
    gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3
  fi

  \curl -sSL https://get.rvm.io | bash -s -- --ignore-dotfiles
  
  # set +e before sourceing the rvm script as it has none zero exits in the
  # script somewhere (presumably a bug).
  set +e
  source $RVM_SCRIPT
  rvm install $RVM_VERSION
  rvm use $RVM_VERSION
  set -e
  gem install fpm
else
  set +e
  source $RVM_SCRIPT
  rvm use $RVM_VERSION
  set -e
fi
set -e

# Create empty INSTALL_ROOT - this is where we'll make install to.
if [ -d $INSTALL_ROOT ]
then
  rm -rf $INSTALL_ROOT
fi
mkdir -p $INSTALL_ROOT

# Create empty BUILD_ROOT - this is where we'll download source and compile.
if [ -d $BUILD_ROOT ]
then
  rm -rf $BUILD_ROOT
fi
mkdir $BUILD_ROOT

# Due to a bug in rvm, running `cd` results in a none zero exit.
# So from now on, we use `builtin cd`

# Build LUA
LUA_SRC="lua-${LUA_VERSION}"
builtin cd $BUILD_ROOT
wget http://www.lua.org/ftp/${LUA_SRC}.tar.gz
tar xzf $LUA_SRC.tar.gz
builtin cd $LUA_SRC

# Add -ltermcap to the Makefile on EL5 variants to fix
# undefined references in libreadline.so
if [ $REDHAT_VERSION -eq 5 ]
then
  if ! grep -q ltermcap Makefile
  then
    sed -ie "s/-lreadline/-lreadline -ltermcap/" src/Makefile
  fi
fi

make linux
make INSTALL_TOP=$INSTALL_ROOT/$LUA_SRC install

# Build HAProxy
builtin cd $BUILD_ROOT
HAPROXY_BRANCH=${HAPROXY_VERSION%.*}
HAPROXY_SRC="haproxy-${HAPROXY_VERSION}"
wget http://www.haproxy.org/download/$HAPROXY_BRANCH/src/$HAPROXY_SRC.tar.gz
tar xzf $HAPROXY_SRC.tar.gz
builtin cd $HAPROXY_SRC

LUA_ROOT="$INSTALL_ROOT/$LUA_SRC"
if [ $REDHAT_VERSION -eq 5 ]
then
  make TARGET=linux26 USE_PCRE=1 USE_OPENSSL=1 USE_ZLIB=1 USE_DL=1 USE_LUA=1 LUA_LIB=$LUA_ROOT/lib LUA_INC=$LUA_ROOT/include LUA_LIB_NAME=lua CC="gcc -DLUA_32BITS"
else
  make TARGET=linux26 USE_PCRE=1 USE_OPENSSL=1 USE_ZLIB=1 USE_DL=1 USE_LUA=1 LUA_LIB=$LUA_ROOT/lib LUA_INC=$LUA_ROOT/include LUA_LIB_NAME=lua
fi

mkdir -p $INSTALL_ROOT/haproxy/etc/rc.d/init.d  
mkdir -p $INSTALL_ROOT/haproxy/etc/haproxy  
mkdir -p $INSTALL_ROOT/haproxy/var/lib/haproxy  
chmod 700 $INSTALL_ROOT/haproxy/var/lib/haproxy  
make install DESTDIR=$INSTALL_ROOT/haproxy PREFIX=/usr DOCDIR=/usr/share/doc/haproxy

# Create system v init script for EL versions < 7
if [ $REDHAT_VERSION -lt 7 ]
then
  cp $SCRIPT_DIR/haproxy.sysv $INSTALL_ROOT/haproxy/etc/rc.d/init.d/haproxy
  chmod 755 $INSTALL_ROOT/haproxy/etc/rc.d/init.d/haproxy
fi

builtin cd $WORKSPACE
rm -f *.rpm
fpm -s dir -t rpm -n haproxy -v $HAPROXY_VERSION --config-files /etc/haproxy/ -C ~/oss/haproxy/ usr etc var
[ ! -d /vagrant/rpms/el${REDHAT_VERSION} ] && mkdir -p /vagrant/rpms/el${REDHAT_VERSION}
cp -f haproxy-$HAPROXY_VERSION-1.x86_64.rpm /vagrant/rpms/el${REDHAT_VERSION}
echo "haproxy-$HAPROXY_VERSION-1.x86_64.rpm copied to /vagrant/rpms/el${REDHAT_VERSION}"
