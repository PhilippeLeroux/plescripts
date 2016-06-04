rem Répertoire contenant les binaires VirtualBox
set PATH=%PATH%;VIRTUALBOX_PATH

rem Répertoire qui contiendra les VMs
set VM_PATH=VIRTUALBOX_VM_PATH

rem Chemin complet de l'ISO Linux Ã  utiliser
set ISO_PATH=VIRTUALBOX_LINUX_ISO_PATH

VBoxManage createvm --name %VM_NAME% --register
VBoxManage modifyvm %VM_NAME% --ostype Oracle_64
VBoxManage modifyvm %VM_NAME% --acpi on
VBoxManage modifyvm %VM_NAME% --ioapic on
VBoxManage modifyvm %VM_NAME% --memory %VM_MEMORY%
VBoxManage modifyvm %VM_NAME% --vram 12
VBoxManage modifyvm %VM_NAME% --cpus 4
VBoxManage modifyvm %VM_NAME% --rtcuseutc on
VBoxManage modifyvm %VM_NAME% --nic1 bridged 
VBoxManage modifyvm %VM_NAME% --nictype1 virtio
VBoxManage modifyvm %VM_NAME% --bridgeadapter1 "Realtek RTL8188CU Wireless LAN 802.11n USB 2.0 Network Adapter"
VBoxManage modifyvm %VM_NAME% --nic2 intnet
VBoxManage modifyvm %VM_NAME% --nictype2 virtio
VBoxManage modifyvm %VM_NAME% --nic3 intnet
VBoxManage modifyvm %VM_NAME% --nictype3 virtio
VBoxManage modifyvm %VM_NAME% --audio dsound
VBoxManage modifyvm %VM_NAME% --usb on
VBoxManage modifyvm %VM_NAME% --usbehci on
VBoxManage storagectl %VM_NAME% --name IDE --add IDE --controller PIIX4 
VBoxManage storageattach %VM_NAME% --storagectl IDE --port 0 --device 0 --type dvddrive --medium "%ISO_PATH%"
VBoxManage createhd --filename "%VM_PATH%\%VM_NAME%\%VM_NAME%.vdi" --size 131072
VBoxManage storagectl %VM_NAME% --name SATA --add SATA --controller IntelAhci --portcount 1
VBoxManage storageattach %VM_NAME% --storagectl SATA --port 0 --device 0 --type hdd --medium "%VM_PATH%\%VM_NAME%\%VM_NAME%.vdi"
VBoxManage showvminfo %VM_NAME% > %VM_NAME%.info
