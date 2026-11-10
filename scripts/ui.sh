#!/usr/bin/env bash
# Print what's on screen as text (package, id, text, content-desc, bounds, C=clickable).
# Always deletes the old dump first: a stale /sdcard/ui.xml makes you act on an old screen.
. "$(dirname "$0")/_common.sh"
rm -f "$UIXML"
ash 'rm -f /sdcard/ui.xml; uiautomator dump --compressed /sdcard/ui.xml >/dev/null' >/dev/null 2>&1
aexec cat /sdcard/ui.xml > "$UIXML" 2>/dev/null
ash rm -f /sdcard/ui.xml >/dev/null 2>&1
python3 - "$UIXML" <<'P'
import sys, xml.etree.ElementTree as ET
try:
    t = ET.parse(sys.argv[1])
except Exception as e:
    print("UI_DUMP_FAILED", e); sys.exit(1)
for n in t.iter('node'):
    tx, d, r = n.get('text'), n.get('content-desc'), n.get('resource-id') or ''
    if tx or d or n.get('clickable') == 'true':
        print((n.get('package') or '').split('.')[-1], r.split('/')[-1], repr(tx), repr(d),
              n.get('bounds'), 'C' if n.get('clickable') == 'true' else '')
P
