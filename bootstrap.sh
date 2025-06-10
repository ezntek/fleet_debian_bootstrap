#!/bin/bash
#
# fleet_debian_boostrap: a silly script to bootstrap a debian install for
# a marcosian fleet laptop. this should be run on a debian live cd with
# network connectivity.
#
# Copyright (c) Eason Qin <eason@ezntek.com>, 2025
#
# Licensed under the MIT/Expat License
#

# Make sure to return if a command executed here returns a non-zero status.
set -e

log() {
    echo -e "\033[1m[LOG]\033[0m" $@ 
}

die() {
    echo -e "\033[31;1m[ERROR]\033[0m" $@
    echo "        Remember to review the log at ${LOG_FILE}" >&2
    exit 1
}

handle_int() {
    echo
    die "interrupt signal received"
}

trap "handle_int" "SIGINT"

check_root() {
    if [[ "$(whoami)" != "root" ]]; then
        die "not root" 
    fi
}

get_disk_name() {
    echo "enter base name of disk"
    read disk # magical bash scoping shit

    [ -e "/dev/${disk}" ] || die "disk ${disk} doesnt exist"
}


ensure_debootstrap() {
    for pkg in debootstrap dosfstools; do
        [[ "$(apt list --installed | grep $pkg)" == "" ]] && apt install -y $pkg
    done
}

prepare_disks() {
    log "partitioning disks"

    swapoff -a

    # clear partition table
    sgdisk -Z /dev/sda

    # create partitions:
    #  * bios boot (1M)
    #  * linux swap (4G)
    #  * linux filesystem (the rest)
    sgdisk -n 1::+1M -t 1:21686148-6449-6E6F-744E-656564454649 \
           -n 2::+4G -t 2:0657FD6D-A4AB-43C4-84E5-0933C84B4F4F \
           -n 3:: -t 3:0FC63DAF-8483-4772-8E79-3D69D8477DE4 \
           /dev/sda

    mkswap /dev/sda2
    mkfs.ext4 -F /dev/sda3
}

mount_disks() {
    log "mounting disks"
    mount /dev/sda3 /mnt
    swapon /dev/sda2
}

bootstrap() {
    log "running debootstrap"
    debootstrap --arch amd64 testing /mnt https://deb.debian.org/debian
}

create_fstab() {
    log "creating fstab"

    local root_uuid=$(blkid -s UUID -o value "/dev/${disk}3")
    local swap_uuid=$(blkid -s UUID -o value "/dev/${disk}2")

    echo "UUID=${root_uuid} / ext4 rw,defaults,errors=remount-ro 0 1" >> /mnt/etc/fstab
    echo "UUID=${swap_uuid} none swap defaults 0 0" >> /mnt/etc/fstab
}

run_chroot() {
    log "preparing chroot"
    mount --make-rslave --rbind /proc /mnt/proc
    mount --make-rslave --rbind /sys /mnt/sys
    mount --make-rslave --rbind /dev /mnt/dev
    mount --make-rslave --rbind /run /mnt/run

    log "chrooting"
    export FLBOOTSTRAP_IN_CHROOT=1
    local script_path=$(readlink -f "$0")
    local new_path="/mnt/$(basename $0)"
    cp "$script_path" "$new_path"
    chmod +x $new_path
    chroot /mnt /bin/bash -c "/$(basename $new_path)"
}

main() {
    export FLBOOTSTRAP_IN_CHROOT=0
    log "fleet laptop bootstrapper"

    check_root
    get_disk_name
    apt update -y
    ensure_debootstrap

    prepare_disks
    mount_disks
    bootstrap
    create_fstab
    run_chroot
}

# ===== chroot stage =====

chr_update_repos() {
    log "updating repos"

    rm -f /etc/apt/sources.list

    cat <<EOF > /etc/apt/sources.list.d/debian.sources
Types: deb deb-src
URIs: https://deb.debian.org/debian
Suites: testing bookworm 
Components: main non-free-firmware contrib
Enabled: yes
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb deb-src
URIs: https://security.debian.org
Suites: testing-security bookworm-security
Components: main
Enabled: yes
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF
 
    apt -y update 
    apt -y upgrade
}

chr_install_pkgs() {
    log "installing packages"

    EXTRA_PKGS="chromium neofetch fastfetch htop btop build-essential python3 python-is-python3 default-jdk default-jdk-doc neovim curl"

    PKGS="network-manager tasksel sudo grub2 os-prober e2fsprogs console-setup console-setup-linux linux-image-amd64 firmware-iwlwifi firmware-linux openssh-server ca-certificates lsb-release arch-install-scripts ${EXTRA_PKGS}"
    
    apt install -y ${PKGS}
}

chr_configure_locales() {
    log "setting up locales"

    apt install -y locales

    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
    locale-gen
    localectl set-locale "en_US.UTF-8"
}

chr_configure_tz() {
    log "setting up time zone"

    timedatectl set-timezone "Asia/Singapore"
}

chr_configure_networking() {
    log "configuring networking"

    local id=$(printf "%04x\n" $((RANDOM << 8 | RANDOM & 0xFF)))
    local hostname="S0816-$id"
    echo $hostname > /etc/hostname
    cat > /etc/hosts << EOF
127.0.0.1 localhost ${hostname}
127.0.1.1 ${hostname}

# The following lines are desirable for IPv6 capable hosts
::1     localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOF
}

chr_enable_services() {
    log "enabling services"

    systemctl enable NetworkManager
    systemctl enable ssh
}

chr_add_users() {
    log "setting root password"
    passwd root

    useradd -m -G sudo,video,audio,tty,lp -s /bin/bash administrator
    useradd -m -G video,audio,tty,lp -s /bin/bash guest

    log "setting password for administrator"
    passwd administrator

    log "setting password for guest"
    echo "guest:guest" | chpasswd
} 

chr_setup_bootloader() {
    log "setting up bootloader"
    grub-install /dev/sda 
    update-grub
}

chr_install_software() {
    log "installing software"

    tasksel install cinnamon-desktop
    tasksel install standard
    tasksel install laptop

    GUI_PKGS="papirus-icon-theme mint-y-icons geany thonny bibata-cursor-theme fonts-ibm-plex"
    apt install -y ${GUI_PKGS}
} 

chr_install_themes() {
    log "installing themes"
    
    mkdir -p /tmp/bootstrap_workdir
    cd /tmp/bootstrap_workdir
    curl -fLsSO "https://github.com/linuxmint/mint-themes/releases/download/master.lmde6/packages.tar.gz"
    tar xpf packages.tar.gz
    cd packages
    ar x *.deb
    tar xpf data.tar.xz
    cp -rf usr/share/themes/Mint-* /usr/share/themes/

    log "setting themes for users"
    
    mkdir -p /etc/dconf/profile
    cat <<EOF > /etc/dconf/profile/user
user-db:user
system-db:msb
EOF

    mkdir -p /etc/dconf/db/msb.d
    cat <<EOF > /etc/dconf/db/msb.d/00_msb_settings
[org/cinnamon/desktop/interface]
cursor-theme='Bibata-Original-Classic'
font-name='IBM Plex Sans 10'
gtk-theme='Mint-Y-Dark-Aqua'
icon-theme='Mint-Y-Aqua'

[org/cinnamon/desktop/wm/preferences]
titlebar-font='IBM Plex Sans 10'

[org/cinnamon/theme]
name='Mint-Y-Dark-Aqua'

[org/gnome/desktop/interface]
cursor-size=24
cursor-theme='Bibata-Original-Classic'
document-font-name='IBM Plex Sans 10'
font-name='IBM Plex Sans 10'
gtk-theme='Mint-Y-Dark-Aqua'
icon-theme='Mint-Y-Aqua'
monospace-font-name='IBM Plex Mono 11'

[org/gnome/desktop/wm/preferences]
titlebar-font='IBM Plex Sans 10'

[org/nemo/desktop]
font='IBM Plex Sans 10'
EOF

    dconf update
    chmod a+rx -R /etc/dconf
    
    # set default apps for all users
    local settingsdir="/etc/skel/.config/cinnamon/spices/grouped-window-list@cinnamon.org"
    mkdir -p $settingsdir
    cat <<EOF > "${settingsdir}/2.json"
{
    "pinned-apps": {
        "default": [
            "firefox-esr.desktop",
            "chromium.desktop",
            "org.gnome.Terminal.desktop",
            "nemo.desktop",
            "libreoffice-startcenter.desktop",
            "libreoffice-writer.desktop",
            "libreoffice-calc.desktop",
            "libreoffice-impress.desktop",
            "geany.desktop",
            "org.thonny.Thonny.desktop"
        ],
    }
}
EOF
}

main_chroot() {
    log "fleet laptop boostrapper (chroot)"

    chr_update_repos
    
    # locales first cos some pkgs might need
    chr_configure_locales

    chr_install_pkgs
    chr_configure_tz
    chr_configure_networking
    chr_enable_services
    chr_setup_bootloader
    chr_install_software
    chr_install_themes
    chr_add_users

    log "done!"
}

if [[ "${FLBOOTSTRAP_IN_CHROOT}" != "1" ]]; then
    main
else
    main_chroot
fi

