#!/bin/bash

# ============================================================
# Zoom Transcript Grabber - Mac
# Uses macOS Accessibility API (read-only, system built-in)
# ============================================================

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
RESET='\033[0m'

echo ""
echo -e "${BOLD}${CYAN}╔════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}${CYAN}║   Zoom Transcript Grabber  (Mac)       ║${RESET}"
echo -e "${BOLD}${CYAN}╚════════════════════════════════════════╝${RESET}"
echo ""

# ── Step 1: Check Zoom is running ─────────────────────────────
if ! pgrep -x "zoom.us" > /dev/null; then
    echo -e "${RED}❌ Zoom is not running. Please start a Zoom meeting first.${RESET}"
    exit 1
fi

# ── Step 2: Check Transcript window is open ───────────────────
WINDOW_CHECK=$(osascript -e '
tell application "System Events"
    tell process "zoom.us"
        return name of every window
    end tell
end tell' 2>/dev/null)

if ! echo "$WINDOW_CHECK" | grep -qi "transcript"; then
    echo -e "${RED}❌ No Transcript window found.${RESET}"
    echo -e "${YELLOW}In Zoom: click \"CC / Captions\" → \"View Full Transcript\"${RESET}"
    exit 1
fi

# ── Step 3: Check Accessibility permission ────────────────────
echo -e "${YELLOW}🔐 Checking Accessibility permission...${RESET}"

PERM_CHECK=$(osascript -e '
tell application "System Events"
    tell process "zoom.us"
        try
            set x to name of every window
            return "ok"
        on error
            return "denied"
        end try
    end tell
end tell' 2>/dev/null)

if [ "$PERM_CHECK" != "ok" ]; then
    echo ""
    echo -e "${RED}❌ Accessibility permission required.${RESET}"
    echo -e "  1. Open ${BOLD}System Settings → Privacy & Security → Accessibility${RESET}"
    echo -e "  2. Find ${BOLD}Terminal${RESET} and toggle it ON"
    echo -e "  3. Re-run this script"
    echo ""
    printf "Open System Settings now? (y/n): "
    read OPEN_PREFS < /dev/tty
    [[ "$OPEN_PREFS" =~ ^[Yy]$ ]] && open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    exit 1
fi
echo -e "${GREEN}✅ Permission OK${RESET}"
echo ""

# ── Step 4: Grab text (single batch call — fastest possible) ──
echo -e "${YELLOW}📋 Reading transcript...${RESET}"

OUTPUT_FILE="$HOME/Desktop/zoom_transcript_$(date +%Y%m%d_%H%M%S).txt"

RESULT=$(osascript << 'APPLESCRIPT'
tell application "System Events"
    tell process "zoom.us"
        set theTable to table 1 of scroll area 1 of window "Transcript"
        -- One single call: fetch all text areas from all rows at once
        set allText to value of every text area of every UI element of every row of theTable
    end tell
end tell

-- Flatten and assemble output
set output to ""
repeat with rowTexts in allText
    repeat with cellTexts in rowTexts
        repeat with t in cellTexts
            if t is not missing value and t as string is not "" then
                set output to output & (t as string) & linefeed
            end if
        end repeat
    end repeat
end repeat
return output
APPLESCRIPT
)

# ── Step 5: Save ──────────────────────────────────────────────
if [ -z "$RESULT" ] || echo "$RESULT" | grep -q "^ERROR"; then
    echo -e "${RED}❌ Failed: $RESULT${RESET}"
    echo -e "${YELLOW}Make sure the Transcript panel is open and has content.${RESET}"
    exit 1
fi

echo "$RESULT" > "$OUTPUT_FILE"
LINE_COUNT=$(echo "$RESULT" | wc -l | tr -d ' ')
CHAR_COUNT=${#RESULT}

echo ""
echo -e "${GREEN}${BOLD}✅ Done!${RESET}"
echo -e "   📄 ${BOLD}$(basename "$OUTPUT_FILE")${RESET}"
echo -e "   📍 $OUTPUT_FILE"
echo -e "   📊 ${BOLD}${LINE_COUNT}${RESET} lines · ${BOLD}${CHAR_COUNT}${RESET} characters"
echo ""

open -R "$OUTPUT_FILE"

# ── Step 6: Offer to revoke permission ────────────────────────
echo -e "${CYAN}────────────────────────────────────────${RESET}"
echo -e "${YELLOW}💡 Revoke Accessibility permission when done:${RESET}"
echo -e "   System Settings → Privacy & Security → Accessibility → uncheck Terminal"
echo ""
printf "Open System Settings to revoke now? (y/n): "
read REVOKE < /dev/tty
[[ "$REVOKE" =~ ^[Yy]$ ]] && open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
