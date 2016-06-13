rem Répertoire contenant les binaires VirtualBox
set PATH=%PATH%;C:\Program Files\Oracle\VirtualBox

rem Répertoire qui contiendra les VMs
set VM_PATH=C:\Program Files\Oracle\VirtualBox

rem Chemin complet de l'ISO Linux à utiliser
set ISO_PATH=C:\Program Files\Oracle\VirtualBox

VBoxManage createvm --name %VM_NAME% --register
VBoxManage modifyvm %VM_NAME% --ostype Oracle_64
VBoxManage modifyvm %VM_NAME% --acpi on
VBoxManage modifyvm %VM_NAME% --ioapic on
VBoxManage modifyvm %VM_NAME% --memory %VM_MEMORY%
VBoxManage modifyvm %VM_NAME% --vram 12
VBoxManage modifyvm %VM_NAME% --cpus 4
VBoxManage modifyvm %VM_NAME% --rtcuseutc on

VBoxManage modifyvm %VM_NAME% --nic1 hostonly
VBoxManage modifyvm %VM_NAME% --hostonlyadapter1 "VirtualBox Host-Only Ethernet Adapter"
VBoxManage modifyvm %VM_NAME% --nictype1 virtio

VBoxManage modifyvm %VM_NAME% --nic2 intnet
VBoxManage modifyvm %VM_NAME% --nictype2 virtio

if %VM_NAME% NEQ K2 goto AFTER_NIC3
VBoxManage modifyvm %VM_NAME% --nic3 bridged
VBoxManage modifyvm %VM_NAME% --bridgeadapter3 "Realtek RTL8188CU Wireless LAN 802.11n USB 2.0 Network Adapter"
VBoxManage modifyvm %VM_NAME% --nictype3 virtio
:AFTER_NIC3
VBoxManage modifyvm %VM_NAME% --audio dsound
VBoxManage modifyvm %VM_NAME% --usb on
VBoxManage modifyvm %VM_NAME% --usbehci on
VBoxManage storagectl %VM_NAME% --name IDE --add IDE --controller PIIX4 
VBoxManage storageattach %VM_NAME% --storagectl IDE --port 0 --device 0 --type dvddrive --medium "%ISO_PATH%"
VBoxManage createhd --filename "%VM_PATH%\%VM_NAME%\%VM_NAME%.vdi" --size 131072
VBoxManage storagectl %VM_NAME% --name SATA --add SATA --controller IntelAhci --portcount 1
VBoxManage storageattach %VM_NAME% --storagectl SATA --port 0 --device 0 --type hdd --medium "%VM_PATH%\%VM_NAME%\%VM_NAME%.vdi"
