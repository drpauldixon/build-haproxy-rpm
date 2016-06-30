#!/bin/bash -e

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
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

REDHAT_VERSION=$(awk '{print substr ($3, 0, 1)}' /etc/redhat-release)

# Install development tools and libraries
sudo yum -y groupinstall "Development tools"  
sudo yum -y install openssl-devel pcre-devel zlib-devel readline-devel libtermcap-devel

# Install fpm (this is used to build the RPM)
if [ ! -f $HOME/.rvm/gems/ruby-1.9.3-p551/bin/fpm ]
then

  if [ $REDHAT_VERSION -gt 5 ]
  then
    gpg2 --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3
  else
    sudo yum -y install gpg
    gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3
  fi

  if [ ! -f $HOME/.rvm/VERSION ]
  then
    \curl -sSL https://get.rvm.io | bash -s -- --ignore-dotfiles
  fi
  export PATH="$PATH:$HOME/.rvm/bin" # Add RVM to PATH for scripting
  [[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm" # Load RVM into a shell session *as a function*
  rvm install 1.9.3
  rvm use 1.9.3
  gem install fpm
else
  export PATH="$PATH:$HOME/.rvm/bin" # Add RVM to PATH for scripting
  [[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm" # Load RVM into a shell session *as a function*
  rvm use 1.9.3
fi


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

# Build LUA
LUA_SRC="lua-${LUA_VERSION}"
cd $BUILD_ROOT
wget http://www.lua.org/ftp/${LUA_SRC}.tar.gz
tar xzf $LUA_SRC.tar.gz
cd $LUA_SRC

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
cd $BUILD_ROOT
HAPROXY_BRANCH=${HAPROXY_VERSION%.*}
HAPROXY_SRC="haproxy-${HAPROXY_VERSION}"
wget http://www.haproxy.org/download/$HAPROXY_BRANCH/src/$HAPROXY_SRC.tar.gz
tar xzf $HAPROXY_SRC.tar.gz
cd $HAPROXY_SRC

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

cd $WORKSPACE
rm -f *.rpm
fpm -s dir -t rpm -n haproxy -v $HAPROXY_VERSION --config-files /etc/haproxy/ -C ~/oss/haproxy/ usr etc var
[ ! -d /vagrant/rpms/el${REDHAT_VERSION} ] && mkdir -p /vagrant/rpms/el${REDHAT_VERSION}
cp -f haproxy-$HAPROXY_VERSION-1.x86_64.rpm /vagrant/rpms/el${REDHAT_VERSION}
echo "haproxy-$HAPROXY_VERSION-1.x86_64.rpm copied to /vagrant/rpms/el${REDHAT_VERSION}"
