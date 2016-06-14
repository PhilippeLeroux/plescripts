set echo off 
rem Nom de la VM
set VM_NAME=MASTER_NAME

rem mémoire :
set VM_MEMORY=VM_MEMORY_MB_FOR_MASTER

call createvm.bat

VBoxManage showvminfo %VM_NAME% > %VM_NAME%.info 
