@echo off
chcp 65001 >nul
title iiko Front + AnyDesk Автоустановка

setlocal enabledelayedexpansion

:: Самоподъём прав администратора
net session >nul 2>&1
if %errorLevel% == 0 (goto :main) else (
    echo Запрашиваю права администратора...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:main
echo =============================================
echo       iiko Front + AnyDesk Автоустановка
echo =============================================
echo.

mkdir "C:\Temp" 2>nul
set "LOGFILE=C:\Temp\iiko_install.log"
echo [%DATE% %TIME%] === Запуск установки === >> "%LOGFILE%"

set "installer=C:\Temp\Setup.Front.exe"
set "exePath=C:\Program Files\iiko\iikoRMS\Front.Net\iikoFront.Net.exe"
set "configPath=%USERPROFILE%\AppData\Roaming\iiko\CashServer\config.xml"
set "AnyDeskInstaller=C:\Temp\AnyDesk.exe"
set "AnyDeskPath=C:\Program Files (x86)\AnyDesk\AnyDesk.exe"

:: ====================== ВЫБОР ВЕРСИИ ======================
echo Актуальные версии iikoFront:
echo.
echo 1. 9.5.6087.0
echo 2. 9.4.9005.0
echo 3. 9.4.8049.0
echo 4. 9.4.7039.0
echo 5. 9.4.6046.0
echo 6. 9.3.7033.0
echo 7. 9.3.6065.0
echo 8. 9.2.9018.0
echo 9. 9.2.8035.0
echo 10. Ввести свою версию
echo.

choice /C 123456789A /N /M "Выберите версию (1-10): "

if errorlevel 10 (
    set /p "version=Введите версию: "
) else if errorlevel 9 (set "version=9.2.8035.0"
) else if errorlevel 8 (set "version=9.2.9018.0"
) else if errorlevel 7 (set "version=9.3.6065.0"
) else if errorlevel 6 (set "version=9.3.7033.0"
) else if errorlevel 5 (set "version=9.4.6046.0"
) else if errorlevel 4 (set "version=9.4.7039.0"
) else if errorlevel 3 (set "version=9.4.8049.0"
) else if errorlevel 2 (set "version=9.4.9005.0"
) else (set "version=9.5.6087.0")

echo Выбрана версия: %version%

:: ====================== ОТКЛЮЧЕНИЕ ЗАЩИТЫ ======================
echo.
echo Отключаем Firewall и Defender...
netsh advfirewall set allprofiles state off >nul 2>&1
powershell -Command "Set-MpPreference -DisableRealtimeMonitoring $true" >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender" /v DisableAntiSpyware /t REG_DWORD /d 1 /f >nul 2>&1

:: ====================== УСТАНОВКА IIKO ======================
echo.
echo 1. Установка iiko Front...
curl -u "partners:partners#iiko" --ftp-pasv -L -f --retry 3 -o "%installer%" "ftp://ftp.iiko.ru/release_iiko/%version%/Setup/Offline/Setup.Front.exe"

if %errorlevel% neq 0 (
    echo ОШИБКА скачивания iiko!
    pause
    exit /b
)

"%installer%" /install /quiet /norestart FrontMode=UI
timeout /t 40 /nobreak >nul

echo Запускаем iikoFront на 15 секунд...
if exist "%exePath%" (
    start "" "%exePath%"
    timeout /t 15 /nobreak >nul
    taskkill /f /im iikoFront.Net.exe >nul 2>&1
)

:: Правильный ярлык в автозагрузку
echo Создаём ярлык iikoFront в автозагрузку...
powershell -Command ^
"$WshShell = New-Object -comObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut('%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\iikoFront.lnk'); $Shortcut.TargetPath = '%exePath%'; $Shortcut.WorkingDirectory = '%exePath:\iikoFront.Net.exe=%'; $Shortcut.Save()" >nul 2>&1

:: Правка config
if exist "%configPath%" (
    powershell -NoProfile -Command "(Get-Content '%configPath%' -Raw) -replace '<AllowHandCardRoll>false</AllowHandCardRoll>', '<AllowHandCardRoll>true</AllowHandCardRoll>' -replace '<ShowMinimizeButton>false</ShowMinimizeButton>', '<ShowMinimizeButton>true</ShowMinimizeButton>' | Set-Content '%configPath%' -Encoding UTF8"
    echo ✓ config.xml изменён
)

:: ====================== ANYDESK ======================
echo.
echo =============================================
echo             Установка AnyDesk
echo =============================================

echo Скачиваем AnyDesk...
curl -L -o "%AnyDeskInstaller%" "https://download.anydesk.com/AnyDesk.exe" --silent --retry 3

if exist "%AnyDeskInstaller%" (
    echo Устанавливаем AnyDesk...
    "%AnyDeskInstaller%" --install "%ProgramFiles(x86)%\AnyDesk" --start-with-win --create-shortcuts
    
    echo Запускаем AnyDesk на 15 секунд...
    start "" "%AnyDeskPath%"
    timeout /t 15 /nobreak >nul
    taskkill /f /im AnyDesk.exe >nul 2>&1

    echo Устанавливаем пароль @iikoweb@# ...
    echo @iikoweb@#| "%AnyDeskPath%" --set-password

    echo Добавляем AnyDesk в автозагрузку...
    powershell -Command ^
    "$WshShell = New-Object -comObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut('%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\AnyDesk.lnk'); $Shortcut.TargetPath = '%AnyDeskPath%'; $Shortcut.Save()" >nul 2>&1

    echo Получаем AnyDesk ID...
    timeout /t 8 /nobreak >nul
    for /f "tokens=*" %%a in ('"%AnyDeskPath%" --get-id 2^>nul') do set "AnyDeskID=%%a"

    if not "%AnyDeskID%"=="" (
        echo AnyDesk ID: %AnyDeskID%
        echo Меняем имя компьютера на %AnyDeskID%...
        powershell -Command "Rename-Computer -NewName '%AnyDeskID%' -Force" >nul 2>&1
    )
) else (
    echo ОШИБКА скачивания AnyDesk!
    pause
    exit /b
)

:: ====================== ЗАВЕРШЕНИЕ ======================
echo.
echo =============================================
echo         УСТАНОВКА УСПЕШНО ЗАВЕРШЕНА!
echo =============================================
echo AnyDesk пароль: @iikoweb@#
if defined AnyDeskID echo Новое имя ПК: %AnyDeskID%
echo.

set /a "code=%RANDOM% %% 900 + 100"
echo Код подтверждения: %code%
echo.
set /p "input=Введите код для перезагрузки: "

if "%input%"=="%code%" (
    echo Перезагрузка через 5 секунд...
    timeout /t 5 /nobreak >nul
    shutdown /r /t 3 /c "Перезагрузка после настройки" /f
) else (
    echo Перезагрузка отменена.
    pause
)