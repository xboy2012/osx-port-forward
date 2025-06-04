#!/bin/bash

set -e

# Check if the script is running on macOS
if [[ "$(uname)" != "Darwin" ]]; then
  echo "❌ This script is only intended for macOS. Exiting."
  exit 1
fi

PF_CONF="/etc/pf.conf"
ANCHOR_NAME="com.redirect443to8443"
ANCHOR_FILE="/etc/pf.anchors/$ANCHOR_NAME"
RDR_ANCHOR_LINE="rdr-anchor \"$ANCHOR_NAME\""
LOAD_ANCHOR_LINE="load anchor \"$ANCHOR_NAME\" from \"$ANCHOR_FILE\""

echo "🔧 Writing redirect rule to anchor file..."
echo "rdr pass on lo0 inet proto tcp from any to any port 443 -> 127.0.0.1 port 8443" | sudo tee "$ANCHOR_FILE" > /dev/null

# Add rdr-anchor if not present
if ! grep -Fxq "$RDR_ANCHOR_LINE" "$PF_CONF"; then
  echo "🔧 Inserting rdr-anchor into pf.conf..."
  LINE_NUM=$(grep -n '^rdr-anchor' "$PF_CONF" | tail -n1 | cut -d: -f1)
  if [ -z "$LINE_NUM" ]; then
    echo "⚠️  No existing rdr-anchor found, inserting at the end..."
    echo "$RDR_ANCHOR_LINE" | sudo tee -a "$PF_CONF" > /dev/null
  else
    sudo sed -i '' "${LINE_NUM}a\\
$RDR_ANCHOR_LINE
" "$PF_CONF"
  fi
else
  echo "✅ rdr-anchor already present."
fi

# Add load anchor if not present
if ! grep -Fxq "$LOAD_ANCHOR_LINE" "$PF_CONF"; then
  echo "🔧 Inserting load anchor into pf.conf..."
  LINE_NUM=$(grep -n '^load anchor' "$PF_CONF" | tail -n1 | cut -d: -f1)
  if [ -z "$LINE_NUM" ]; then
    echo "⚠️  No existing load anchor found, inserting at the end..."
    echo "$LOAD_ANCHOR_LINE" | sudo tee -a "$PF_CONF" > /dev/null
  else
    sudo sed -i '' "${LINE_NUM}a\\
$LOAD_ANCHOR_LINE
" "$PF_CONF"
  fi
else
  echo "✅ load anchor already present."
fi

# Reload pf config
echo "🔁 Reloading pf.conf..."
sudo pfctl -f "$PF_CONF" &> /dev/null

# Enable pf if not already enabled
if sudo pfctl -s info &> /dev/null | grep -q "Status: Enabled"; then
  echo "✅ PF is already enabled."
else
  echo "🚀 Enabling PF..."
  sudo pfctl -e 2>/dev/null || true
fi

echo "🎉 Done! All HTTPS (443) traffic is now redirected to 8443 locally."
