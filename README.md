# emu

InkBox OS emulator. Based on `qemu-system-arm` with the `vexpress-a9` board.

## Install
On a Debian-based system, install the following dependencies to be able to bootstrap it:
```
sudo apt install build-essential qemu-system-arm git u-boot-tools swig python-dev python3-dev bison flex squashfs-tools bc
```

Then, clone the repository, `cd` into it, and bootstrap the emulator:
```
env GITDIR=${PWD} ./bootstrap.sh
```

## Launch
`cd` into `out/boot` and run the following command:
```
env GITDIR=/location/of/the/repository ./qemu-boot
```
Serial console (`ttyAMA0`) will print out on `stdout`. Once the system has fully booted, you can login as `root` with the password `root`, or as `user` with the password `user`.

To access InkBox GUI, connect, on your host machine, to `127.0.0.1:5901` via VNC. If it doesn't work right away, wait awhile. The speed of the emulator may vary depending on your hardware.

If everything goes well, you should have something like this:
![InkBox GUI via VNC](https://github.com/Kobo-InkBox/emu/raw/main/images/vnc.png)
