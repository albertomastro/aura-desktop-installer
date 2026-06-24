# AURA Desktop Installer

> Installer 1-click per **AURA Desktop** — AI locale medica con Ollama  
> Piattaforma **Dottori-Online** | [dottori-online.com](https://dottori-online.com)

[![Build macOS .pkg](https://github.com/albertomastro/aura-desktop-installer/actions/workflows/build-macos.yml/badge.svg)](https://github.com/albertomastro/aura-desktop-installer/actions/workflows/build-macos.yml)
[![Build Windows .exe/.msi](https://github.com/albertomastro/aura-desktop-installer/actions/workflows/build-windows.yml/badge.svg)](https://github.com/albertomastro/aura-desktop-installer/actions/workflows/build-windows.yml)

## Cosa fa questo installer

Configura automaticamente **Ollama** con `OLLAMA_ORIGINS=*` per permettere alla dashboard AURA (WKWebView/WebView2) di fare chiamate `fetch()` verso `localhost:11434` senza errori CORS.

### Problema risolto
```
Ollama parte SENZA OLLAMA_ORIGINS → CORS blocca fetch() dalla webview
→ "Ollama Local Engine: Non raggiungibile" ❌

Fix: LaunchAgent com.aura.ollama-serve con OLLAMA_ORIGINS="*"
→ "Ollama Local Engine: Attivo" ✅
```

## Download

| Platform | File | Descrizione |
|----------|------|-------------|
| macOS | `.pkg` | 1-click installer — LaunchAgent automatico |
| Windows | `.exe` | NSIS installer con CORS fix integrato |
| Windows | `.msi` | Installer enterprise (MSI/WiX) |
| Windows | `.ps1` | Script PowerShell standalone |

👉 [**Scarica l'ultima release →**](https://github.com/albertomastro/aura-desktop-installer/releases/latest)

## Struttura Repository

```
aura-desktop-installer/
├── .github/workflows/
│   ├── build-macos.yml          # CI macOS: pkgbuild + productbuild
│   └── build-windows.yml        # CI Windows: NSIS (.exe) + WiX (.msi)
├── macos/
│   ├── scripts/
│   │   ├── postinstall          # 🔑 Script post-install (fix root context)
│   │   └── setup-aura-ollama.sh # Setup manuale / .dmg setup.command
│   └── resources/
│       └── com.aura.ollama-serve.plist  # LaunchAgent template
├── windows/
│   ├── setup-ollama.ps1         # PowerShell CORS fix
│   └── aura-installer.nsi       # NSIS script (.exe)
├── shared/
│   └── VERSION                  # Versione corrente
└── README.md
```

## Dettaglio Tecnico

### macOS — LaunchAgent

Il file `com.aura.ollama-serve.plist` viene installato in:
```
~/Library/LaunchAgents/com.aura.ollama-serve.plist
```

Con `EnvironmentVariables`:
```xml
<key>OLLAMA_ORIGINS</key>
<string>*</string>
<key>HOME</key>
<string>/Users/[utente]</string>
```

Il `postinstall` rileva l'utente reale della console anche quando gira come root:
```bash
CONSOLE_USER=$(stat -f "%Su" /dev/console)
USER_UID=$(id -u "$CONSOLE_USER")
launchctl asuser "$USER_UID" launchctl bootstrap "gui/$USER_UID" "$PLIST_DST"
```

### Windows — Variabile di Sistema

```powershell
[Environment]::SetEnvironmentVariable("OLLAMA_ORIGINS", "*", "Machine")
[Environment]::SetEnvironmentVariable("OLLAMA_ORIGINS", "*", "User")
```

## Build Locali

### macOS
```bash
# Scarica ollama
curl -L https://github.com/ollama/ollama/releases/latest/download/ollama-darwin \
  -o ollama-binary
chmod +x ollama-binary

# Assembla e builda
mkdir -p payload/Applications/Aura.app/Contents/Resources/ollama-bundle
cp ollama-binary payload/Applications/Aura.app/Contents/Resources/ollama-bundle/ollama
cp macos/resources/com.aura.ollama-serve.plist payload/Applications/Aura.app/Contents/Resources/ollama-bundle/
cp macos/scripts/setup-aura-ollama.sh payload/Applications/Aura.app/Contents/Resources/ollama-bundle/
chmod +x payload/Applications/Aura.app/Contents/Resources/ollama-bundle/ollama

# Build pkg
pkgbuild \
  --root payload \
  --scripts macos/scripts \
  --identifier com.dottorionline.aura-desktop-installer \
  --version 1.0.7 \
  Aura-Desktop-Installer-v1.0.7.pkg
```

### Windows (PowerShell)
```powershell
# Esegui come Amministratore
.\windows\setup-ollama.ps1
```

## Modelli AI Consigliati

```bash
ollama pull qwen2.5:1.5b   # 1.5B params — veloce su Mac con 8GB RAM
ollama pull llama3:latest  # 8B params — qualità superiore
```

## Supporto

- 🌐 [dottori-online.com](https://dottori-online.com)
- 📧 info@dottori-online.com
- 🐛 [Issues](https://github.com/albertomastro/aura-desktop-installer/issues)
