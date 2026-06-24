; ═══════════════════════════════════════════════════════════════════
; AURA Desktop Installer — NSIS Script
; Crea un .exe installer per Windows che:
;   1. Installa Aura Desktop
;   2. Installa Ollama (se non presente)
;   3. Esegue setup-ollama.ps1 per configurare OLLAMA_ORIGINS=*
; ═══════════════════════════════════════════════════════════════════

!define PRODUCT_NAME "AURA Desktop"
!define PRODUCT_VERSION "1.0.7"
!define PRODUCT_PUBLISHER "Dottori-Online"
!define PRODUCT_URL "https://dottori-online.com"
!define PRODUCT_ICON "assets\aura-icon.ico"

; Compressione
SetCompressor /SOLID lzma

; Informazioni installer
Name "${PRODUCT_NAME} ${PRODUCT_VERSION}"
OutFile "Aura-Desktop-Installer-v${PRODUCT_VERSION}.exe"
InstallDir "$LOCALAPPDATA\Programs\AuraDesktop"
InstallDirRegKey HKCU "Software\${PRODUCT_NAME}" "InstallDir"

; Richiede privilegi admin per OLLAMA_ORIGINS sistema
RequestExecutionLevel admin

; Include Modern UI
!include "MUI2.nsh"

; ── Pagine installer ─────────────────────────────────────────────
!define MUI_ABORTWARNING
!define MUI_ICON "assets\aura-icon.ico"
!define MUI_UNICON "assets\aura-icon.ico"
!define MUI_WELCOMEPAGE_TITLE "Benvenuto in AURA Desktop"
!define MUI_WELCOMEPAGE_TEXT "Installa AURA Desktop con AI locale (Ollama).$\r$\n$\r$\nIl wizard configurerà automaticamente:$\r$\n• App AURA Desktop$\r$\n• Motore AI locale Ollama$\r$\n• CORS per comunicazione locale$\r$\n$\r$\nNessun dato inviato via internet.$\r$\n$\r$\nClicca Avanti per continuare."

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "assets\LICENSE.txt"
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!define MUI_FINISHPAGE_RUN "$INSTDIR\Aura Desktop.exe"
!define MUI_FINISHPAGE_RUN_TEXT "Avvia AURA Desktop"
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "Italian"

; ── Sezione principale ───────────────────────────────────────────
Section "AURA Desktop" SecMain
    SectionIn RO  ; Obbligatorio
    
    SetOutPath "$INSTDIR"
    
    ; Copia file app (forniti dalla build GitHub Actions)
    File /r "payload\*.*"
    
    ; Copia script setup
    File "setup-ollama.ps1"
    
    ; Scrivi registro per uninstall
    WriteRegStr HKCU "Software\${PRODUCT_NAME}" "InstallDir" "$INSTDIR"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}" \
        "DisplayName" "${PRODUCT_NAME} ${PRODUCT_VERSION}"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}" \
        "UninstallString" "$INSTDIR\uninstall.exe"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}" \
        "DisplayVersion" "${PRODUCT_VERSION}"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}" \
        "Publisher" "${PRODUCT_PUBLISHER}"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}" \
        "URLInfoAbout" "${PRODUCT_URL}"
    
    ; Shortcut desktop
    CreateShortCut "$DESKTOP\AURA Desktop.lnk" "$INSTDIR\Aura Desktop.exe"
    
    ; Shortcut menu Start
    CreateDirectory "$SMPROGRAMS\${PRODUCT_NAME}"
    CreateShortCut "$SMPROGRAMS\${PRODUCT_NAME}\AURA Desktop.lnk" "$INSTDIR\Aura Desktop.exe"
    CreateShortCut "$SMPROGRAMS\${PRODUCT_NAME}\Disinstalla.lnk" "$INSTDIR\uninstall.exe"
    
    ; Crea uninstaller
    WriteUninstaller "$INSTDIR\uninstall.exe"

SectionEnd

; ── Sezione Ollama CORS Fix (post-install) ───────────────────────
Section "Configura AI Locale (Ollama)" SecOllama
    
    DetailPrint "Configurazione OLLAMA_ORIGINS per CORS..."
    
    ; Imposta OLLAMA_ORIGINS a livello sistema
    WriteRegExpandStr HKLM "SYSTEM\CurrentControlSet\Control\Session Manager\Environment" \
        "OLLAMA_ORIGINS" "*"
    
    ; Imposta anche a livello utente (effetto immediato)
    WriteRegExpandStr HKCU "Environment" "OLLAMA_ORIGINS" "*"
    
    ; Esegui script PowerShell per restart Ollama
    DetailPrint "Avvio script configurazione AI..."
    nsExec::ExecToLog 'powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File "$INSTDIR\setup-ollama.ps1" -Silent'
    
    DetailPrint "Configurazione AI completata."

SectionEnd

; ── Descrizioni sezioni ──────────────────────────────────────────
!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
    !insertmacro MUI_DESCRIPTION_TEXT ${SecMain} "Installa AURA Desktop — app per dottori con AI vocale locale."
    !insertmacro MUI_DESCRIPTION_TEXT ${SecOllama} "Configura il motore AI locale Ollama con CORS abilitato (necessario per AI locale)."
!insertmacro MUI_FUNCTION_DESCRIPTION_END

; ── Uninstaller ──────────────────────────────────────────────────
Section "Uninstall"
    
    ; Rimuovi LaunchAgent / servizio
    nsExec::ExecToLog 'powershell.exe -ExecutionPolicy Bypass -Command "Stop-Process -Name ollama -Force -ErrorAction SilentlyContinue"'
    
    ; Rimuovi env vars
    DeleteRegValue HKLM "SYSTEM\CurrentControlSet\Control\Session Manager\Environment" "OLLAMA_ORIGINS"
    DeleteRegValue HKCU "Environment" "OLLAMA_ORIGINS"
    
    ; Rimuovi file
    RMDir /r "$INSTDIR"
    
    ; Rimuovi shortcut
    Delete "$DESKTOP\AURA Desktop.lnk"
    RMDir /r "$SMPROGRAMS\${PRODUCT_NAME}"
    
    ; Rimuovi chiavi registro
    DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}"
    DeleteRegKey HKCU "Software\${PRODUCT_NAME}"

SectionEnd
