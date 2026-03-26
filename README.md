# Zoom Transcript Grabber

**Save your Zoom Live Transcript to a text file with one command — no recording, no host permission, no screenshotting.**

Works on Mac and Windows. No installation, no sign-in, no dependencies.

---

### Quick Guide 快速说明

**English:** If you're in an active Zoom meeting with the Live Transcript panel open, but can't copy the text — open Terminal (Mac) or PowerShell (Windows), paste the one-line command below, and it will save everything to your Desktop as a `.txt` file. On Mac, you'll need to grant Terminal **Accessibility permission** once in System Settings → Privacy & Security → Accessibility. Remember to revoke it after you're done.

**中文：** 如果你正在开 Zoom 会议，已打开 Live Transcript 字幕面板，但文字无法复制——打开 Terminal（Mac）或 PowerShell（Windows），粘贴下方一行命令，它会把所有内容保存为桌面上的 `.txt` 文件。Mac 用户需要在「系统设置 → 隐私与安全 → 辅助功能」中给 Terminal 开启一次权限，使用完毕后记得关掉。

---

---

## The problem this solves

To get a transcript of a Zoom meeting through the official route, either the host must enable recording beforehand, or someone needs to start a cloud recording — and the transcript only becomes available after the meeting ends.

But sometimes you're already in a meeting, fully engaged, and you realize partway through that you want to capture what's been said. You didn't record. The meeting isn't over. You can see the Live Transcript panel right there on your screen — but Zoom has copy-paste disabled on it. Your only option is to take screenshot after screenshot and run OCR on each one.

This tool fixes that. As long as you're in an active meeting with the Transcript panel open, one command saves everything to a text file on your Desktop — without ending the meeting, without asking the host, and without taking a single screenshot.

---

## How to use it

### Before you run

1. A Zoom meeting must be in progress
2. The Transcript panel must be open: click **CC / Captions** at the bottom toolbar → **View Full Transcript**
3. Keep both the meeting and the Transcript panel open while the script runs — do not close them

### Mac

Open **Terminal** (`Cmd + Space` → type "Terminal") and paste:

```bash
curl -sSL https://raw.githubusercontent.com/Xiaoniu86/zoom-transcript-grabber/main/mac/grab.sh | bash
```

The first time you run it, you'll need to grant Terminal the Accessibility permission. The script will detect this and walk you through it automatically.

### Windows

Open **PowerShell** (right-click the Start menu → Windows PowerShell) and paste:

```powershell
irm https://raw.githubusercontent.com/Xiaoniu86/zoom-transcript-grabber/main/windows/grab.ps1 | iex
```

No extra permissions needed on Windows.

---

## What you get

A `.txt` file saved to your Desktop:

```
zoom_transcript_20260326_143022.txt
```

Sample output:
```
[X] Let's go over today's agenda...
[Y] Sounds good. I have three things to cover.
This approach needs more discussion before we finalize.
```

---

## Permissions & what to do after

### Mac — Accessibility permission

The script needs Terminal to have **Accessibility** permission. This is a macOS security requirement — the OS won't let any app read another app's UI content without your explicit approval.

When you run the script for the first time, it will ask you to open System Settings and grant the permission. This takes about 30 seconds.

> ⚠️ Once Terminal has Accessibility permission, any script you run in Terminal can read text from other apps on your screen. **Only run scripts you trust.**

**After you're done, revoke the permission.** The script will prompt you to do this when it finishes. You can also do it manually at any time:

**System Settings → Privacy & Security → Accessibility → uncheck Terminal**

This has no effect on your computer other than removing the permission. Your files, settings, and data are completely untouched.

### Windows — No extra permissions needed

Windows UI Automation is available to all applications by default. Nothing to grant, nothing to revoke.

> ⚠️ The first time you run a `.ps1` script, Windows may show an execution policy warning. This is a standard system prompt — select "Allow" to proceed.

---

## Safety

**This script will never:**
- Upload or transmit any data over the network
- Install software or modify system files
- Read content from any window other than Zoom's Transcript panel
- Leave any persistent process running on your computer

The only thing it writes to your computer is the `.txt` file on your Desktop.

**Regarding meeting content:** the transcript may include other participants' speech. Please follow your organization's policies on meeting notes, and do not share others' words without their consent.

---

## How it works

Zoom blocks copy-paste by intercepting `Ctrl+C` and disabling the right-click menu. But the text is still rendered on screen — and macOS and Windows both provide a system-level **Accessibility API** that allows assistive software (like screen readers for blind users) to read any app's UI text. Zoom cannot hide text from this API without also breaking screen reader support for visually impaired users.

This tool uses that same read-only interface to extract the transcript text directly.

| Platform | API | Notes |
|----------|-----|-------|
| Mac | macOS Accessibility API via AppleScript | Built-in, designed for VoiceOver and similar tools |
| Windows | UI Automation API via PowerShell | Built-in, designed for NVDA and similar tools |

---

## FAQ

**Q: Can I run this after the meeting ends?**
A: Yes — as long as Zoom is still open and the Transcript panel is still visible, you can run it any time before closing the app.

**Q: Does it capture everything or just what's currently on screen?**
A: It reads all content Zoom has loaded in memory, not just the visible portion — typically the full transcript from the moment Live Transcript was enabled.

**Q: Does it work with non-English transcripts?**
A: Yes. The output file is UTF-8 encoded and supports any language Zoom transcribes.

**Q: Where is Terminal on Mac?**
A: Press `Cmd + Space`, type "Terminal", and press Enter.

---

## Contributing

PRs and issues welcome, especially for:
- Testing across different Zoom versions
- Improving Windows reliability
- Support for other meeting platforms (Teams, Google Meet)

---

## License

MIT — free to use, modify, and distribute.
