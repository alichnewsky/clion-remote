# building CLion toolchain docker images
This has changed with CLion 2021.3. It is now extremely simple, you don't have to add ssh ...

## building with a linux/arm64/v8 platform
i.e. for a Mac M1

```bash
git clone https://github.com/alichnewsky/clion-remote github.com/alichnewsky/clion-remote
pushd github.com/alichnewsky/clion-remote

docker build --platform linux/arm64/v8 --rm \
       -t clion/arm64v8/devtoolset-10-centos7-cpp-env \
       -f Dockerfile.devtoolset-10-toolchain-centos7-cpp-env.mac.arm64v8 .
```

## running with a linux/arm64/v8 platform
- not sure we ahve to pass the platform again, if there is only one container built?
- not sure if docker recently picks the local host platform correctly on mac M1 ( which can execute x86_64 code and containers as well )

```bash
$ docker run --rm -it --platform linux/arm64/v8 clion/arm64v8/devtoolset-10-centos7-cpp-env uname -a
Linux b67aaf582911 5.10.104-linuxkit #1 SMP PREEMPT Thu Mar 17 17:05:54 UTC 2022 aarch64 aarch64 aarch64 GNU/Linux

$ docker run --rm -it --platform linux/arm64/v8 clion/arm64v8/devtoolset-10-centos7-cpp-env  /bin/bash -c 'set -x; g++ --version; clang++ --version;git --version; cmake --version'
+ g++ --version
g++ (GCC) 10.2.1 20210130 (Red Hat 10.2.1-11)
Copyright (C) 2020 Free Software Foundation, Inc.
This is free software; see the source for copying conditions.  There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

+ clang++ --version
clang version 7.0.1 (tags/RELEASE_701/final)
Target: aarch64-unknown-linux-gnu
Thread model: posix
InstalledDir: /opt/rh/llvm-toolset-7.0/root/usr/bin
+ git --version
git version 2.27.0
+ cmake --version
cmake version 3.22.3

CMake suite maintained and supported by Kitware (kitware.com/cmake).
```