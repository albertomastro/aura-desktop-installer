param(
    [string]$Version = "1.0.7",
    [string]$OllamaVersion = "0.3.10"
)

$ErrorActionPreference = "Stop"

Write-Host "Starting build for Version: $Version, Ollama Version: $OllamaVersion"

# Function to download large files robustly
function Download-File {
    param(
        [string]$Url,
        [string]$OutFile
    )
    
    $ProgressPreference = 'SilentlyContinue'
    
    # Try using curl.exe first (faster and handles large files better on Windows runner)
    try {
        Write-Host "Attempting download with curl.exe..."
        curl.exe -L -s -S -o $OutFile $Url
        if ((Test-Path $OutFile) -and ((Get-Item $OutFile).Length -gt 100MB)) {
            Write-Host "Download successful via curl.exe"
            return
        }
    } catch {
        Write-Host "curl.exe download failed or file too small: $_"
    }
    
    # Fallback to Invoke-WebRequest
    Write-Host "Attempting download with Invoke-WebRequest..."
    Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing
    
    if (-not (Test-Path $OutFile) -or ((Get-Item $OutFile).Length -le 100MB)) {
        throw "Download failed or downloaded file is too small (less than 100MB)"
    }
}

# 1. Download ollama binary for Windows
$url = "https://github.com/ollama/ollama/releases/download/v${OllamaVersion}/ollama-windows-amd64.zip"
Write-Host "Downloading Ollama for Windows from $url..."
Download-File -Url $url -OutFile "ollama-windows.zip"

Write-Host "Extracting Ollama..."
if (Test-Path "ollama-extracted") {
    Remove-Item "ollama-extracted" -Recurse -Force
}
Expand-Archive -Path "ollama-windows.zip" -DestinationPath "ollama-extracted" -Force
Write-Host "Ollama extracted contents:"
Get-ChildItem "ollama-extracted" | Select-Object Name, Length

# 2. Prepare payload directory
Write-Host "Preparing payload directory..."
if (Test-Path "payload") {
    Remove-Item "payload" -Recurse -Force
}
New-Item -ItemType Directory -Force -Path "payload"

$ollamaExe = Get-ChildItem "ollama-extracted" -Recurse -Filter "ollama.exe" | Select-Object -First 1
if ($ollamaExe) {
    Copy-Item $ollamaExe.FullName -Destination "payload\ollama.exe"
} else {
    Copy-Item "ollama-extracted\ollama.exe" -Destination "payload\ollama.exe"
}

# Copy setup PowerShell script
Copy-Item "windows\setup-ollama.ps1" -Destination "payload\setup-ollama.ps1"

# Create launcher batch file
$batContent = "@echo off`r`nstart """" ""https://dottori-online.com/app/professionista"""
[System.IO.File]::WriteAllText("payload\AuraDesktop.bat", $batContent)

Write-Host "Payload contents:"
Get-ChildItem "payload" | Select-Object Name, Length

# 3. Create NSIS assets
Write-Host "Preparing NSIS assets..."
if (Test-Path "nsis-assets") {
    Remove-Item "nsis-assets" -Recurse -Force
}
New-Item -ItemType Directory -Force -Path "nsis-assets"
$license = "AURA Desktop - Termini di Utilizzo`r`nDottori-Online - https://dottori-online.com`r`n`r`nSoftware per uso professionale medico.`r`nOllama distribuito sotto licenza MIT."
[System.IO.File]::WriteAllText("nsis-assets\LICENSE.txt", $license)

# 4. Generate NSIS script file
Write-Host "Generating NSIS script..."
$nsiContent = @'
!define PRODUCT_NAME "AURA Desktop"
!define PRODUCT_VERSION "VERSIONPLACEHOLDER"
!define PRODUCT_PUBLISHER "Dottori-Online"
!define PRODUCT_URL "https://dottori-online.com"

SetCompressor /SOLID lzma
Name "${PRODUCT_NAME} ${PRODUCT_VERSION}"
OutFile "Aura-Desktop-Installer-v${PRODUCT_VERSION}.exe"
InstallDir "$LOCALAPPDATA\Programs\AuraDesktop"
RequestExecutionLevel admin

!include "MUI2.nsh"

!define MUI_ABORTWARNING
!define MUI_WELCOMEPAGE_TITLE "Benvenuto in AURA Desktop"
!define MUI_WELCOMEPAGE_TEXT "Installa AURA Desktop con AI locale Ollama.$\r$\n$\r$\nConfigura automaticamente OLLAMA_ORIGINS per la dashboard medica.$\r$\n$\r$\nClicca Avanti per continuare."

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "nsis-assets\LICENSE.txt"
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!define MUI_FINISHPAGE_RUN "$INSTDIR\AuraDesktop.bat"
!define MUI_FINISHPAGE_RUN_TEXT "Avvia AURA Desktop"
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "Italian"

Section "AURA Desktop" SecMain
  SectionIn RO
  SetOutPath "$INSTDIR"
  File "payload\ollama.exe"
  File "payload\setup-ollama.ps1"
  File "payload\AuraDesktop.bat"

  WriteRegStr HKCU "Software\${PRODUCT_NAME}" "InstallDir" "$INSTDIR"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}" "DisplayName" "${PRODUCT_NAME} ${PRODUCT_VERSION}"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}" "UninstallString" "$INSTDIR\uninstall.exe"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}" "DisplayVersion" "${PRODUCT_VERSION}"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}" "Publisher" "${PRODUCT_PUBLISHER}"

  CreateShortCut "$DESKTOP\AURA Desktop.lnk" "$INSTDIR\AuraDesktop.bat"
  CreateDirectory "$SMPROGRAMS\${PRODUCT_NAME}"
  CreateShortCut "$SMPROGRAMS\${PRODUCT_NAME}\AURA Desktop.lnk" "$INSTDIR\AuraDesktop.bat"
  CreateShortCut "$SMPROGRAMS\${PRODUCT_NAME}\Disinstalla.lnk" "$INSTDIR\uninstall.exe"

  WriteUninstaller "$INSTDIR\uninstall.exe"
SectionEnd

Section "Configura AI Locale" SecOllama
  WriteRegExpandStr HKLM "SYSTEM\CurrentControlSet\Control\Session Manager\Environment" "OLLAMA_ORIGINS" "*"
  WriteRegExpandStr HKCU "Environment" "OLLAMA_ORIGINS" "*"
  DetailPrint "OLLAMA_ORIGINS=* configurato"
  nsExec::ExecToLog 'powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File "$INSTDIR\setup-ollama.ps1" -Silent'
  DetailPrint "Setup AI completato"
SectionEnd

Section "Uninstall"
  nsExec::ExecToLog 'powershell.exe -ExecutionPolicy Bypass -Command "Stop-Process -Name ollama -Force -ErrorAction SilentlyContinue"'
  DeleteRegValue HKLM "SYSTEM\CurrentControlSet\Control\Session Manager\Environment" "OLLAMA_ORIGINS"
  DeleteRegValue HKCU "Environment" "OLLAMA_ORIGINS"
  RMDir /r "$INSTDIR"
  Delete "$DESKTOP\AURA Desktop.lnk"
  RMDir /r "$SMPROGRAMS\${PRODUCT_NAME}"
  DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}"
  DeleteRegKey HKCU "Software\${PRODUCT_NAME}"
SectionEnd
'@

$nsiContent = $nsiContent -replace 'VERSIONPLACEHOLDER', $Version
[System.IO.File]::WriteAllText("aura-installer.nsi", $nsiContent)
Write-Host "NSIS script written to aura-installer.nsi"

# 5. Build exe with NSIS
$nsisExe = "C:\Program Files (x86)\NSIS\makensis.exe"
if (-not (Test-Path $nsisExe)) {
    Write-Host "makensis.exe not found at default location. Checking PATH..."
    $nsisExe = Get-Command makensis.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
}

if (-not $nsisExe) {
    Write-Host "NSIS not found, installing via chocolatey..."
    choco install nsis -y --no-progress
    $nsisExe = "C:\Program Files (x86)\NSIS\makensis.exe"
}

Write-Host "Building EXE with NSIS using: $nsisExe"
& $nsisExe /V3 "aura-installer.nsi"

$outFile = "Aura-Desktop-Installer-v${Version}.exe"
if (Test-Path $outFile) {
    Write-Host "SUCCESS: $outFile created successfully!"
    Get-Item $outFile | Select-Object Name, @{N='Size';E={[math]::Round($_.Length/1MB,1)}}
} else {
    Write-Error "ERROR: $outFile was not created!"
    exit 1
}

# 6. Build MSI with WiX (non-fatal — .exe is the primary artifact)
Write-Host "--- WiX MSI Build (optional) ---"

# Install WiX tool
$wixInstalled = $false
try {
    $dotnetToolResult = dotnet tool install --global wix --version 4.0.5 2>&1
    Write-Host $dotnetToolResult
    $wixInstalled = $true
} catch {
    try {
        # Already installed - update it
        dotnet tool update --global wix 2>&1 | Write-Host
        $wixInstalled = $true
    } catch {
        Write-Host "Could not install/update WiX: $_"
    }
}

if ($wixInstalled) {
    # Ensure global dotnet tools are in PATH
    $env:PATH = "$env:USERPROFILE\.dotnet\tools;$env:PATH"
    
    $wixExe = "$env:USERPROFILE\.dotnet\tools\wix.exe"
    
    if (Test-Path $wixExe) {
        Write-Host "WiX found at: $wixExe"
        
        # Install required WiX extension
        try {
            Write-Host "Installing WixToolset.UI.wixext..."
            & $wixExe extension add WixToolset.UI.wixext --global 2>&1 | Write-Host
        } catch {
            Write-Host "Extension install note: $_"
        }
        
        try {
            & $wixExe --version
            
            Write-Host "Updating version in windows\aura-installer.wxs..."
            $wxsFile = "windows\aura-installer.wxs"
            $wxs = Get-Content $wxsFile -Raw
            $wxs = $wxs -replace 'Version="[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+"', "Version=`"$Version.0`""
            Set-Content $wxsFile $wxs
            
            Write-Host "Building MSI with WiX..."
            $msiFile = "Aura.Desktop_${Version}_x64_en-US.msi"
            
            # Run wix build - use $LASTEXITCODE instead of exceptions
            & $wixExe build $wxsFile -bindpath payload -ext WixToolset.UI.wixext -o $msiFile 2>&1 | Write-Host
            
            if ((Test-Path $msiFile) -and ((Get-Item $msiFile).Length -gt 0)) {
                Write-Host "SUCCESS: $msiFile created!"
                Get-Item $msiFile | Select-Object Name, @{N='Size';E={[math]::Round($_.Length/1MB,1)}}
            } else {
                Write-Host "MSI not created — continuing without it (EXE is the primary artifact)"
            }
        } catch {
            Write-Host "WiX build skipped: $_"
        }
    } else {
        Write-Host "wix.exe not found at expected path. Skipping MSI."
    }
} else {
    Write-Host "WiX not installed. Skipping MSI build."
}

Write-Host "Build script completed successfully."
exit 0
