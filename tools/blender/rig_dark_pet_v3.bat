@echo off
setlocal
set "BLENDER=C:\Program Files\Blender Foundation\Blender 4.5\blender.exe"
set "SCRIPT=F:\project\tools\blender\rig_dark_pet_v3.py"
set "INPUT=F:\project\assets\pets\dark\3d\runtime\dark_pet_runtime.glb"
set "OUTPUT=F:\project\assets\pets\dark\3d\runtime\dark_pet_rigged_v3.glb"
if not exist "%BLENDER%" (echo Blender not found & pause & exit /b 1)
if not exist "%INPUT%" (echo Missing %INPUT% & pause & exit /b 1)
"%BLENDER%" --background --python "%SCRIPT%" -- "%INPUT%" "%OUTPUT%"
if errorlevel 1 (echo FAILED & pause & exit /b 1)
echo DONE: %OUTPUT%
pause
