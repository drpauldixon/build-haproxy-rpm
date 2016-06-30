# Build an HAProxy RPM with Lua support

This is a bit of a hatchet job... I needed HAProxy built with Lua support and package it up as an RPM. And I needed a version that runs on EL 5 variants (CentOS 5, RedHat 5). And I needed to build new packages when new versions of HAProxy are released.

This currently supports EL5 and EL6.

To get going...

## Build HAproxy for EL6 variants

```
./mkvagrantfile.sh 6
vagrant up
vagrant ssh
/vagrant/build.sh
```

This will create an rpm in /vagrant/rpms/el6/.

## Versions

HAProxy and Lua versions can be configured before running `/vagrant/build.sh` using environment variables, e.g.

```
export HAPROXY_VERSION=1.6.5
export LUA_VERSION=5.3.2
/vagrant/build.sh
```

## TODO

EL7 using systemd.
