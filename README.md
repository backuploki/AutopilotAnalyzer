# Autopilot Analyzer - Architect Edition

**Autopilot Analyzer** is a monolithic, zero-dependency PowerShell diagnostic engine designed for Microsoft Intune and Windows Autopilot. It provides deep forensic analysis of MDM provisioning failures, parses offline Event Logs, tracks App IDs, and seamlessly maps errors to Microsoft documentation and MVP community knowledge bases.

Whether you are dropping it onto a single broken laptop or parsing a 50MB log bundle collected via Intune, this tool extracts the exact reason your device failed to enroll and gives you the actionable links to fix it.

## Key Features

* **Zero Dependencies:** A single `.ps1` file. No modules to install, no secondary scripts to manage.
* **Smart Archive Extraction:** Natively handles raw `.cab`, `.zip`, `.xml`, `.log`, and `.evtx` files, including recursively unpacking nested CABs.
* **Offline Event Log Parsing:** Reads OS-level Event Logs (`.evtx`) directly from the disk, hunting down W32Time sync issues, TPM attestation failures, and Schannel/TLS drops without needing the live OS.
* **Advanced Network Interception Hunting:** Explicitly tracks silent proxy blocks (`0xcaa7000f`) and HTTPS Inspection/SSL failures (`0x80072f8f`) across both the Intune Management Extension and Azure AD Operational logs.
* **Native GUI Dashboard:** Generates a secure, color-coded, and sanitized HTML dashboard detailing Critical Failures, Device State (UPN/Profile), and Win32 App Telemetry with Intune Admin Portal deep-links.
* **Data Portability:** Exports findings cleanly to CSV and JSON formats for integration into larger reporting workflows.

## Usage

The script is built to be flexible for both Helpdesk technicians and Senior Architects.

**Run Locally (GUI Prompt)**
If you execute the script without any parameters, it will spawn a native Windows File Explorer dialog, allowing you to browse and select your downloaded log archive.

```powershell
.\AutopilotAnalyzer.ps1

```

**Auto-Collect from Local Machine**
Run the tool directly on a failing device. It will automatically trigger the `MdmDiagnosticsTool`, generate the CAB file, and parse it in one motion. *(Requires Elevation)*

```powershell
.\AutopilotAnalyzer.ps1 -CollectLocal

```

**Headless Execution & Data Export**
Run the tool silently against a downloaded `.zip` or `.cab` log bundle and immediately export the telemetry to CSV and JSON, automatically highlighting the output in Explorer when complete.

```powershell
.\AutopilotAnalyzer.ps1 -LogPath "C:\Temp\AutopilotLogs.zip" -ExportJSON -ExportCSV

```

## Enterprise Value-Add: Cloud Automation

While `AutopilotAnalyzer.ps1` is the ultimate forensic tool for a single device, you can pair its diagnostic logic with Microsoft Sentinel and Azure Logic Apps to monitor your entire fleet.

Below are the KQL queries that mirror the script's advanced network interception tracking, ready to be deployed to your Log Analytics Workspace.

### KQL: Hunt for Autopilot Proxy and SSL Failures

Use this query in Log Analytics to identify devices hitting proxy walls or SSL inspection appliances during enrollment:

```kusto
let targetErrors = dynamic(["0x80072f8f", "0xcaa7000f"]);
Event
| where TimeGenerated > ago(14d)
| where EventLog =~ "Microsoft-Windows-AAD/Operational" 
    or EventLog contains "DeviceManagement-Enterprise-Diagnostics-Provider"
| where RenderedDescription has_any (targetErrors) or EventData has_any (targetErrors)
| extend ErrorType = case(
    RenderedDescription has "0x80072f8f", "HTTPS Inspection/SSL",
    RenderedDescription has "0xcaa7000f", "Proxy Block",
    "Unknown Enrollment Error"
)
| project TimeGenerated, Computer, EventLog, EventID, ErrorType, RenderedDescription
| summarize FailureCount = count(), LatestFailure = max(TimeGenerated) by Computer, ErrorType
| order by FailureCount desc

```

### Automation Blueprint

To move from reactive to proactive, connect the above KQL query to an **Azure Logic App**:

1. Trigger the Logic App on a Sentinel Alert when the query detects >5 proxy failures in an hour.
2. Format the JSON output into a Microsoft Teams Adaptive Card.
3. Alert the networking team automatically before Helpdesk tickets begin to surge.

## Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.