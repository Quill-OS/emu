#!/bin/bash -ex

[ -z "${GITDIR}" ] && echo "You must specify the GITDIR environment variable with the location of this repository." && exit 1
SERVER="http://23.163.0.39"

create_sd() {
	# Creating SD card image
	qemu-img create -f qcow2 sd.img 4G
	sudo modprobe nbd && sudo qemu-nbd --connect=/dev/nbd0 sd.img
	sudo sfdisk /dev/nbd0 < ../sd/sd-layout
	sudo mkfs.ext4 /dev/nbd0p1 && sudo mkfs.ext4 /dev/nbd0p2 && sudo mkfs.ext4 /dev/nbd0p3 && sudo mkfs.ext4 /dev/nbd0p4
}

mount_fs() {
	ROOT_MOUNT="/tmp/inkbox"
	BOOT_MOUNT="${ROOT_MOUNT}/boot"
	RECOVERYFS_MOUNT="${ROOT_MOUNT}/recovery"
	ROOTFS_MOUNT="${ROOT_MOUNT}/rootfs"
	USER_MOUNT="${ROOT_MOUNT}/user"
	mkdir -p "${BOOT_MOUNT}" "${RECOVERYFS_MOUNT}" "${ROOTFS_MOUNT}" "${USER_MOUNT}"
	sudo mount /dev/nbd0p1 "${BOOT_MOUNT}"
	sudo mount /dev/nbd0p2 "${RECOVERYFS_MOUNT}"
	sudo mount /dev/nbd0p3 "${ROOTFS_MOUNT}"
	sudo mount /dev/nbd0p4 "${USER_MOUNT}"
}

populate_sd() {
	# Populating SD card image with necessary content
	# Allow root kernel to be executed in emulator
	echo "rooted" | sudo dd of=/dev/nbd0 bs=512 seek=79872

	# Boot partition
	sudo mkdir -p "${BOOT_MOUNT}/flags"

	# Root filesystem
	# Yes, this is meant to be run as root
	sudo git clone https://github.com/Kobo-InkBox/rootfs && cd rootfs
	sudo env GITDIR="${PWD}" ./release.sh && cd ..
	sudo openssl dgst -sha256 -sign "${GITDIR}/keys/private.pem" -out rootfs.squashfs.dgst rootfs.squashfs
	sudo cp rootfs.squashfs rootfs.squashfs.dgst "${ROOTFS_MOUNT}"
	sudo openssl dgst -sha256 -sign "${GITDIR}/keys/private.pem" -out ../sd/overlaymount-rootfs.squashfs.dgst ../sd/overlaymount-rootfs.squashfs
	sudo cp ../sd/overlaymount-rootfs.squashfs ../sd/overlaymount-rootfs.squashfs.dgst "${ROOTFS_MOUNT}"

	cd "${GITDIR}"

	# Recovery partition
	# No need for a full recovery program, we just copy the necessary overlaymount-rootfs squashfs bundle needed by the initrd at startup
	sudo cp sd/overlaymount-rootfs.squashfs sd/overlaymount-rootfs.squashfs.dgst "${RECOVERYFS_MOUNT}"
	
	# User storage partition
	cat sd/user.sqsh.* > sd/user.sqsh
	sudo unsquashfs -f -d "${USER_MOUNT}" sd/user.sqsh
	sudo openssl dgst -sha256 -sign keys/private.pem -out "${USER_MOUNT}/gui_rootfs.isa.dgst" "${USER_MOUNT}/gui_rootfs.isa"
	CURRENT_VERSION=$(wget -q -O - "${SERVER}/bundles/inkbox/native/update/ota_current")
	echo "${CURRENT_VERSION}" | sudo tee -a "${USER_MOUNT}/update/version" > /dev/null
	cd "${USER_MOUNT}/update" && sudo wget "${SERVER}/bundles/inkbox/native/update/${CURRENT_VERSION}/emu/inkbox-update-${CURRENT_VERSION}.upd.isa" -O "update.isa" && cd "${GITDIR}"

	# Build kernel
	cd "${GITDIR}/out"
	mkdir -p boot
	if [ -z "${KERNELDIR}" ]; then
		git clone https://github.com/Kobo-InkBox/kernel && cd kernel
		KERNELDIR="${PWD}"
	else
		cd "${KERNELDIR}"
	fi

	env GITDIR="${KERNELDIR}" TOOLCHAINDIR="${KERNELDIR}/toolchain/armv7l-linux-musleabihf-cross" THREADS=$(($(nproc)*2)) TARGET=armv7l-linux-musleabihf scripts/build_kernel.sh emu root
	cp kernel/out/emu/zImage-root kernel/linux-5.15.10/arch/arm/boot/dts/vexpress-v2p-ca9.dtb "${GITDIR}/out/boot"
	echo -e '#!/bin/bash\ncd ${GITDIR}\nqemu-system-arm -M vexpress-a9 -kernel "${GITDIR}/out/boot/zImage-root" -dtb "${GITDIR}/out/boot/vexpress-v2p-ca9.dtb" -append "console=ttyAMA0 root=/dev/ram0 rdinit=/sbin/init rootfstype=ramfs" -serial mon:stdio -sd "${GITDIR}/out/sd.img" -m 1G -smp 4 -net nic -net user,hostfwd=tcp::5901-:5900' > "${GITDIR}/out/boot/qemu-boot"
	chmod +x "${GITDIR}/out/boot/qemu-boot"
}

umount_fs() {
	sync
	sudo umount -l -f "${BOOT_MOUNT}"
	sudo umount -l -f "${RECOVERYFS_MOUNT}"
	sudo umount -l -f "${ROOTFS_MOUNT}"
	sudo umount -l -f "${USER_MOUNT}"
	rm -rf "${ROOT_MOUNT}"
	sudo qemu-nbd --disconnect /dev/nbd0
}

cd "${GITDIR}"
mkdir -p out && cd out
create_sd
mount_fs
populate_sd
umount_fs
echo "Bootstrap done. You should now be able to launch the emulator by running: 'env GITDIR=${GITDIR} ${GITDIR}/out/boot/qemu-boot'."
