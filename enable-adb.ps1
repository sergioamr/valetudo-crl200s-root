# PowerShell script to enable ADB access to Mi Vacuum Mop P

function Main {
    # Check if adb is installed
    $adbPath = Get-Command adb -ErrorAction SilentlyContinue
    if (-not $adbPath) {
        Write-Host "Please install adb." -ForegroundColor Red
        Write-Host "You can download it from: https://developer.android.com/studio/releases/platform-tools" -ForegroundColor Yellow
        exit 1
    }

    Write-Host "ADB found at: $($adbPath.Source)" -ForegroundColor Green

    Write-Host @"

This script will help you enable ADB access to your Mi Vacuum Mop P

Please make sure of the following before starting:
1. Your robot is powered off
2. The battery is disconnected
3. You have a working micro-USB cable plugged into the robot and ready to plug into your computer.

IMPORTANT: On Windows, you may need to install USB drivers for ADB to recognize the device.
If ADB doesn't detect your device, try:
- Installing Universal ADB Drivers or Google USB Driver
- Checking Device Manager for unrecognized devices
- Trying a different USB port (preferably USB 2.0)
- Using a different USB cable

Press [Enter] to continue

"@
    Read-Host

    # Check USB drivers first
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Checking USB Device Drivers" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan
    Check-UsbDrivers
    Show-RecentUsbDevices

    # Restart ADB server
    Write-Host "`nRestarting ADB server..." -ForegroundColor Cyan
    & adb kill-server 2>&1 | Out-Null
    Start-Sleep -Seconds 1
    & adb start-server 2>&1 | Out-Null
    Write-Host "ADB server restarted." -ForegroundColor Green

    # Check initial device status
    Write-Host "`nChecking for connected devices..." -ForegroundColor Cyan
    $devices = & adb devices 2>&1
    Write-Host "Current ADB devices:" -ForegroundColor Yellow
    Write-Host $devices
    Write-Host ""

    # If no devices found, check again and provide driver help
    if ($devices -match "no devices|List of devices attached" -and $devices -notmatch "device$") {
        Write-Host "`nWARNING: No ADB devices detected!" -ForegroundColor Yellow
        Write-Host "Checking USB devices that might need driver installation...`n" -ForegroundColor Yellow
        Check-UsbDevicesForAdb
    }

    Connect-Adb

    Write-Host @"


The ADB shell should be fixed and permanent after the next reboot.
To get a shell, unplug and replug the USB cable once again. It won't say 'kaichi' this time.
After it has booted you should be able to connect via "adb shell".

Please note that the robot won't work in this state as we had to disable the core process to persist the adb shell.
This also means that it will reboot every four minutes which will be fixed after you've installed the rooted firmware image.

"@
}

function Connect-Adb {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Step 1: Initial Connection" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan

    Write-Host "We'll now try to connect to the ADB shell. Please connect the USB cable to your computer."
    Write-Host "If you hear the Robot voice ('kaichi'), wait another two seconds and unplug and reconnect the cable."
    Write-Host "If nothing happens try replugging the USB cable. This may take 10 or more attempts.`n"

    Write-Host "Waiting for device to be detected by ADB..." -ForegroundColor Yellow
    Write-Host "(This will keep trying until a device is found - you may need to replug the USB cable)`n" -ForegroundColor Gray

    Fix-AdbShell
    Write-Host "`nShell fixed..." -ForegroundColor Green

    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Step 2: Persisting ADB Shell" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan

    Persist-AdbShell

    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Step 3: Final Connection" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan

    Write-Host "Please replug the USB cable again. Do not unplug once you hear the sound."
    Write-Host "Waiting for ADB shell to be ready..." -ForegroundColor Yellow

    Wait-ForAdbShell
    Write-Host "`nShell is present!" -ForegroundColor Green
}

function Invoke-AdbLoop {
    param([string[]]$Arguments, [string]$OperationName = "Operation")

    $attempt = 0
    $maxAttempts = 200  # Allow up to 100 seconds (200 * 500ms)

    Write-Host "Attempting: adb $($Arguments -join ' ')" -ForegroundColor Gray

    while ($true) {
        $attempt++
        if ($attempt % 10 -eq 0) {
            Write-Host "[Attempt $attempt] Still waiting for device... (replug USB cable if needed)" -ForegroundColor Yellow
            # Show current device status
            $deviceStatus = & adb devices 2>&1 | Out-String
            Write-Host "Current device status:" -ForegroundColor Gray
            Write-Host $deviceStatus -ForegroundColor Gray
        }

        $output = & adb $Arguments 2>&1 | Out-String
        $errorOutput = $LASTEXITCODE

        # Check if we got an error about no devices
        if ($output -match "no devices/emulators found" -or $output -match "device not found") {
            if ($attempt -ge $maxAttempts) {
                Write-Host "`nERROR: Maximum attempts reached. Device not detected." -ForegroundColor Red
                Write-Host "`n========================================" -ForegroundColor Red
                Write-Host "Troubleshooting Steps" -ForegroundColor Red
                Write-Host "========================================`n" -ForegroundColor Red

                Write-Host "1. Check Device Manager for your device:" -ForegroundColor Yellow
                Write-Host "   - Press Win+X and select 'Device Manager'" -ForegroundColor White
                Write-Host "   - Look for devices with yellow warning icons" -ForegroundColor White
                Write-Host "   - Look under 'Android Phone', 'Portable Devices', or 'Other devices'" -ForegroundColor White
                Write-Host ""

                Write-Host "2. If device appears in Device Manager but not in ADB:" -ForegroundColor Yellow
                Write-Host "   - The device needs the correct USB driver installed" -ForegroundColor White
                Write-Host "   - Right-click device > Update driver > Browse > Let me pick" -ForegroundColor White
                Write-Host "   - Select 'Android Device' > 'Android Composite ADB Interface'" -ForegroundColor White
                Write-Host "   - Or install Universal ADB Driver from: https://adb.clockworkmod.com/" -ForegroundColor White
                Write-Host ""

                Write-Host "3. Other things to try:" -ForegroundColor Yellow
                Write-Host "   - Unplug and replug USB cable" -ForegroundColor White
                Write-Host "   - Try a different USB port (preferably USB 2.0)" -ForegroundColor White
                Write-Host "   - Try a different USB cable" -ForegroundColor White
                Write-Host "   - Make sure robot is powered on" -ForegroundColor White
                Write-Host "   - Run 'adb devices' manually to check status" -ForegroundColor White
                Write-Host ""

                Write-Host "4. Check current USB device status:" -ForegroundColor Yellow
                Check-UsbDrivers

                exit 1
            }
            Start-Sleep -Milliseconds 500
            continue
        }

        # If we got here, either success or a different error
        if ($errorOutput -eq 0 -or $output -notmatch "error|failed|not found") {
            Write-Host "[Success] Device detected and command executed!" -ForegroundColor Green
            if ($output.Trim()) {
                Write-Host "Output: $($output.Trim())" -ForegroundColor Gray
            }
            return
        }

        # Show error but continue trying
        if ($output.Trim()) {
            Write-Host "[Attempt $attempt] Error: $($output.Trim())" -ForegroundColor DarkYellow
        }
        Start-Sleep -Milliseconds 500
    }
}

function Fix-AdbShell {
    Write-Host "Creating adb_shell script..." -ForegroundColor Cyan

    $adbShellContent = @"
#!/bin/sh
export ENV='/etc/adb_profile'
exec /bin/sh "$@"
"@

    $adbShellContent | Out-File -FilePath "adb_shell" -Encoding ASCII -NoNewline

    if (-not (Test-Path "adb_shell")) {
        Write-Host "ERROR: Failed to create adb_shell file!" -ForegroundColor Red
        exit 1
    }

    Write-Host "Pushing adb_shell to device..." -ForegroundColor Cyan
    Invoke-AdbLoop -Arguments @("push", "-a", "adb_shell", "/bin/adb_shell") -OperationName "Push adb_shell"
}

function Persist-AdbShell {
    Write-Host "Removing robot manager to persist ADB shell..." -ForegroundColor Cyan
    Invoke-AdbLoop -Arguments @("shell", "rm", "/etc/rc.d/S90robotManager") -OperationName "Remove robot manager"
}

function Check-UsbDrivers {
    Write-Host "Scanning for USB devices that might be your robot...`n" -ForegroundColor Cyan

    # Check for ADB interface devices
    $adbDevices = Get-PnpDevice -Class USB -Status OK -ErrorAction SilentlyContinue |
        Where-Object { $_.FriendlyName -match "ADB|Android|Composite|Interface" }

    # Check for unknown devices
    $unknownDevices = Get-PnpDevice -Class USB -Status Error -ErrorAction SilentlyContinue |
        Where-Object { $_.FriendlyName -match "Unknown|Other" }

    # Check for devices with problem status
    $problemDevices = Get-PnpDevice -Class USB -Status Error -ErrorAction SilentlyContinue

    if ($adbDevices) {
        Write-Host "Found potential ADB devices:" -ForegroundColor Green
        foreach ($device in $adbDevices) {
            Write-Host "  - $($device.FriendlyName) (Status: $($device.Status))" -ForegroundColor White
            Write-Host "    Instance ID: $($device.InstanceId)" -ForegroundColor Gray
        }
        Write-Host ""
    }

    if ($unknownDevices) {
        Write-Host "Found unknown USB devices (may need drivers):" -ForegroundColor Yellow
        foreach ($device in $unknownDevices) {
            Write-Host "  - $($device.FriendlyName) (Status: $($device.Status))" -ForegroundColor White
            Write-Host "    Instance ID: $($device.InstanceId)" -ForegroundColor Gray
        }
        Write-Host ""
    }

    if ($problemDevices) {
        Write-Host "Found USB devices with problems:" -ForegroundColor Red
        foreach ($device in $problemDevices) {
            Write-Host "  - $($device.FriendlyName) (Status: $($device.Status))" -ForegroundColor White
            Write-Host "    Instance ID: $($device.InstanceId)" -ForegroundColor Gray
        }
        Write-Host ""
    }

    # Check for devices with VID/PID that might be Android/ADB
    Write-Host "Checking for Android/ADB compatible devices...`n" -ForegroundColor Cyan
    $allUsbDevices = Get-PnpDevice -Class USB -ErrorAction SilentlyContinue

    $androidVids = @("0BB4", "04E8", "18D1", "22B8", "0E79", "24E3", "2717", "2A47", "2A03", "04C5")
    $foundAndroid = $false

    foreach ($device in $allUsbDevices) {
        if ($device.InstanceId) {
            foreach ($vid in $androidVids) {
                if ($device.InstanceId -match $vid) {
                    Write-Host "  Found device with Android-compatible VID: $($device.FriendlyName)" -ForegroundColor Yellow
                    Write-Host "    Instance ID: $($device.InstanceId)" -ForegroundColor Gray
                    Write-Host "    Status: $($device.Status)" -ForegroundColor $(if ($device.Status -eq "OK") { "Green" } else { "Red" })
                    $foundAndroid = $true
                    break
                }
            }
        }
    }

    if (-not $foundAndroid -and -not $adbDevices) {
        Write-Host "  No Android/ADB compatible devices found in Device Manager." -ForegroundColor Yellow
        Write-Host "  This might mean:" -ForegroundColor Yellow
        Write-Host "    1. Device is not connected" -ForegroundColor White
        Write-Host "    2. Device is not powered on" -ForegroundColor White
        Write-Host "    3. Device needs to be in ADB mode" -ForegroundColor White
        Write-Host ""
    }
}

function Show-RecentUsbDevices {
    Write-Host "`nRecent USB device connections (last 5 minutes):" -ForegroundColor Cyan
    try {
        $events = Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-Kernel-PnP/Configuration'; ID=400} -MaxEvents 20 -ErrorAction SilentlyContinue |
            Where-Object { $_.TimeCreated -gt (Get-Date).AddMinutes(-5) }

        if ($events) {
            foreach ($event in $events) {
                $message = $event.Message
                if ($message -match "Device.*installed|Device.*connected") {
                    Write-Host "  $message" -ForegroundColor Gray
                }
            }
        } else {
            Write-Host "  No recent USB connection events found." -ForegroundColor Gray
        }
    } catch {
        Write-Host "  Could not retrieve USB connection events." -ForegroundColor Gray
    }
    Write-Host ""
}

function Check-UsbDevicesForAdb {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Driver Installation Guide" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan

    Write-Host "If your device appears in Device Manager but ADB doesn't see it," -ForegroundColor Yellow
    Write-Host "you likely need to install the correct USB driver.`n" -ForegroundColor Yellow

    Write-Host "Steps to install ADB USB drivers:" -ForegroundColor Cyan
    Write-Host "1. Open Device Manager (Win+X, then select Device Manager)" -ForegroundColor White
    Write-Host "2. Look for your device under:" -ForegroundColor White
    Write-Host "   - 'Android Phone' or 'Portable Devices'" -ForegroundColor Gray
    Write-Host "   - 'Other devices' (with yellow warning icon)" -ForegroundColor Gray
    Write-Host "   - 'Universal Serial Bus controllers' (might show as 'Unknown Device')" -ForegroundColor Gray
    Write-Host "3. Right-click the device and select 'Update driver'" -ForegroundColor White
    Write-Host "4. Choose 'Browse my computer for drivers'" -ForegroundColor White
    Write-Host "5. Choose 'Let me pick from a list of available drivers'" -ForegroundColor White
    Write-Host "6. Select 'Android Device' or 'Android Composite ADB Interface'" -ForegroundColor White
    Write-Host ""

    Write-Host "Alternative: Install Universal ADB Drivers" -ForegroundColor Cyan
    Write-Host "Download from: https://adb.clockworkmod.com/" -ForegroundColor Yellow
    Write-Host "Or search for 'Universal ADB Driver' or '15 seconds ADB Installer'`n" -ForegroundColor Yellow

    Write-Host "For Xiaomi/Robot devices specifically:" -ForegroundColor Cyan
    Write-Host "- Try installing 'Xiaomi USB Driver' from Xiaomi's website" -ForegroundColor White
    Write-Host "- Or use 'Universal ADB Driver' which works with most Android devices`n" -ForegroundColor White

    Write-Host "After installing drivers:" -ForegroundColor Cyan
    Write-Host "1. Unplug and replug the USB cable" -ForegroundColor White
    Write-Host "2. Run 'adb devices' to verify the device appears" -ForegroundColor White
    Write-Host "3. If device shows as 'unauthorized', check the robot screen for authorization prompt`n" -ForegroundColor White

    Write-Host "Press [Enter] to continue with the script (you can install drivers later)..." -ForegroundColor Yellow
    Read-Host
}

function Wait-ForAdbShell {
    $attempt = 0
    $maxAttempts = 200  # Allow up to 100 seconds

    while ($true) {
        $attempt++

        if ($attempt % 10 -eq 0) {
            Write-Host "[Attempt $attempt] Still waiting for shell... (replug USB cable if needed)" -ForegroundColor Yellow
            # Show current device status
            $deviceStatus = & adb devices 2>&1 | Out-String
            Write-Host "Current device status:" -ForegroundColor Gray
            Write-Host $deviceStatus -ForegroundColor Gray
        }

        $output = & adb shell echo shell_is_ready 2>&1 | Out-String
        $errorCode = $LASTEXITCODE

        if ($output -match "no devices/emulators found" -or $output -match "device not found") {
            if ($attempt -ge $maxAttempts) {
                Write-Host "`nERROR: Maximum attempts reached. Shell not ready." -ForegroundColor Red
                Write-Host "The device may not be properly connected or may need to be replugged." -ForegroundColor Yellow
                exit 1
            }
            Start-Sleep -Milliseconds 500
            continue
        }

        if ($output -match "shell_is_ready" -and $errorCode -eq 0) {
            Write-Host "`n[Success] Shell is ready!" -ForegroundColor Green
            break
        }

        # Show what we're getting
        if ($attempt % 5 -eq 0 -and $output.Trim()) {
            Write-Host "[Attempt $attempt] Response: $($output.Trim())" -ForegroundColor Gray
        }

        Start-Sleep -Milliseconds 500
    }
}

Main

