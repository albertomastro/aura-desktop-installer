#
# .SYNOPSIS
#     AURA Desktop — Configura Ollama per AI Locale su Windows
# .DESCRIPTION
#     Imposta OLLAMA_ORIGINS=* come variabile di sistema e riavvia Ollama.
#     Integrato nel post-install del .exe (NSIS) — gira con privilegi Admin.
# .NOTES
#     Dottori-Online — https://dottori-online.com
#

param(
    [switch]$Silent
)

function Write-Log {
    param([string]$Message, [string]$Color = "White")
    $timestamp = Get-Date -Format "HH:mm:ss"
    $logLine = "[$timestamp] $Message"
    
    if (-not $Silent) {
        Write-Host $Message -ForegroundColor $Color
    }
    
    # Scrivi anche nel log file
    $logPath = "$env:TEMP\aura-ollama-setup.log"
    Add-Content -Path $logPath -Value $logLine -ErrorAction SilentlyContinue
}

Write-Log "═══════════════════════════════════════════════" Cyan
Write-Log "   AURA Desktop — Setup AI Locale (Windows)   " Cyan
Write-Log "═══════════════════════════════════════════════" Cyan

# ── 1. Imposta variabile di sistema OLLAMA_ORIGINS ─────────────
try {
    [Environment]::SetEnvironmentVariable("OLLAMA_ORIGINS", "*", "Machine")
    # Anche per l'utente corrente (per la sessione attiva)
    [Environment]::SetEnvironmentVariable("OLLAMA_ORIGINS", "*", "User")
    Write-Log "✅ OLLAMA_ORIGINS=* impostato (sistema + utente)" Green
} catch {
    Write-Log "❌ Errore impostazione variabile: $_" Red
    exit 1
}

# ── 2. Termina processi Ollama in esecuzione ───────────────────
$ollamaProcesses = Get-Process -Name "ollama" -ErrorAction SilentlyContinue
if ($ollamaProcesses) {
    Write-Log "⏳ Terminazione processi Ollama in corso..." Yellow
    $ollamaProcesses | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3
    Write-Log "✅ Processi Ollama terminati" Green
}

# ── 3. Gestione servizio Windows o processo standalone ─────────
$ollamaService = Get-Service -Name "Ollama" -ErrorAction SilentlyContinue

if ($ollamaService) {
    # Ollama installato come servizio Windows
    try {
        Stop-Service -Name "Ollama" -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        Start-Service -Name "Ollama"
        Write-Log "✅ Servizio Ollama riavviato con CORS fix" Green
    } catch {
        Write-Log "⚠️  Errore riavvio servizio: $_" Yellow
        # Fallback: avvia come processo
        $ollamaExe = "${env:LOCALAPPDATA}\Programs\Ollama\ollama.exe"
        if (-not (Test-Path $ollamaExe)) {
            $ollamaExe = "${env:ProgramFiles}\Ollama\ollama.exe"
        }
        if (Test-Path $ollamaExe) {
            Start-Process $ollamaExe -ArgumentList "serve" -WindowStyle Hidden
            Write-Log "✅ Ollama avviato come processo standalone" Green
        }
    }
} else {
    # Ollama non è un servizio — cerca l'eseguibile
    Write-Log "ℹ️  Servizio Ollama non trovato, cerco eseguibile..." Yellow
    
    $ollamaPaths = @(
        "${env:LOCALAPPDATA}\Programs\Ollama\ollama.exe",
        "${env:ProgramFiles}\Ollama\ollama.exe",
        "${env:ProgramFiles(x86)}\Ollama\ollama.exe",
        "C:\Ollama\ollama.exe"
    )
    
    $ollamaExe = $ollamaPaths | Where-Object { Test-Path $_ } | Select-Object -First 1
    
    if ($ollamaExe) {
        Write-Log "✅ Ollama trovato in: $ollamaExe" Green
        # Avvia con OLLAMA_ORIGINS già nel env corrente
        Start-Process $ollamaExe -ArgumentList "serve" -WindowStyle Hidden
        Write-Log "✅ Ollama avviato con OLLAMA_ORIGINS=*" Green
    } else {
        Write-Log "⚠️  Ollama non trovato. Installa da https://ollama.com" Yellow
        Write-Log "   Dopo l'installazione riavvia il computer." Yellow
    }
}

# ── 4. Verifica CORS ────────────────────────────────────────────
Write-Log "⏳ Attesa avvio Ollama server (15 secondi)..." Yellow
Start-Sleep -Seconds 15

try {
    $response = Invoke-WebRequest -Uri "http://localhost:11434/api/tags" -Method GET -UseBasicParsing -TimeoutSec 10
    if ($response.StatusCode -eq 200) {
        Write-Log "✅ Ollama AI Locale ATTIVO su localhost:11434" Green
        # Verifica CORS header
        $corsHeader = $response.Headers["Access-Control-Allow-Origin"]
        if ($corsHeader -eq "*") {
            Write-Log "✅ CORS verificato: Access-Control-Allow-Origin: *" Green
        } else {
            Write-Log "⚠️  CORS header non rilevato — il riavvio del PC applicherà le env vars" Yellow
        }
    }
} catch {
    Write-Log "⚠️  Ollama non risponde ancora. Riavvia il computer per applicare le env vars." Yellow
    Write-Log "   Log: $env:TEMP\aura-ollama-setup.log" Yellow
}

Write-Log "" White
Write-Log "═══════════════════════════════════════════════" Cyan
Write-Log "   ✅ Setup completato. Avvia AURA Desktop.   " Cyan
Write-Log "═══════════════════════════════════════════════" Cyan
