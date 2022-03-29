#!/bin/bash

echo "######################################################################################"
echo "#                                                                                    #"
echo "#                                                                                    #"
echo "# Phil Bendeck | Cloudian Professional Services 2021                                 #"
echo "#                                                                                    #"
echo "######################################################################################"
echo

echo -e "--> Welcome to the automated Cassandra directory creation script."
echo -e "--> It executes the following operations:"
echo
echo -e "   1. The script will request the end-user to select the block-device from lsblk"
echo -e "   2. The script will use sgdisk to create a single partition using the Linux Filesystem HEX 8300"
echo -e "   3. The script will automatically add the entry in /etc/fstab with the corresponding options and mount-point of /var/lib/cassandra."
echo -e "   4. The script will execute a mount -v /var/lib/cassandra" '\n'

function choosedisk {
        n=0
	for disk in "${array[@]}"
        do
          	printf "$n: $disk\n"
                n=$((n+1))
        done
	read -r -p "Choice: " choice
        re='^[0-9]+$' #Make sure $choice is a number
        until [[ $choice =~ $re ]]; do
                if ! [[ $choice =~ $re ]]; then
                        echo "Error: Please enter the NUMBER of your choice."
                        choosedisk
                fi
        done
	IFS=' ' read -r -a diskparts <<< "${array[$choice]}"
}

# Create array of disks to choose from.
lsblk -dn -o NAME,SIZE,TYPE > disks
n=0
while read line; do
        array[$n]=$line
        n=$((n+1))
done < disks

echo "--> Select block-device from the list:"
choosedisk

# Check for existence of /dev/(choice). If it doesn't exist, user entered invalid option.
diskexists=0
until [ "$diskexists" = "1" ]; do
        if [ -b /dev/${diskparts[0]} ]; then
                let diskexists=1
                echo "--> You are formatting block-device /dev/${diskparts[0]} on $HOSTNAME."
                read -r -p "--> Confirm that you will be formatting /dev/${diskparts[0]} [Y or N]: " formatdisk
                if [ "$formatdisk" = "Y" ]; then
                        echo "Install will proceed."

			# Partition/format drive
			# List physical disks
			lsblk -dn -o NAME,SIZE,TYPE --include 8
			echo "--> Executing sgdisk -Z /dev/${diskparts[0]}"
			sgdisk -Z /dev/${diskparts[0]}
			echo "--> sgdisk -n 1 -t 1:8300 -c 1:"Linux Filesystem" /dev/${diskparts[0]}"
			sgdisk -n 1 -t 1:8300 -c 1:"Linux Filesystem" /dev/${diskparts[0]}
			sgdisk -p /dev/${diskparts[0]}
            #echo "/dev/${diskparts[0]}1"	

			# Create EXT4 Filesystem on Device
            echo "--> mkfs.ext4 -i 8192 -m 0 -O dir_index,extent,flex_bg,large_file,sparse_super,uninit_bg /dev/${diskparts[0]}1"
            mkfs.ext4  -i 8192 -m 0 -O dir_index,extent,flex_bg,large_file,sparse_super,uninit_bg /dev/${diskparts[0]}1
            echo "--> Creating /var/lib/cassandra"
            mkdir -v /var/lib/cassandra && chown -Rv cloudian:cloudian /var/lib/cassandra

            # Add Entry to fstab
            echo "--> Getting blkid UUID of /dev/${diskparts[0]}1"
            blkid=$(blkid -o value -s UUID /dev/${diskparts[0]}1)
            echo "--> UUID=$blkid"
            echo "UUID="$blkid" /var/lib/cassandra	ext4    defaults,rw,nosuid,noexec,nodev,noatime,data=ordered,errors=remount-ro    0       1" >> /etc/fstab
            mount -v /var/lib/cassandra

                else
                        echo "--> Disk formatting has been cancelled by $USER."
                fi
        else
                echo "Disk $choice does not exist."
                choosedisk
        fi
done
rm disks #Delete tmp file.
