set echo off 

rem Nom de la VM
set VM_NAME=K2

set SHARED_WINDOWS_PATH=C:\Program Files\Oracle\VirtualBox

rem mémoire :
rem Pour l'installation de l'OS 1Gb c'est mieux
rem mais passer la mémoir à 256 après.
set VM_MEMORY=1024

call createvm.bat

VBoxManage storageattach %VM_NAME% --storagectl IDE  --port 1 --device 0 --type dvddrive --medium "C:\Program Files\Oracle\VirtualBox\VBoxGuestAdditions.iso"

VBoxManage sharedfolder add %VM_NAME% --name "shared" --hostpath "%SHARED_WINDOWS_PATH%" --automount

VBoxManage createhd --filename "%VM_PATH%\%VM_NAME%\asm01.vdi" --size 524288
VBoxManage storageattach %VM_NAME% --storagectl SATA --port 1 --device 0 --type hdd --medium "%VM_PATH%\%VM_NAME%\asm01.vdi"

VBoxManage showvminfo %VM_NAME% > %VM_NAME%.info
