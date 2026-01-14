# CouncilWise Valuation Splitter

A robust, cross-platform PowerShell tool designed to process "CouncilWise" property valuation exports. It allows users to interactively select properties to **exclude** from a main dataset, automatically generating two clean JSON files: one for included properties and one for excluded ones.

## 🚀 Quick Start (Run without downloading)

You can run this tool directly from your terminal without manually downloading files.

### 1. Open PowerShell
* **Windows:** Press the **Windows Key**, type `PowerShell`, and press **Enter**.
* **Mac/Linux:** Open your **Terminal** and type `pwsh` (requires PowerShell 7+).

### 2. Copy & Paste this Command
Paste the following line into the window and press **Enter**:

```powershell
irm [https://raw.githubusercontent.com/CouncilWise/CW-JSON-Valuation-Splitter/main/VMOnline_JSON_Splitter.ps1](https://raw.githubusercontent.com/CouncilWise/CW-JSON-Valuation-Splitter/main/VMOnline_JSON_Splitter.ps1) | iex
💾 Manual Installation
If you prefer to download the script for repeated use:

Download the file VMOnline_JSON_Splitter.ps1 from this repository.

Open a terminal in the folder where you saved the file.

Run the script:

PowerShell

.\VMOnline_JSON_Splitter.ps1
📋 Features
Cross-Platform: Runs on Windows (PowerShell 5.1+) and macOS/Linux (PowerShell 7+).

Interactive UI:

Windows: Launches a native "Always-on-Top" GUI with checkboxes for easy selection.

Mac/Linux: Falls back to a clear, text-based terminal menu.

Smart File Handling: Supports drag-and-drop file paths and native OS file pickers.

Data Integrity: Validates JSON structure (checks for Valuation_ID) before processing.

🛠️ Usage Details
Selecting Exclusions
Once the script is running:

On Windows: A window will pop up. Check the boxes next to the properties you wish to remove from the main list. Click "Exclude Selected".

On Mac/Linux: A list will appear in the terminal. Type the index numbers of the properties you wish to remove (e.g., 1, 3, 5) and press Enter.

Output Files
The script will generate two new files in the same directory as your source file:

[Filename]_PropertiesIncluded.json - The clean list (everything you didn't check).

[Filename]_PropertiesExcluded.json - The list of items you removed.

📝 Input File Requirements
The input file must be a valid JSON array containing objects with at least the following property:

Valuation_ID

📄 License
MIT License