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

# ── Step 4: Grab text (batch read — fast) ─────────────────────
echo -e "${YELLOW}📋 Reading transcript...${RESET}"

OUTPUT_FILE="$HOME/Desktop/zoom_transcript_$(date +%Y%m%d_%H%M%S).txt"

# Key technique: read ALL text areas and ALL static texts in one
# batch call instead of looping row by row. Much faster.
RESULT=$(osascript << 'APPLESCRIPT'
tell application "System Events"
    tell process "zoom.us"

        -- Find Transcript window
        set transcriptWindow to missing value
        repeat with w in every window
            if name of w contains "Transcript" then
                set transcriptWindow to w
                exit repeat
            end if
        end repeat
        if transcriptWindow is missing value then
            return "ERROR: window not found"
        end if

        set theTable to table 1 of scroll area 1 of transcriptWindow

        -- Batch read: get all static texts (speaker names) and
        -- all text areas (spoken text) in two calls instead of per-row loop
        set speakerValues to {}
        set textValues to {}

        try
            set allRows to every row of theTable
            repeat with aRow in allRows
                set el to UI element 1 of aRow

                -- Speaker name (may not exist on every row)
                set spkr to ""
                try
                    set spkr to value of static text 1 of el
                    if spkr is missing value then set spkr to ""
                end try
                set end of speakerValues to spkr as string

                -- Text content (collect all text areas in this row)
                set rowText to ""
                try
                    set tas to every text area of el
                    repeat with ta in tas
                        try
                            set t to value of ta
                            if t is not missing value and t as string is not "" then
                                set rowText to rowText & (t as string) & " "
                            end if
                        end try
                    end repeat
                end try
                set end of textValues to rowText
            end repeat
        end try

        -- Assemble output
        set output to ""
        set rowCount to count of speakerValues
        repeat with i from 1 to rowCount
            set spkr to item i of speakerValues
            set txt to item i of textValues
            set txt to my trimText(txt)
            if txt is not "" then
                if spkr is not "" then
                    set output to output & "[" & spkr & "] " & txt & linefeed
                else
                    set output to output & txt & linefeed
                end if
            end if
        end repeat

        return output
    end tell
end tell

on trimText(t)
    -- Remove leading/trailing spaces
    set t to t as string
    repeat while t starts with " "
        set t to text 2 thru -1 of t
    end repeat
    repeat while t ends with " "
        set t to text 1 thru -2 of t
    end repeat
    return t
end trimText
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
