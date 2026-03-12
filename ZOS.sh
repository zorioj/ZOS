#!/usr/bin/env bash
#
# Script name: dtosinstall
# Description: A lightweight kickass Arch Linux installer.
# Dependencies: 
# GitLab: https://www.gitlab.com/dtos/dtosinstall/
# License: https://www.gitlab.com/dtos/dtosinstall/
# Contributors: Derek Taylor

# Set with the flags "-e", "-u","-o pipefail" cause the script to fail
# if certain things happen, which is a good thing.  Otherwise, we can
# get hidden bugs that are hard to discover.
set -euo pipefail

# Let's clear the tty when starting script
clear

if [ ! -d "/sys/firmware/efi/" ]; then
    echo "ERROR: Your system is using legacy BIOS."
    echo "ZOS only supports UEFI installations."
    echo "To install ZOS, you must enable UEFI on this machine."
    exit
fi

BOLD='\e[1m'
GREEN='\e[92m'
RED='\e[91m'
YELLOW='\e[93m'
RESET='\e[0m'

#get paru

print_info () {
    echo -ne "${BOLD}${YELLOW}$1${RESET}\n"
}

print_choice () {
    echo -ne "${BOLD}${GREEN}>> $1${RESET}\n\n"
}

invalid_input () {
    print_info "\n${RED}WARNING! Invalid input!"
    print_info "Please enter a valid option."
}

menu() {
    # Start from the 3rd argument
    for ((i=3; i<$#; i++)); do
      local my_array=("${@:i:1}")  
    done
    while true; do
        print_info "$1"
        PS3="$2"
        select choice in "${my_array[@]}";
        do
	    # shellcheck disable=SC2076
            if [[ ! " ${my_array[*]} " =~ " ${choice} " ]]; then
		invalid_input
            else
		break
            fi
        done
        break
    done
}

# num_input () {
#     while true; do
#         print_info "$1"
#         read -r -e -p "$2" num
#         if [[ $num =~ ^-?[0-9]+$ ]]; then
#             break
#         else
#             invalid_input
#         fi
#     done
# }

txt_input () {
    while true; do
        print_info "$1"
        read -r -e -p "$2" txt
        if [ -n "$txt" ]; then
            break
        else
            invalid_input
        fi
    done
}

passwd_input () {
    while true; do
        print_info "$1"
        read -r -s -p "$2" txt
        if [ -n "$txt" ]; then
            break
        else
            invalid_input
        fi
    done
}


fzf_menu() {
    # Start from the 2rd argument
    for ((i=2; i<$#; i++)); do
      local my_array=("${@:i:1}")  
    done
    while true; do
        print_info "$1"
        choice=$(fzf --exact --reverse --prompt "$1" < <(printf "%s\n" "${my_array[@]}"))
	# shellcheck disable=SC2076
        if [[ ! " ${my_array[*]} " =~ " ${choice} " ]]; then
            invalid_input
        else
            break
        fi
    done
}

vm_check () {
    hypervisor=$(systemd-detect-virt)
    case $hypervisor in
        kvm )       pacstrap /mnt qemu-guest-agent &>/dev/null
                    systemctl enable qemu-guest-agent --root=/mnt &>/dev/null
                    ;;
        vmware  )   pacstrap /mnt open-vm-tools &>/dev/null
                    systemctl enable vmtoolsd --root=/mnt &>/dev/null
                    systemctl enable vmware-vmblock-fuse --root=/mnt &>/dev/null
                    ;;
        oracle )    pacstrap /mnt virtualbox-guest-utils &>/dev/null
                    systemctl enable vboxservice --root=/mnt &>/dev/null
                    ;;
        microsoft ) pacstrap /mnt hyperv &>/dev/null
                    systemctl enable hv_fcopy_daemon --root=/mnt &>/dev/null
                    systemctl enable hv_kvp_daemon --root=/mnt &>/dev/null
                    systemctl enable hv_vss_daemon --root=/mnt &>/dev/null
                    ;;
    esac
}

echo -e "${BOLD}${YELLOW}\
__/\\\\\\\\\\\\\\\_______/\\\\\__________/\\\\\\\\\\\___        
 _\////////////\\\______/\\\///\\\______/\\\/////////\\\_       
  ___________/\\\/_____/\\\/__\///\\\___\//\\\______\///__      
   _________/\\\/______/\\\______\//\\\___\////\\\_________     
    _______/\\\/_______\/\\\_______\/\\\______\////\\\______    
     _____/\\\/_________\//\\\______/\\\__________\////\\\___   
      ___/\\\/____________\///\\\__/\\\_____/\\\______\//\\\__  
       __/\\\\\\\\\\\\\\\____\///\\\\\/_____\///\\\\\\\\\\\/___ 
        _\///////////////_______\/////_________\///////////_____
${RESET}" 
echo -e "${BOLD}       The installation script for ZOS${RESET}\n"

print_info "Listing the available disks:"
lsblk -e 7
mapfile -t my_array < <(lsblk -dpno NAME | grep -P "/dev/sd|nvme|vd")
menu "\nPlease select the disk for installation:" "Please select the number of the disk: " "${my_array[*]}"
disk="$choice"
print_choice "disk: $disk"

print_info "Choose the file system type:"
my_array=("btrfs [recommended]" "ext4")
menu "Please select the file system type:" "Please select the number of the file system: "
fs_type=${choice// [recommended\]/}
print_choice "fs_type: $fs_type"

## ENCRYPTION YES OR NO - NOT IMPLEMENTED - ENCRYPTION IS AUTOMATICALLY SETUP
my_array=("yes [recommended]" "no")
menu "Disk encryption:" "Would you like to encrypt the disk? "
encryption=${choice// [recommended\]/}
print_choice "encryption: $encryption" 

## SWAP TYPE - NOT IMPLEMENTED - ZRAM IS AUTOMATICALLY SETUP
# my_array=("zram [recommended]" "file" "partition" "none")
# menu "Choose type of swap to use:" "Please select the number for desired swap type: "
# swap_type=${choice// [recommended\]/}
# print_choice "swap_type: $swap_type" 

## SWAP SIZE - NOT IMPLEMENTED - USEFUL IF I OFFER SWAP CHOICES AT SOME POINT
# num_input "What size swap should be used?" "Please enter number (in gigabytes) for swap size: "
# swap_size="$num"
# print_choice "swap_size: ${swap_size}G" 

## CHOOSE BOOTLOADER - NOT IMPLEMENTED - GRUB IS AUTOMATICALLY INSTALLED
# my_array=("grub [recommended]" "refind" "systemd-boot")
# menu "Choose a bootloader to install:" "Please select the number for desired bootloader: "
# bootloader=${choice// [recommended\]/}
# print_choice "bootloader: $bootloader" 

mapfile -t my_array < <(grep -E '^#[a-z]' /etc/locale.gen | cut -c 2- | awk '{print $1}')
fzf_menu "Please select a locale [ex: en_us.UTF-8]: " "${my_array[*]}"
locale="$choice"
print_choice "locale: $locale"

mapfile -t my_array < <(localectl list-keymaps)
fzf_menu "Please select the keyboard layout [ex: us]: " "${my_array[*]}"
keymap="$choice"
print_choice "keymap: $keymap"
loadkeys "$keymap"

mapfile -t my_array < <(timedatectl list-timezones)
fzf_menu "Please select the timezone: " "${my_array[*]}"
timezone="$choice"
print_choice "timezone: $timezone"

txt_input "Set the hostname for this computer:" "Please enter hostname: "
hostname="$txt"
print_choice "hostname: $hostname" 

if [[ "$encryption" = "yes" ]]; then
    while true; do
        passwd_input "LUKS disk encryption:" "Please enter a password for LUKS disk encryption: "
        lukspass1="$txt"
        passwd_input "" "Retype the password for LUKS disk encryption: "
        lukspass2="$txt"
        if [[ "$lukspass1" != "$lukspass2" ]]; then
            echo -e "\nPasswords do not match! Please try again."
        else
            print_choice "\nLUKS password successfully set."
    	lukspass="$lukspass1"
            break
        fi
    done
fi

while true; do
    passwd_input "Root password:" "Please enter a root password: "
    rootpass1="$txt"
    passwd_input "" "Retype the root password: "
    rootpass2="$txt"
    if [[ "$rootpass1" != "$rootpass2" ]]; then
        echo -e "\nPasswords do not match! Please try again."
    else
        print_choice "\nRoot password successfully set."
	rootpass="$rootpass1"
        break
    fi
done

txt_input "Create your user:" "Please enter desired username: "
username="$txt"
print_choice "username: $username" 

while true; do
    passwd_input "User password:" "Please enter a password for $username: "
    userpass1="$txt"
    passwd_input "" "Retype the password for $username: "
    userpass2="$txt"
    if [[ "$userpass1" != "$userpass2" ]]; then
        echo -e "\nPasswords do not match! Please try again."
    else
        print_choice "\nPassword successfully set for $username."
	userpass="$userpass1"
        break
    fi
done

print_info "---------------------------------"
print_info "SUMMARY OF CONFIGURATION CHOICES:"
print_info "---------------------------------"
echo -e "disk:\t\t${BOLD}${GREEN}$disk${RESET}"
echo -e "fs_type:\t${BOLD}${GREEN}$fs_type${RESET}"
echo -e "encryption:\t${BOLD}${GREEN}$encryption${RESET}"
# echo -e "swap_type:\t${BOLD}${GREEN}$swap_type${RESET}" 
# echo -e "swap_size:\t${BOLD}${GREEN}${swap_size}G${RESET}"
echo -e "locale:\t\t${BOLD}${GREEN}$locale${RESET}"
echo -e "keymap:\t\t${BOLD}${GREEN}$keymap${RESET}"
echo -e "timezone:\t${BOLD}${GREEN}$timezone${RESET}"
echo -e "hostname:\t${BOLD}${GREEN}$hostname${RESET}"
echo -e "lukspass:\t${BOLD}${GREEN}✓${RESET}"
echo -e "rootpass:\t${BOLD}${GREEN}✓${RESET}"
echo -e "username:\t${BOLD}${GREEN}$username${RESET}"
echo -e "userpass:\t${BOLD}${GREEN}✓${RESET}"

print_info "${RED}WARNING! Please review the above configuration.${RESET}"
print_info "Based on this configuration, would you like to install ZOS?"

while true; do
    yes_no=("yes"
            "no")
    PS3="Would you like to install ZOS? "
    select choice in "${yes_no[@]}";
    do
        install_ZOS="$choice"
	# shellcheck disable=SC2076
        if [[ ! " ${yes_no[*]} " =~ " ${choice} " ]]; then
	    invalid_input
        else
            print_choice "You chose \"$install_ZOS\" to installing ZOS!"
            break
	fi
    done
    if [ "$install_ZOS" = "yes" ]; then
        ## One last check before wiping the disk!

        print_info "Formatting the disk: $disk"
        while true; do
            yes_no=("yes"
                    "no")
            PS3="All data on $disk will be lost.  Do you wish to proceed with the installation? "
            select choice in "${yes_no[@]}";
            do
                format_drive="$choice"
                if [[ "$format_drive" = "yes" ]]; then
                    print_choice "Formatting the drive and installing ZOS."
                    print_info "Wiping $disk."
                    wipefs -af "$disk"
                    sgdisk -Zo "$disk"
                    break
                elif [[ "$format_drive" = "no" ]]; then
                    print_choice "Exiting before formatting the drive."
                    exit
		elif [[ ! " ${yes_no[*]} " =~ " ${format_drive} " ]]; then
                    invalid_input
		fi
	    done
	    break
        done
	
        print_info "Reflector grabbing top 20 mirrors sorted by download rate."
        echo "This may take a couple of minutes."
        reflector --latest 20 --sort rate --save /etc/pacman.d/mirrorlist &>/dev/null

        print_info "Partitioning the disk: ${disk}"
        echo "File system type: $fs_type"
        parted -s "$disk" \
            mklabel gpt \
            mkpart ESP fat32 1MiB 1025MiB \
            set 1 esp on \
            mkpart CRYPTROOT 1025MiB 100% \
        
        ESP="/dev/disk/by-partlabel/ESP"
        CRYPTROOT="/dev/disk/by-partlabel/CRYPTROOT"
        
        partprobe "$disk"
        
        print_info "Formatting EFI Partition as FAT32."
        mkfs.fat -F 32 "$ESP"
        
        if [[ "$encryption" = "yes" ]]; then
            print_info "Creating LUKS container for root partition."
            echo -n "$lukspass" | cryptsetup luksFormat "$CRYPTROOT" -d -
            echo -n "$lukspass" | cryptsetup open "$CRYPTROOT" cryptroot -d - 
        fi

        if [[ "$fs_type" = "btrfs" ]]; then
            if [[ "$encryption" = "yes" ]]; then
                BTRFS="/dev/mapper/cryptroot"
            else
                BTRFS="$CRYPTROOT"
            fi
            
            print_info "Formatting the BTRFS partition."
            mkfs.btrfs "$BTRFS" &>/dev/null
            mount "$BTRFS" /mnt
            
            print_info "Creating BTRFS subvolumes."
            subvols=(snapshots var_pkgs var_log home root srv)
            for subvol in '' "${subvols[@]}"; do
                btrfs su cr /mnt/@"$subvol" &>/dev/null
            done
            
            print_info "Mounting the newly created subvolumes."
            umount /mnt
            mountopts="ssd,noatime,compress-force=zstd:3,discard=async"
            mount -o "$mountopts",subvol=@ "$BTRFS" /mnt
            mkdir -p /mnt/{home,root,srv,.snapshots,var/{log,cache/pacman/pkg},boot}
            for subvol in "${subvols[@]:2}"; do
                mount -o "$mountopts",subvol=@"$subvol" "$BTRFS" /mnt/"${subvol//_//}"
            done
            chmod 750 /mnt/root
            mount -o "$mountopts",subvol=@snapshots "$BTRFS" /mnt/.snapshots
            mount -o "$mountopts",subvol=@var_pkgs "$BTRFS" /mnt/var/cache/pacman/pkg
            chattr +C /mnt/var/log
            mount "$ESP" /mnt/boot/
        else
            if [[ "$encryption" = "yes" ]]; then
                EXT4="/dev/mapper/cryptroot"
            else
                EXT4="$CRYPTROOT"
            fi

            print_info "Formatting the EXT4 partition."
            mkfs.ext4 "$EXT4" &>/dev/null
            
            print_info "Mounting the newly created partitions."
            mount "$EXT4" /mnt
            mkdir -p /mnt/{home,root,srv,var/{log,cache/pacman/pkg},boot}
            chmod 750 /mnt/root
            # chattr +C /mnt/var/log
            mount "$ESP" /mnt/boot/
        fi

	print_info "Checking which microcode to install."
        CPU=$(grep vendor_id /proc/cpuinfo)
        if [[ "$CPU" == *"AuthenticAMD"* ]]; then
            print_choice "An AMD CPU has been detected, the AMD microcode will be installed."
            microcode="amd-ucode"
        else
            print_choice "An Intel CPU has been detected, the Intel microcode will be installed."
            microcode="intel-ucode"
        fi
        
        # Re-installing keyring because sometimes we have key problems
        print_info "Clearing the pacman cache."
        yes | pacman -Scc || print_choice "Finished clearing the cache."
        yes | pacman -Syy archlinux-keyring || print_choice "Could not install the Arch keyring."
	pacman-key --init
        pacman-key --populate
	
        print_info "Waiting for pacman keyring init to complete."
        if [[ $(systemctl show pacman-init.service | grep SubState=failed) ]]; then
            systemctl start pacman-init || echo "Error: pacman-init failed to start." && exit
	    sleep 10
        fi

        print_info "Installing the base system."
        pacstrap -K /mnt base base-devel linux-cachyos linux-cachyos-headers linux-firmware "$microcode"  
        pacstrap /mnt - < /root/pkgs-base

        if [[ "$fs_type" = "btrfs" ]]; then
            print_info "Installing important btrfs-related packages."
            pacstrap /mnt - < /root/pkgs-btrfs
	fi

        print_info "Enabling NetworkManager service."
        systemctl enable NetworkManager --root=/mnt &>/dev/null

        print_info "Setting the hostname as $hostname."
        echo "$hostname" > /mnt/etc/hostname

        print_info "Generating the fstab."
        genfstab -U /mnt >> /mnt/etc/fstab

        print_info "Configuring selected locale and keymap."
        sed -i "/^#$locale/s/^#//" /mnt/etc/locale.gen
        echo "LANG=$locale" > /mnt/etc/locale.conf
        echo "KEYMAP=$keymap" > /mnt/etc/vconsole.conf

        print_info "Setting hosts file."
        cat > /mnt/etc/hosts <<-EOF
        127.0.0.1   localhost
        ::1         localhost
        127.0.1.1   $hostname.localdomain   $hostname
EOF

        print_info "Virtual machine detected. Setting up VM guest tools."
        vm_check
	
        print_info "Configuring /etc/mkinitcpio.conf."
        cat > /mnt/etc/mkinitcpio.conf <<-EOF
        HOOKS=(systemd autodetect keyboard sd-vconsole modconf block sd-encrypt filesystems)
EOF
	print_info "Copying DTOS Grub theme into boot directory."
	mkdir -p /mnt/boot/grub/themes/ZOS-grub/
        rsync -avr /run/archiso/airootfs/usr/share/grub/themes/ZOS-grub/ /mnt/boot/grub/themes/ZOS-grub/
        sed -i "s/^GRUB_DISTRIBUTOR=\"Arch\"/GRUB_DISTRIBUTOR=\"ZOS\"/" /mnt/etc/default/grub
        sed -i "s/^#GRUB_THEME.*/GRUB_THEME=\"\/boot\/grub\/themes\/dtos-grub\/theme.txt\"/" /mnt/etc/default/grub
	
        if [[ "$encryption" = "yes" ]]; then
            print_info "Setting up LUKS encryption in grub."
            UUID=$(blkid -s UUID -o value $CRYPTROOT)
            if [[ "$fs_type" = "btrfs" ]]; then
                sed -i "\,^GRUB_CMDLINE_LINUX=\"\",s,\",&rd.luks.name=$UUID=cryptroot root=$BTRFS," /mnt/etc/default/grub
            else
                sed -i "\,^GRUB_CMDLINE_LINUX=\"\",s,\",&rd.luks.name=$UUID=cryptroot root=$EXT4," /mnt/etc/default/grub
            fi
        fi

        print_info "Running arch-chroot for system configuration."
        arch-chroot /mnt /bin/bash -e <<-EOF
        
            echo "Setting up timezone."
            ln -sf /usr/share/zoneinfo/$timezone /etc/localtime
        
            echo "Setting up clock."
            hwclock --systohc
        
            echo "Generating locales."
            locale-gen
        
            echo "Generating a new initramfs."
            mkinitcpio -P
        
            if [[ "$fs_type" = "btrfs" ]]; then
                echo "Configuring snapper."
                umount /.snapshots
                rm -r /.snapshots
                snapper --no-dbus -c root create-config /
                btrfs subvolume delete /.snapshots
                mkdir /.snapshots
                mount -a &>/dev/null
                chmod 750 /.snapshots
            fi
        
            echo "Installing GRUB bootloader."
            grub-install --target=x86_64-efi --efi-directory=/boot/ --bootloader-id=GRUB
        
            echo "Making GRUB config file."
            grub-mkconfig -o /boot/grub/grub.cfg

	    
            echo "Updating the man page database"
            mandb -c
EOF
	
        print_info "Setting root password."
        echo "root:$rootpass" | arch-chroot /mnt chpasswd

        print_info "Adding user $username to the system with root privileges."
        arch-chroot /mnt useradd -m -G wheel,audio,video,optical,storage -s /bin/fish "$username"
        echo "$username:$userpass" | arch-chroot /mnt chpasswd

        print_info "Copying files into new installation."
	mkdir -p /mnt/home/"$username"/.local/share/fonts/
        rsync -avr /run/archiso/airootfs/etc/skel/ /mnt/home/"$username"/
        rsync -avr /mnt/etc/dtos/ /mnt/home/"$username"/
        rsync -avr /run/archiso/airootfs/etc/sddm.conf.d/ /mnt/etc/sddm.conf.d/
        rsync -av /run/archiso/airootfs/etc/bash.bashrc /mnt/etc/
        rsync -av /run/archiso/airootfs/etc/doas.conf /mnt/etc/
        rsync -av /run/archiso/airootfs/etc/os-release /mnt/etc/
        rsync -av /run/archiso/airootfs/etc/pacman.conf /mnt/etc/
	mkdir -p /mnt/usr/share/backgrounds/ZOS-backgrounds/
        rsync -avr /run/archiso/airootfs/usr/share/backgrounds/ZOS-backgrounds/ /mnt/usr/share/backgrounds/ZOS-backgrounds/
       
        # NOT IMPLEMENTED YET!
        # mkdir -p /mnt/etc/pacman.d/hooks/
        # rsync -avr /run/archiso/airootfs/etc/pacman.d/hooks/ /mnt/etc/pacman.d/hooks/
 
        print_info "Changing some file permissions in user home directory."
	arch-chroot /mnt chown -R "$username:$username" /home/"$username"
	arch-chroot /mnt chmod -R 755 /home/"$username"/.local/bin/

        print_info "Removing files that could cause some conflicts."
	rm -rf /mnt/home/"$username"/.emacs.d
        rm /mnt/usr/share/wayland-sessions/qtile-wayland.desktop
	
        sed -i '/^Background=/c\Background=\"/\usr/\share/\backgrounds\/dtos-backgrounds/\0277.jpg\"' /mnt/usr/share/sddm/themes/eucalyptus-drop/theme.conf
	
        print_info "Configuring ZRAM."
        cat > /mnt/etc/systemd/zram-generator.conf <<-EOF
        [zram0]
        zram-size = min(ram / 2, 8192)
EOF

        print_info "Enabling systemd services."
        if [[ "$fs_type" = "btrfs" ]]; then
            services=(reflector.timer 
                      snapper-timeline.timer 
                      snapper-cleanup.timer 
                      btrfs-scrub@-.timer 
                      btrfs-scrub@home.timer 
                      btrfs-scrub@var-log.timer 
                      btrfs-scrub@\\x2esnapshots.timer 
                      grub-btrfsd.service
                      sddm.service
                      systemd-oomd.service
                      udisks2.service)
            for service in "${services[@]}"; do
                systemctl enable "$service" --root=/mnt
            done
        else
            services=(reflector.timer 
                      sddm.service
                      systemd-oomd.service
                      udisks2.service)
            for service in "${services[@]}"; do
                systemctl enable "$service" --root=/mnt
            done
        fi
    
    git clone https://aur.archlinux.org/yay.git
    cd yay
    yes | makepkg -si
    cd ..
    rm -d yay
    yay -S nscde-git
    
	print_info "Removing 'sudo' in favor of 'doas'."
        arch-chroot /mnt /bin/bash -e <<-EOF
            yes | pacman -Rdd sudo
            ln -s /usr/bin/doas /usr/bin/sudo
EOF

        print_info "Installation of ZOS completed! You may now reboot the computer."
        break
	
    elif [ "$install_dtos" = "no" ]; then
	exit
    else
        invalid_input
    fi
done

exit

