# Autopilot Analyzer - Architect Edition (V5)

Autopilot Analyzer is a high-performance PowerShell diagnostic engine designed to transform complex Intune and Autopilot log files into a clean, actionable visual dashboard. It automates the extraction and parsing of MDM and IME logs, reducing troubleshooting time from hours to seconds.

---

## Technical Features

### Dashboard Preview
![Main Dashboard](media/dashboard_screenshot.png)

### App Telemetry Detail
![App Telemetry Dashboard](media/app_telemetry.png)

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
   ```powershell
   git clone [https://github.com/backuploki/AutopilotAnalyzer.git](https://github.com/backuploki/AutopilotAnalyzer.git)