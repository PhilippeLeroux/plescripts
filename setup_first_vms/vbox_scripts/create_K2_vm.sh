#!/bin/sh

export VM_PATH="$HOME/VirtualBox VMs"

export VM_NAME=K2

export VM_MEMORY=1024

~/plescripts/setup_first_vms/vbox_scripts/createvm.sh

#VBoxManage storageattach $VM_NAME --storagectl IDE  --port 1 --device 0 --type dvddrive --medium "C:\Program Files\Oracle\VirtualBox\VBoxGuestAdditions.iso"
VBoxManage sharedfolder add $VM_NAME --name "shared" --hostpath "$HOME/shared" --automount

VBoxManage createhd --filename "$VM_PATH/$VM_NAME/asm01.vdi" --size 131072
VBoxManage storageattach $VM_NAME --storagectl SATA --port 1 --device 0 --type hdd --medium "$VM_PATH/$VM_NAME/asm01.vdi"

VBoxManage showvminfo $VM_NAME > $VM_NAME.info
