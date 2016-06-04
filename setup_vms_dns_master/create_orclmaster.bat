set echo off 
rem Nom de la VM
set VM_NAME=orclmaster

rem mémoire :
set VM_MEMORY=4096

call createvm.bat

VBoxManage showvminfo %VM_NAME% > %VM_NAME%.info 
