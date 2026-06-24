#!/bin/bash
# ════════════════════════════════════════════════════════════════════════
# AURA Desktop — Setup Ollama AI Locale (macOS)
# ════════════════════════════════════════════════════════════════════════
# Eseguire DOPO l'installazione dell'app AURA Desktop.
# Questo script viene incluso nel .dmg come setup.command
# oppure è disponibile in /Applications/Aura.app/Contents/Resources/ollama-bundle/
# ════════════════════════════════════════════════════════════════════════

AURA_APP="/Applications/Aura.app"
OLLAMA_BIN="$AURA_APP/Contents/Resources/ollama-bundle/ollama"
PLIST_SRC="$AURA_APP/Contents/Resources/ollama-bundle/com.aura.ollama-serve.plist"
PLIST_DST="$HOME/Library/LaunchAgents/com.aura.ollama-serve.plist"

echo "╔══════════════════════════════════════════════╗"
echo "║  AURA Desktop — Setup AI Locale (Ollama)    ║"
echo "╚══════════════════════════════════════════════╝"

# Verifica AURA Desktop
if [ ! -d "$AURA_APP" ]; then
    echo "❌ App AURA Desktop non trovata in $AURA_APP"
    echo "   Installa prima AURA Desktop."
    exit 1
fi

# Verifica ollama binary
if [ ! -f "$OLLAMA_BIN" ]; then
    echo "❌ ollama binary non trovato in $OLLAMA_BIN"
    echo "   Il bundle è corrotto. Reinstalla AURA Desktop."
    exit 1
fi
echo "✅ Ollama bundle trovato"

# Rendi eseguibile il binary
chmod +x "$OLLAMA_BIN"

# Crea directory LaunchAgents se non esiste
mkdir -p "$HOME/Library/LaunchAgents"

# Arresta eventuali processi ollama in esecuzione
echo "⏳ Arresto eventuali processi ollama in corso..."
pkill -TERM ollama 2>/dev/null || true
sleep 2

# Installa e personalizza il plist
if [ -f "$PLIST_SRC" ]; then
    # Sostituisce __USER_HOME__ con la home reale
    sed "s|__USER_HOME__|$HOME|g" "$PLIST_SRC" > "$PLIST_DST"
    chmod 644 "$PLIST_DST"
    echo "✅ Plist installato"
else
    echo "❌ Plist sorgente non trovato in $PLIST_SRC"
    exit 1
fi

# Carica il LaunchAgent
launchctl bootout "gui/$(id -u)" com.aura.ollama-serve 2>/dev/null || true
sleep 1
launchctl bootstrap "gui/$(id -u)" "$PLIST_DST"
echo "✅ LaunchAgent caricato (avvio automatico a ogni login)"

# Verifica con attesa più lunga
echo "⏳ Attesa avvio Ollama server..."
sleep 10
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" localhost:11434/api/tags 2>/dev/null)
if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ Ollama server ATTIVO su localhost:11434"
    echo "   CORS: Access-Control-Allow-Origin: *"
    # Verifica CORS header
    CORS=$(curl -s -I -H "Origin: app://." http://localhost:11434/api/tags 2>/dev/null | grep -i "access-control" || echo "")
    if [ -n "$CORS" ]; then
        echo "✅ CORS verificato: $CORS"
    fi
else
    echo "⚠️  Ollama non risponde ancora (HTTP $HTTP_CODE)"
    echo "   Aspetta 30 secondi e riprova, oppure verifica il log:"
    echo "   tail -20 /tmp/aura-ollama.err"
fi

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║  ✅ Setup completato                        ║"
echo "║  Ora puoi avviare AURA Desktop.             ║"
echo "║  L'AI locale sarà disponibile a ogni login. ║"
echo "╚══════════════════════════════════════════════╝"
