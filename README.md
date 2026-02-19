# Autopilot Diagnostic Analyzer

**A robust, modular PowerShell engine for automating root-cause analysis of Windows Autopilot failures.**

![Dashboard Screenshot](Media/dashboard_screenshot.png)

## 🚀 The Problem
Troubleshooting Windows Autopilot failures in an enterprise environment is notoriously time-consuming. Engineers often spend hours manually extracting `.cab` archives, parsing cryptic XML configuration files, and hunting through the verbose `IntuneManagementExtension.log` (CMTrace format) to find a single exit code or timeout.

## 🛠 The Solution
**Autopilot Analyzer** is a custom-built PowerShell module designed to reduce "Time to Diagnosis" from hours to seconds. It programmatically ingests raw diagnostic logs, parses the DOM and Event streams, and correlates the data into a high-level HTML executive dashboard.

## ✨ Key Features
* **Modular Architecture:** Built as a scalable PowerShell Module with separated Public/Private logic.
* **Native Ingestion:** Automatically validates and unpacks `.zip` and `.cab` archives without third-party dependencies.
* **XML DOM Parsing:** Navigates the `MDMDiagReport.xml` DOM to extract Tenant ID, OS Version, and ESP Configuration.
* **Regex Log Analysis:** Uses advanced Regex with Named Capture Groups to parse CMTrace-formatted logs, filtering specifically for Win32 App and PowerShell script failures.
* **Zero-Dependency Reporting:** Generates a self-contained, CSS-styled HTML dashboard with dark mode and heads-up metrics.

## 📦 Installation

This tool is designed as a standalone module.

1. Clone the repository:
   ```powershell
   git clone [https://github.com/YourUsername/AutopilotAnalyzer.git](https://github.com/YourUsername/AutopilotAnalyzer.git)