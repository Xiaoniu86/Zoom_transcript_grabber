# ============================================================
# Zoom Transcript Grabber - Windows
# How it works: Uses Windows UI Automation API to read Zoom's UI.
# This is a system-level read-only interface designed for screen
# readers. It cannot modify any data on your computer.
# Usage: Right-click this file → "Run with PowerShell"
# ============================================================

$ErrorActionPreference = "SilentlyContinue"

function Write-Header {
    Write-Host ""
    Write-Host "╔════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║   Zoom Transcript Grabber  (Windows)   ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Step($msg)    { Write-Host "▶ $msg" -ForegroundColor Yellow }
function Write-Success($msg) { Write-Host "✅ $msg" -ForegroundColor Green }
function Write-Fail($msg)    { Write-Host "❌ $msg" -ForegroundColor Red }

Write-Header

# ── Step 1: Check Zoom is running ─────────────────────────────
Write-Step "Checking if Zoom is running..."
$zoomProcess = Get-Process -Name "Zoom" -ErrorAction SilentlyContinue
if (-not $zoomProcess) {
    Write-Fail "Zoom is not running. Please start a Zoom meeting first."
    Read-Host "Press Enter to exit"
    exit 1
}
Write-Success "Zoom is running (PID: $($zoomProcess.Id))"

# ── Step 2: Load UI Automation ────────────────────────────────
Write-Step "Loading UI Automation..."
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

$automation = [System.Windows.Automation.AutomationElement]

# ── Step 3: Find the Transcript window ───────────────────────
Write-Step "Looking for the Transcript window..."

$desktop = $automation::RootElement
$condition = New-Object System.Windows.Automation.PropertyCondition(
    $automation::ProcessIdProperty, $zoomProcess.Id
)

$allWindows = $desktop.FindAll(
    [System.Windows.Automation.TreeScope]::Children,
    $condition
)

$transcriptWindow = $null
foreach ($win in $allWindows) {
    $name = $win.GetCurrentPropertyValue($automation::NameProperty)
    if ($name -match "Transcript") {
        $transcriptWindow = $win
        break
    }
}

if (-not $transcriptWindow) {
    Write-Fail "No Transcript window found."
    Write-Host "In your Zoom meeting, click 'Captions' or 'CC' at the bottom toolbar," -ForegroundColor Yellow
    Write-Host "then select 'View Full Transcript' to open the panel." -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Success "Transcript window found"

# ── Step 4: Read all text recursively ────────────────────────
Write-Step "Reading transcript content..."

function Get-AllText {
    param($element, $depth = 0)
    $texts = @()
    try {
        $name        = $element.GetCurrentPropertyValue($automation::NameProperty)
        $controlType = $element.GetCurrentPropertyValue($automation::ControlTypeProperty)
        $textType    = [System.Windows.Automation.ControlType]::Text
        $editType    = [System.Windows.Automation.ControlType]::Edit
        $docType     = [System.Windows.Automation.ControlType]::Document

        if (($controlType -eq $textType -or $controlType -eq $editType -or $controlType -eq $docType) `
            -and $name -and $name.Trim() -ne "") {
            $texts += $name.Trim()
        }
    } catch {}

    if ($depth -lt 8) {
        try {
            $children = $element.FindAll(
                [System.Windows.Automation.TreeScope]::Children,
                [System.Windows.Automation.Condition]::TrueCondition
            )
            foreach ($child in $children) {
                $texts += Get-AllText $child ($depth + 1)
            }
        } catch {}
    }
    return $texts
}

$allTexts = Get-AllText $transcriptWindow
$output   = $allTexts | Where-Object { $_ -ne "" } | Select-Object -Unique

# ── Step 5: Save to Desktop ───────────────────────────────────
if ($output.Count -eq 0) {
    Write-Fail "No text found. Make sure the Transcript panel is open and has content."
    Read-Host "Press Enter to exit"
    exit 1
}

$timestamp  = Get-Date -Format "yyyyMMdd_HHmmss"
$outputPath = "$env:USERPROFILE\Desktop\zoom_transcript_$timestamp.txt"
$output | Out-File -FilePath $outputPath -Encoding UTF8

$lineCount = $output.Count
$charCount = ($output | Measure-Object -Character).Characters

Write-Host ""
Write-Success "Done!"
Write-Host "   📄 File: zoom_transcript_$timestamp.txt" -ForegroundColor White
Write-Host "   📍 Saved to: $outputPath"               -ForegroundColor White
Write-Host "   📊 $lineCount lines · $charCount characters" -ForegroundColor White
Write-Host ""

Start-Process explorer.exe -ArgumentList "/select,`"$outputPath`""

# ── Note: no permission to revoke on Windows ─────────────────
Write-Host "────────────────────────────────────────" -ForegroundColor Cyan
Write-Host "💡 No extra permissions were granted — UI Automation is a built-in" -ForegroundColor Cyan
Write-Host "   Windows feature available to all applications." -ForegroundColor Cyan
Write-Host ""
Read-Host "Press Enter to exit"
