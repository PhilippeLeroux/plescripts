set PATH=%PATH%;"C:\Program Files\Oracle\VirtualBox"
VBoxManage controlvm K2 acpipowerbutton
echo "Attente de 20s"
timeout /t 20 >/nul
VBoxManage modifyvm K2 --memory 256
VBoxManage startvm K2 --type headless
