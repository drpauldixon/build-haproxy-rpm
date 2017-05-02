# Build an HAProxy RPM with Lua support

This is a bit of a hatchet job... I needed HAProxy built with Lua support and packaged up as an RPM. And I needed a version that runs on EL5 variants (CentOS 5, RedHat 5). And I needed to build new packages when new versions of HAProxy are released.

This currently supports EL5 and EL6.

To get going...

## Using Docker

**Build an HAProxy RPM for EL7 variants:**

This will place an RPM file in `rpms/el7`

```
docker run -t -i -v $PWD:/vagrant centos:7 /vagrant/build.sh
```

This will place an RPM file in `rpms/el6`

```
docker run -t -i -v $PWD:/vagrant centos:6 /vagrant/build.sh
```

**Build an HAProxy RPM for EL5 variants:**

This will place an RPM file in `rpms/el5`

```
docker run -t -i -v $PWD:/vagrant reducible/centosdev:5 /vagrant/build.sh
```


## Using Vagrant

**Build an HAProxy RPM for EL6 variants:**

```
./mkvagrantfile.sh 6
vagrant up
vagrant ssh
/vagrant/build.sh
```

This will place an RPM file in `rpms/el6`

**Build an HAProxy RPM for EL5 variants:**

```
./mkvagrantfile.sh 5
vagrant up
vagrant ssh
/vagrant/build.sh
```

This will place an RPM file in `rpms/el5`

## Versions

HAProxy and Lua versions can be configured before running `/vagrant/build.sh` using environment variables, e.g.

**Via docker:**

```
docker run -t -i -e HAPROXY_VERSION='1.6.5' -e LUA_VERSION='5.3.2' -v $PWD:/vagrant centosdev:6 /vagrant/build.sh
```

**Via vagrant:**

```
export HAPROXY_VERSION=1.6.5
export LUA_VERSION=5.3.2
/vagrant/build.sh
```

