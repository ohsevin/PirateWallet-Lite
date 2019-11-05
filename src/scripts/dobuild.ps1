# Unified build script for Windows, Linux and Mac builder. Run on a Windows machine inside powershell.
param (
    [Parameter(Mandatory=$true)][string]$version,
    [Parameter(Mandatory=$true)][string]$prev,
    [Parameter(Mandatory=$true)][string]$server
)

Write-Host "[Initializing]"
Remove-Item -Force -ErrorAction Ignore ./artifacts/linux-binaries-pirate-qt-wallet-v$version.tar.gz
Remove-Item -Force -ErrorAction Ignore ./artifacts/linux-deb-pirate-qt-wallet-v$version.deb
Remove-Item -Force -ErrorAction Ignore ./artifacts/Windows-binaries-pirate-qt-wallet-v$version.zip
Remove-Item -Force -ErrorAction Ignore ./artifacts/Windows-installer-pirate-qt-wallet-v$version.msi
Remove-Item -Force -ErrorAction Ignore ./artifacts/macOS-pirate-qt-wallet-v$version.dmg

Remove-Item -Recurse -Force -ErrorAction Ignore ./bin
Remove-Item -Recurse -Force -ErrorAction Ignore ./debug
Remove-Item -Recurse -Force -ErrorAction Ignore ./release

# Create the version.h file and update README version number
Write-Output "#define APP_VERSION `"$version`"" > src/version.h
Get-Content README.md | Foreach-Object { $_ -replace "$prev", "$version" } | Out-File README-new.md
Move-Item -Force README-new.md README.md
Write-Host ""

Write-Host "[Building Linux + Windows]"
Write-Host -NoNewline "Copying files.........."
ssh $server "rm -rf /tmp/pqwbuild"
ssh $server "mkdir /tmp/pqwbuild"
scp -r src/ res/ ./pirate-qt-wallet.pro ./application.qrc ./LICENSE ./README.md ${server}:/tmp/pqwbuild/ | Out-Null
ssh $server "dos2unix -q /tmp/pqwbuild/src/scripts/mkrelease.sh" | Out-Null
ssh $server "dos2unix -q /tmp/pqwbuild/src/version.h"
Write-Host "[OK]"

ssh $server "cd /tmp/pqwbuild && APP_VERSION=$version PREV_VERSION=$prev bash src/scripts/mkrelease.sh"
if (!$?) {
    Write-Output "[Error]"
    exit 1;
}

New-Item artifacts -itemtype directory -Force         | Out-Null
scp    ${server}:/tmp/pqwbuild/artifacts/* artifacts/ | Out-Null
scp -r ${server}:/tmp/pqwbuild/release .              | Out-Null

Write-Host -NoNewline "Building Installer....."
src/scripts/mkwininstaller.ps1 -version $version 2>&1 | Out-Null
if (!$?) {
    Write-Output "[Error]"
    exit 1;
}
Write-Host "[OK]"

# Finally, test to make sure all files exist
Write-Host -NoNewline "Checking Build........."
if (! (Test-Path ./artifacts/linux-binaries-pirate-qt-wallet-v$version.tar.gz) -or
    ! (Test-Path ./artifacts/linux-deb-pirate-qt-wallet-v$version.deb) -or
    ! (Test-Path ./artifacts/Windows-binaries-pirate-qt-wallet-v$version.zip) -or
    ! (Test-Path ./artifacts/Windows-installer-pirate-qt-wallet-v$version.msi) ) {
        Write-Host "[Error]"
        exit 1;
    }
Write-Host "[OK]"
