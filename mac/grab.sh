#!/bin/bash

# ============================================================
# Zoom Transcript Grabber - Mac
# How it works: Uses macOS Accessibility API to read Zoom's UI.
# This is a system-level read-only interface designed for screen
# readers. It cannot modify any data on your computer.
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
        set winNames to name of every window
        return winNames
    end tell
end tell' 2>/dev/null)

if ! echo "$WINDOW_CHECK" | grep -qi "transcript"; then
    echo -e "${RED}❌ No Transcript window found.${RESET}"
    echo -e "${YELLOW}In your Zoom meeting, click \"Captions\" or \"CC\" at the bottom"
    echo -e "toolbar, then select \"View Full Transcript\" to open the panel.${RESET}"
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
    echo -e "${RED}❌ Accessibility permission is required.${RESET}"
    echo ""
    echo -e "${BOLD}Follow these steps to grant permission:${RESET}"
    echo -e "  1. Open System Settings → Privacy & Security → Accessibility"
    echo -e "  2. Find \"Terminal\" in the list and toggle it ON"
    echo -e "  3. Re-run this script"
    echo ""
    echo -e "${YELLOW}Open System Settings now? (y/n)${RESET}"
    read -r OPEN_PREFS
    if [[ "$OPEN_PREFS" =~ ^[Yy]$ ]]; then
        open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    fi
    exit 1
fi

echo -e "${GREEN}✅ Permission OK${RESET}"
echo ""

# ── Step 4: Grab the text ─────────────────────────────────────
echo -e "${YELLOW}📋 Reading Transcript content...${RESET}"

OUTPUT_FILE="$HOME/Desktop/zoom_transcript_$(date +%Y%m%d_%H%M%S).txt"

RESULT=$(osascript << 'APPLESCRIPT'
tell application "System Events"
    tell process "zoom.us"
        set transcriptWindow to missing value
        repeat with w in every window
            if name of w contains "Transcript" then
                set transcriptWindow to w
                exit repeat
            end if
        end repeat
        if transcriptWindow is missing value then
            return "ERROR: no transcript window"
        end if

        set theTable to table 1 of scroll area 1 of transcriptWindow
        set output to ""
        set rowCount to count of rows of theTable
        set currentSpeaker to ""

        repeat with i from 1 to rowCount
            set aRow to row i of theTable
            set el to UI element 1 of aRow

            try
                set spkr to value of static text 1 of el
                if spkr is not missing value and spkr is not "" then
                    set currentSpeaker to spkr
                end if
            end try

            set textAreas to every text area of el
            repeat with ta in textAreas
                try
                    set txt to value of ta
                    if txt is not missing value and txt as string is not "" then
                        if currentSpeaker is not "" then
                            set output to output & "[" & currentSpeaker & "] " & (txt as string) & linefeed
                            set currentSpeaker to ""
                        else
                            set output to output & (txt as string) & linefeed
                        end if
                    end if
                end try
            end repeat
        end repeat

        return output
    end tell
end tell
APPLESCRIPT
)

# ── Step 5: Save and finish ───────────────────────────────────
if [ -z "$RESULT" ] || echo "$RESULT" | grep -q "^ERROR"; then
    echo -e "${RED}❌ Failed to read transcript: $RESULT${RESET}"
    echo -e "${YELLOW}Make sure the Transcript panel is open and has content.${RESET}"
    exit 1
fi

echo "$RESULT" > "$OUTPUT_FILE"
CHAR_COUNT=${#RESULT}
LINE_COUNT=$(echo "$RESULT" | wc -l | tr -d ' ')

echo ""
echo -e "${GREEN}${BOLD}✅ Done!${RESET}"
echo -e "   📄 File: ${BOLD}$(basename $OUTPUT_FILE)${RESET}"
echo -e "   📍 Saved to: $OUTPUT_FILE"
echo -e "   📊 ${BOLD}${LINE_COUNT}${RESET} lines · ${BOLD}${CHAR_COUNT}${RESET} characters"
echo ""

open -R "$OUTPUT_FILE"

# ── Step 6: Offer to revoke permission ───────────────────────
echo -e "${CYAN}────────────────────────────────────────${RESET}"
echo -e "${YELLOW}💡 When you're done, it's good practice to revoke the Accessibility"
echo -e "   permission from Terminal:${RESET}"
echo -e "   System Settings → Privacy & Security → Accessibility → uncheck Terminal"
echo ""
echo -e "${YELLOW}Open System Settings now to revoke? (y/n)${RESET}"
read -r REVOKE
if [[ "$REVOKE" =~ ^[Yy]$ ]]; then
    open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
fi
