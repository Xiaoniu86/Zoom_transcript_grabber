# Zoom Transcript Grabber

**One command to save your Zoom Live Transcript to a text file — no host permission needed.**

Works on Mac and Windows. No installation, no sign-in, no dependencies.

---

## Why does this exist?

Zoom's desktop Live Transcript panel lets you *select* text but not *copy* it. The official "Save Transcript" feature requires the host to enable it — participants have no control.

This tool uses your operating system's built-in **Accessibility API** (the same interface used by screen readers like VoiceOver and NVDA) to read the text directly from Zoom's UI, bypassing the copy restriction entirely.

---

## Usage

### Mac

Open **Terminal** (`Cmd + Space` → type "Terminal") and paste:

```bash
curl -sSL https://raw.githubusercontent.com/Xiaoniu86/zoom-transcript-grabber/main/mac/grab.sh | bash
```

The first time you run it, macOS will ask you to grant Accessibility permission to Terminal. The script will guide you through it.

---

### Windows

Open **PowerShell** (right-click the Start menu → Windows PowerShell) and paste:

```powershell
irm https://raw.githubusercontent.com/Xiaoniu86/zoom-transcript-grabber/main/windows/grab.ps1 | iex
```

No extra permissions needed on Windows.

---

## Before you run

Make sure:
1. A Zoom meeting is in progress
2. The Transcript panel is open: click **Transcript** at the bottom toolbar → **View Full Transcript**

---

## What you get

A `.txt` file saved to your Desktop:

```
zoom_transcript_20260326_143022.txt
```

Sample output:
```
[Atendee A] Let's go over today's agenda...
[Atendee B] Sounds good. I have three things to cover.
This approach needs more discussion before we finalize.
```

---

## Permissions & Security

### Mac — Accessibility permission required

macOS requires explicit user approval before any app can read another app's UI content. This is a **security feature** — it prevents unauthorized programs from silently reading your screen.

**What this means in practice:**
> ⚠️ Once Terminal has Accessibility permission, any script you run in Terminal can read text from other apps' windows. **Only run scripts you trust.**

The script will ask if you want to revoke the permission when it finishes. You can also revoke it manually at any time:

**System Settings → Privacy & Security → Accessibility → uncheck Terminal**

### Windows — No extra permissions needed

Windows UI Automation is available to all applications by default. No approval dialogs, nothing to revoke afterward.

> ⚠️ The first time you run a `.ps1` script, Windows may show an execution policy warning. This is a standard system prompt — select "Allow" to proceed.

---

## Privacy

Zoom meetings may include other participants' speech. Please be mindful:

- Follow your organization's policies on meeting recordings
- Do not share others' words without their consent

---

## How it works

| Platform | API used | Notes |
|----------|----------|-------|
| Mac | macOS Accessibility API via AppleScript | Built-in, designed for screen readers |
| Windows | UI Automation API via PowerShell | Built-in, designed for assistive tech |

Zoom can block `Ctrl+C` and right-click menus, but it **cannot hide text from the OS** — screen readers need to be able to read it. This tool uses that same channel.

**This script will never:**
- Upload or transmit any data over the network
- Install software or modify system files
- Read content from any window other than Zoom's Transcript panel
- Store anything beyond the `.txt` file it saves to your Desktop

---

## FAQ

**Q: Can I run this after the meeting ends?**
A: Yes — as long as the Transcript panel is still open in Zoom, you can run it anytime before closing the app.

**Q: Does it capture the full history or just what's visible?**
A: It reads all content Zoom has loaded in memory, not just the visible portion — typically the full transcript.

**Q: Does it work with non-English transcripts?**
A: Yes. The output file is UTF-8 encoded and supports any language Zoom transcribes.

**Q: Where is Terminal on Mac?**
A: Press `Cmd + Space`, type "Terminal", and press Enter.

---

## Contributing

PRs and issues welcome, especially for:
- Testing across different Zoom versions
- Improving Windows accuracy
- Support for other meeting platforms (Teams, Google Meet)

---

## License

MIT — free to use, modify, and distribute.
