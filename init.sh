#!/bin/bash

# Check if the key file exists
if [ -f "$HOME/gemini.key" ]; then
    GEMINI_API_KEY=$(cat "$HOME/gemini.key")
else
    read -r -p "Enter Gemini KEY: " GEMINI_API_KEY
    echo "$GEMINI_API_KEY" > "$HOME/gemini.key"
fi

# Export GEMINI_API_KEY as primary, and GOOGLE_API_KEY for backward compatibility
export GEMINI_API_KEY
export GOOGLE_API_KEY="$GEMINI_API_KEY"

echo "✅ Environment variables GEMINI_API_KEY and GOOGLE_API_KEY successfully exported."

# Write keys to .env file (never hardcode in mcp_config.json)
CURRENT_DIR=$(pwd)
ENV_FILE="$CURRENT_DIR/.env"

cat > "$ENV_FILE" <<EOF
GEMINI_API_KEY=$GEMINI_API_KEY
GOOGLE_API_KEY=$GEMINI_API_KEY
EOF

source .env

echo "✅ Written API keys to $ENV_FILE"

# Update .kiro/settings/mcp.json with the absolute path based on the current directory
CONFIG_FILE="$CURRENT_DIR/.kiro/settings/mcp.json"

if [ -f "$CONFIG_FILE" ]; then
    python3 -c "
import json
with open('$CONFIG_FILE', 'r') as f:
    data = json.load(f)
if 'mcpServers' in data and 'nb2lite-agent' in data['mcpServers']:
    server = data['mcpServers']['nb2lite-agent']
    server['args'] = ['$CURRENT_DIR/server.py']
    # Inject keys directly into env block so Kiro passes them to the server process
    server.pop('envFile', None)
    server['env'] = {
        'GEMINI_API_KEY': '$GEMINI_API_KEY',
        'GOOGLE_API_KEY': '$GEMINI_API_KEY'
    }
with open('$CONFIG_FILE', 'w') as f:
    json.dump(data, f, indent=2)
"
    echo "✅ Updated $CONFIG_FILE with path and env keys."
else
    echo "⚠️  Could not find $CONFIG_FILE to update."
fi

