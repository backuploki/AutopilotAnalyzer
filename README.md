# Autopilot Analyzer - Architect Edition (V5)

Autopilot Analyzer is a high-performance PowerShell diagnostic engine designed to transform complex Intune and Autopilot log files into a clean, actionable visual dashboard. It automates the extraction and parsing of MDM and IME logs, reducing troubleshooting time from hours to seconds.

---

## Technical Features

### Dashboardd Preview
![App Telemetry Dashboard](app_telemetry.png)


- **Deep Extraction Engine:** Automatically processes nested .cab and .zip archives, including local log collection.
- **Intelligent Error Mapping:** Correlates hex error codes (e.g., 0x800705b4, -2016281112) with plain-English remediation insights.
- **The Architect Dashboard:**
    - **Microsoft Documentation:** Direct links to relevant official troubleshooting guides.
    - **MVP Knowledge Base:** Integrated links to expert articles from community leaders including Rudy Ooms, Andrew Taylor, and Steve Weiner.
    - **Admin Portal Deep-Links:** Context-aware buttons that open the specific Intune or Entra ID blade required to fix the detected error.
    - **App ID Tracking:** Automatically extracts Intune App GUIDs from logs and provides direct links to the application's properties in the Intune portal.
- **Export Capabilities:** Supports raw data export to JSON and CSV for advanced reporting and ticketing integration.

---

## Installation and Requirements

1. Clone this repository:
   git clone https://github.com/backuploki/AutopilotAnalyzer.git

2. Requirements:
   - Windows 10/11
   - PowerShell 5.1 or PowerShell 7+
   - Administrative privileges (if using the -CollectLocal switch)

---

## Usage Examples

### Analyze a specific log archive:
.\AutopilotAnalyzer.ps1 -LogPath "C:\Path\To\DiagLogs.zip"

### Collect and analyze logs from the local machine:
.\AutopilotAnalyzer.ps1 -CollectLocal

### Export analysis to JSON for documentation:
.\AutopilotAnalyzer.ps1 -LogPath "C:\Temp\Logs.zip" -ExportJSON

---

## Project Purpose
This tool was built to bridge the gap between raw log data and administrative action. By centralizing documentation, community expertise, and direct portal access, Autopilot Analyzer streamlines the modern endpoint management workflow.