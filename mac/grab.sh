#!/bin/bash

# ============================================================
# Zoom Transcript Grabber - Mac
# Uses macOS Accessibility API (read-only, system built-in)
# Fast mode: uses Swift directly; falls back to AppleScript
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

# ── Step 4: Grab text ─────────────────────────────────────────
echo -e "${YELLOW}📋 Reading transcript...${RESET}"

OUTPUT_FILE="$HOME/Desktop/zoom_transcript_$(date +%Y%m%d_%H%M%S).txt"

# Fast path: Swift calls Accessibility API directly (no AppleScript overhead)
RESULT=$(swift - 2>/dev/null << 'SWIFT'
import Cocoa
import ApplicationServices

let apps = NSWorkspace.shared.runningApplications
guard let zoom = apps.first(where: { $0.bundleIdentifier == "us.zoom.xos" }) else {
    print("ERROR: Zoom not running"); exit(0)
}

let app = AXUIElementCreateApplication(zoom.processIdentifier)
var windowsRef: CFTypeRef?
AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windowsRef)
guard let windows = windowsRef as? [AXUIElement] else { print("ERROR: no windows"); exit(0) }

var transcriptWin: AXUIElement?
for win in windows {
    var t: CFTypeRef?
    AXUIElementCopyAttributeValue(win, kAXTitleAttribute as CFString, &t)
    if let title = t as? String, title.contains("Transcript") { transcriptWin = win; break }
}
guard let win = transcriptWin else { print("ERROR: no transcript window"); exit(0) }

var output = ""

func collect(_ el: AXUIElement, _ depth: Int) {
    guard depth < 12 else { return }
    var roleRef: CFTypeRef?
    AXUIElementCopyAttributeValue(el, kAXRoleAttribute as CFString, &roleRef)
    let role = roleRef as? String ?? ""
    var valRef: CFTypeRef?
    AXUIElementCopyAttributeValue(el, kAXValueAttribute as CFString, &valRef)
    if role == "AXStaticText" || role == "AXTextArea" {
        if let text = valRef as? String {
            let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty {
                output += (role == "AXStaticText" ? "[\(t)]" : t) + "\n"
            }
        }
        return
    }
    var childRef: CFTypeRef?
    AXUIElementCopyAttributeValue(el, kAXChildrenAttribute as CFString, &childRef)
    if let children = childRef as? [AXUIElement] {
        for child in children { collect(child, depth + 1) }
    }
}

collect(win, 0)
print(output)
SWIFT
)

# Fallback: AppleScript if Swift failed
if [ -z "$RESULT" ] || echo "$RESULT" | grep -q "^ERROR"; then
    echo -e "${YELLOW}  (using fallback method...)${RESET}"
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
        if transcriptWindow is missing value then return "ERROR: no transcript window"
        set theTable to table 1 of scroll area 1 of transcriptWindow
        set output to ""
        set rowCount to count of rows of theTable
        set currentSpeaker to ""
        repeat with i from 1 to rowCount
            set el to UI element 1 of row i of theTable
            try
                set spkr to value of static text 1 of el
                if spkr is not missing value and spkr is not "" then set currentSpeaker to spkr
            end try
            repeat with ta in every text area of el
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
fi

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
