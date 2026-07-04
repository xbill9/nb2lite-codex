#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
CURRENT_DIR="$SCRIPT_DIR"
KEY_FILE="$HOME/gemini.key"

find_python() {
    if command -v python3 >/dev/null 2>&1; then
        command -v python3
        return 0
    fi

    if [ "$(uname -s)" = "Darwin" ]; then
        for candidate in /opt/homebrew/bin/python3 /usr/local/bin/python3 /usr/bin/python3; do
            if [ -x "$candidate" ]; then
                printf '%s\n' "$candidate"
                return 0
            fi
        done
    fi

    return 1
}

PYTHON_BIN="$(find_python)" || {
    echo "ERROR: python3 is required. On macOS, install it with: brew install python"
    return 1 2>/dev/null || exit 1
}

# Check if the key file exists
if [ -f "$KEY_FILE" ]; then
    GEMINI_API_KEY=$(cat "$KEY_FILE")
else
    read -r -p "Enter Gemini KEY: " GEMINI_API_KEY
    printf '%s\n' "$GEMINI_API_KEY" > "$KEY_FILE"
fi

chmod 600 "$KEY_FILE" 2>/dev/null || true

# Export GEMINI_API_KEY as primary, and GOOGLE_API_KEY for backward compatibility
export GEMINI_API_KEY
export GOOGLE_API_KEY="$GEMINI_API_KEY"

echo "✅ Environment variables GEMINI_API_KEY and GOOGLE_API_KEY successfully exported."

# Write keys to .env file (never hardcode in mcp_config.json)
ENV_FILE="$CURRENT_DIR/.env"

cat > "$ENV_FILE" <<EOF
GEMINI_API_KEY=$GEMINI_API_KEY
GOOGLE_API_KEY=$GEMINI_API_KEY
EOF

set -a
source "$ENV_FILE"
set +a

echo "✅ Written API keys to $ENV_FILE"

# Update .kiro/settings/mcp.json with the absolute path based on the current directory
CONFIG_FILE="$CURRENT_DIR/.kiro/settings/mcp.json"

if [ -f "$CONFIG_FILE" ]; then
    CONFIG_FILE="$CONFIG_FILE" CURRENT_DIR="$CURRENT_DIR" PYTHON_BIN="$PYTHON_BIN" GEMINI_API_KEY="$GEMINI_API_KEY" "$PYTHON_BIN" -c "
import json
import os

config_file = os.environ['CONFIG_FILE']
current_dir = os.environ['CURRENT_DIR']
python_bin = os.environ['PYTHON_BIN']
gemini_api_key = os.environ['GEMINI_API_KEY']

with open(config_file, 'r') as f:
    data = json.load(f)
if 'mcpServers' in data and 'nb2lite-agent' in data['mcpServers']:
    server = data['mcpServers']['nb2lite-agent']
    server['command'] = python_bin
    server['args'] = [os.path.join(current_dir, 'server.py')]
    # Inject keys directly into env block so Kiro passes them to the server process
    server.pop('envFile', None)
    server['env'] = {
        'GEMINI_API_KEY': gemini_api_key,
        'GOOGLE_API_KEY': gemini_api_key
    }
with open(config_file, 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
"
    echo "✅ Updated $CONFIG_FILE with path and env keys."
else
    echo "⚠️  Could not find $CONFIG_FILE to update."
fi
