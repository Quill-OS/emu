# emu

InkBox OS emulator. Based on `qemu-system-arm` with the `vexpress-a9` board.

## Install
On a Debian-based system, install the following dependencies to be able to bootstrap it:
```
sudo apt-get install build-essential qemu-system-arm git u-boot-tools swig python-dev python3-dev bison flex squashfs-tools bc telnet-client
```
For an Arch-based distro:
```
sudo pacman -S base-devel qemu-system-arm git uboot-tools swig python python2 bison flex squashfs-tools bc inetutils
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

To launch a self-compiled inkbox binary on it, run something like this:
```
rm /tmp/inkbox; wget your.http.servers.ipaddr:8000/inkbox -O /tmp/inkbox; chmod +x /tmp/inkbox; umount -l -f /kobo/mnt/onboard/.adds/inkbox/inkbox-bin; mount --bind /tmp/inkbox /kobo/mnt/onboard/.adds/inkbox/inkbox-bin; killall inkbox-bin inkbox inkbox.sh; env QT_QPA_PLATFORM=vnc:size=768x1024 chroot /kobo /mnt/onboard/.adds/inkbox/inkbox.sh
```

To interact with the emulator without using the serial console:
```
busybox-initrd telnetd -l /bin/ash
```

test it :
```
telnet 127.0.0.1 5555
```

If you want to use the 'remote debugging' feature of Qt Creator, make it use a script like this:
```bash
#!/bin/bash
killall busybox;
busybox httpd -f -p 0.0.0.0:8000 -vv &
sleep 1;

( sleep 0.5; echo "ifsctl mnt rootfs rw"; sleep 0.4 )  | telnet 127.0.0.1 5555 2>/dev/null 1>/dev/null
( sleep 0.5; echo "rm /kobo/tmp/exec"; sleep 10 ) | telnet 127.0.0.1 5555 2>/dev/null 1>/dev/null
( sleep 0.5; echo "wget 192.168.0.25:8000/exec -O /kobo/tmp/exec;"; sleep 15 )  | telnet 127.0.0.1 5555 2>/dev/null 1>/dev/null # Increase sleep time if it doesn't manage to download the whole binary
( sleep 0.5; echo "chmod +x /kobo/tmp/exec"; sleep 0.5 )  | telnet 127.0.0.1 5555 2>/dev/null 1>/dev/null
killall busybox;
( sleep 0.5; echo "/kobo/launch_app.sh"; sleep infinity ) | telnet 127.0.0.1 5555 2>/dev/null
# Look: https://github.com/Szybet/kobo-nia-audio/blob/main/apps-on-kobo/launch_app.sh
# But change QT_QPA_PLATFORM to QT_QPA_PLATFORM=vnc:size=768x1024
```

### Known issues & tips:
- SSH to the emulator doesn't work, but it's enabled anyway. Nobody knows why. SSH from the emulator works.
- Make sure while making the emulator that every command using `sudo` has worked
- If something doesn't work with the kernel, symlink `/home/build/inkbox/kernel` to `emu/out/kernel`
- Emulator performance depends on CPU frequency, make it higher/maximum to achieve better performance. Lowering the CPU cores number in the `qemu-boot` script (`-smp`) may help. Don't expect fabulous results if your hardware is a low-end i3 CPU from 2013, for example ;)
- To download heavy files/directories use `-no-http-keep-alive --no-cache` with `wget`. Example: `wget -no-http-keep-alive --no-cache --no-cookies -e robots=off -R "index.html*" --recursive --no-parent http://your.http.servers.ipaddr/`
- network can have problems with the first launch of qemu. Close it and relaunch, it should be fine
