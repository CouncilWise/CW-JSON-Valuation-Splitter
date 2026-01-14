<#
.SYNOPSIS
    Splits a Councilwise Valuation Export JSON file into two separate files based on user-selected exclusions. 
    It features a custom Checkbox GUI for Windows users and a text-based menu for Mac/Linux users, with robust cross-platform file handling.

.DESCRIPTION
    This script is designed to process property valuation data exported from Councilwise systems (JSON format). 
    
    Upon execution, the script performs the following steps:
    1.  **File Selection:** -   Prompts the user to select a JSON file. 
        -   Uses a native file picker dialog on Windows and macOS.
        -   Supports drag-and-drop file input for all platforms (including Linux or if the GUI picker fails).
    2.  **Validation:** -   Checks the file structure to ensure it contains the required 'Valuation_ID' field.
        -   Rejects invalid files to prevent data corruption.
    3.  **User Selection (Exclusion):**
        -   **Windows:** Opens a "Always-on-Top" popup window with checkboxes. Users can easily tick the properties they wish to remove from the main list.
        -   **Mac/Linux:** Displays a numbered list in the terminal. Users type the index numbers of the properties they wish to remove.
    4.  **Export:**
        -   Generates two new JSON files in the same directory as the original file:
            -   `*_PropertiesIncluded.json`: Contains all properties *not* selected by the user.
            -   `*_PropertiesExcluded.json`: Contains only the properties selected by the user.

.NOTES
    **Author:** ReadyTech
    **Version:** 1.0 (Cross-Platform GUI Enhanced)
    **Date:** January 2026
    
    **Requirements:**
    -   PowerShell 5.1 (Windows) or PowerShell 7+ (Mac/Linux).
    -   Input file must be a valid JSON array containing objects with a 'Valuation_ID' property.
    
    **Usage Tips:**
    -   **Windows:** The selection window is set to 'TopMost', meaning it will appear above all other open windows.
    -   **Mac:** If the file picker does not appear, look for a bouncing icon in your dock, or simply drag and drop the file into the terminal window when prompted.
    -   **Cancellation:** You can cancel the process at any time by clicking 'Cancel' (Windows) or typing 'Q' (Mac/Linux). No files will be created if cancelled.

.EXAMPLE
    .\Split-Valuations.ps1
    # Starts the script and prompts for a file.

.EXAMPLE
    .\Split-Valuations.ps1 -InputFile "C:\Data\VMO_Export.json"
    # Starts the script using the specific file provided.
#>

param (
    [Parameter(Mandatory=$false, HelpMessage="Full path to the source JSON file.")]
    [string]$InputFile
)

# --- 1. HELPER: Cross-Platform File Picker ---
function Get-FileFromUser {
    if ($IsWindows) {
        try {
            Add-Type -AssemblyName System.Windows.Forms
            $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
            $OpenFileDialog.Filter = "JSON Files (*.json)|*.json|All Files (*.*)|*.*"
            $OpenFileDialog.Title = "Select the Valuation Export JSON File"
            if ($OpenFileDialog.ShowDialog() -eq 'OK') {
                return $OpenFileDialog.FileName
            }
        } catch { }
    }
    elseif ($IsMacOS) {
        try {
            $osaCmd = 'set theFile to choose file with prompt "Select the Valuation JSON File"
                       return POSIX path of theFile'
            $result = & osascript -e $osaCmd 2>$null
            if (-not [string]::IsNullOrWhiteSpace($result)) { return $result.Trim() }
        } catch { }
    }
    
    # Fallback
    Write-Host "Please enter the full path to your JSON file (or drag and drop it here):" -ForegroundColor Yellow
    $manualPath = Read-Host
    if (-not [string]::IsNullOrWhiteSpace($manualPath)) {
        $manualPath = $manualPath.Trim()
        if ($manualPath.StartsWith("&")) { $manualPath = $manualPath.Substring(1).Trim() }
        $manualPath = $manualPath.Trim("'").Trim('"')
    }
    return $manualPath
}

# --- 2. HELPER: Windows Checkbox GUI ---
function Show-WindowsCheckboxGUI {
    param($Data)

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    # Create Form
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Exclude Properties"
    $form.Size = New-Object System.Drawing.Size(600, 500)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false

    # Instruction Label
    $label = New-Object System.Windows.Forms.Label
    $label.Text = "Check the boxes next to the properties you want to EXCLUDE."
    $label.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $label.ForeColor = "Red"
    $label.AutoSize = $true
    $label.Location = New-Object System.Drawing.Point(20, 15)
    $form.Controls.Add($label)

    # Sub-label
    $subLabel = New-Object System.Windows.Forms.Label
    $subLabel.Text = "Any item checked below will be moved to the '_Excluded' file."
    $subLabel.AutoSize = $true
    $subLabel.Location = New-Object System.Drawing.Point(20, 38)
    $form.Controls.Add($subLabel)

    # ListView (The Checkbox List)
    $listView = New-Object System.Windows.Forms.ListView
    $listView.View = "Details"
    $listView.CheckBoxes = $true
    $listView.FullRowSelect = $true
    $listView.GridLines = $true
    $listView.Location = New-Object System.Drawing.Point(20, 65)
    $listView.Size = New-Object System.Drawing.Size(540, 330)
    
    # Columns
    $listView.Columns.Add("Valuation ID", 120) | Out-Null
    $listView.Columns.Add("Classification", 120) | Out-Null
    $listView.Columns.Add("Total Value", 120) | Out-Null
    
    # Populate List
    foreach ($row in $Data) {
        $total = 0
        if ($row.Valuations) {
            $total = $row.Valuations | Where-Object { $_.Valuation_New } | Measure-Object -Property Valuation_New -Sum | Select-Object -ExpandProperty Sum
        }
        
        $item = New-Object System.Windows.Forms.ListViewItem($row.Valuation_ID.ToString())
        $item.SubItems.Add($row.Property_Classification.ToString()) | Out-Null
        $item.SubItems.Add($total.ToString("C0")) | Out-Null # Currency format
        $item.Tag = $row # Store the actual object in the Tag for retrieval
        
        $listView.Items.Add($item) | Out-Null
    }
    $form.Controls.Add($listView)

    # OK Button
    $btnOK = New-Object System.Windows.Forms.Button
    $btnOK.Text = "Exclude Selected"
    $btnOK.DialogResult = "OK"
    $btnOK.Location = New-Object System.Drawing.Point(350, 410)
    $btnOK.Size = New-Object System.Drawing.Size(120, 30)
    $form.Controls.Add($btnOK)

    # Cancel Button
    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text = "Cancel"
    $btnCancel.DialogResult = "Cancel"
    $btnCancel.Location = New-Object System.Drawing.Point(480, 410)
    $btnCancel.Size = New-Object System.Drawing.Size(90, 30)
    $form.Controls.Add($btnCancel)

    # Show Dialog
    $result = $form.ShowDialog()

    if ($result -eq "OK") {
        # Retrieve the objects from the checked items
        $selectedObjs = @()
        foreach ($checkedItem in $listView.CheckedItems) {
            $selectedObjs += $checkedItem.Tag
        }
        return $selectedObjs
    }
    else {
        return "CANCELLED"
    }
}

# --- 3. HELPER: Mac/Linux Text Menu ---
function Show-MacConsoleMenu {
    param($Data)
    Clear-Host
    Write-Host "--- EXCLUSION MENU ---" -ForegroundColor Cyan
    $index = 0
    foreach ($row in $Data) {
        $total = 0
        if ($row.Valuations) {
            $total = $row.Valuations | Where-Object { $_.Valuation_New } | Measure-Object -Property Valuation_New -Sum | Select-Object -ExpandProperty Sum
        }
        Write-Host "[$index] ID: $($row.Valuation_ID) | $($row.Property_Classification) | Value: $total"
        $index++
    }
    Write-Host "`nINSTRUCTIONS:" -ForegroundColor Yellow
    Write-Host "Type the numbers of items to EXCLUDE (comma separated). Example: 1, 3"
    Write-Host "Type 'Q' to Cancel."
    
    $selection = Read-Host "Enter selection"
    if ($selection -match "^(q|quit|cancel)$") { return "CANCELLED" }
    if ([string]::IsNullOrWhiteSpace($selection)) { return @() }

    $indices = $selection -split ',' | ForEach-Object { $_.Trim() }
    $selectedObjects = @()
    foreach ($i in $indices) {
        if ($i -match '^\d+$' -and $i -lt $Data.Count) {
            $selectedObjects += $Data[[int]$i]
        }
    }
    return $selectedObjects
}

# --- MAIN EXECUTION ---

# 1. Get File
if ([string]::IsNullOrWhiteSpace($InputFile)) { $InputFile = Get-FileFromUser }
if (-not (Test-Path -LiteralPath $InputFile)) { Write-Error "File not found."; exit }

# 2. Read JSON
try { $jsonData = Get-Content -LiteralPath $InputFile -Raw | ConvertFrom-Json -ErrorAction Stop } catch { Write-Error "Invalid JSON."; exit }
if ($jsonData -isnot [System.Array]) { $jsonData = @($jsonData) }
if ($jsonData.Count -eq 0 -or $null -eq $jsonData[0].Valuation_ID) { Write-Error "Structure Mismatch: Missing Valuation_ID."; exit }

# 3. Select Exclusions (OS Detection)
if ($IsWindows) {
    $excludedProxies = Show-WindowsCheckboxGUI -Data $jsonData
} else {
    $excludedProxies = Show-MacConsoleMenu -Data $jsonData
}

# 4. Handle Cancel/Empty
if ($excludedProxies -eq "CANCELLED") {
    Write-Host "`nCancelled by user. No files exported." -ForegroundColor Red; Read-Host "Press Enter"; exit
}
if ($excludedProxies.Count -eq 0) {
    Write-Host "`nNo exclusions selected. No files exported." -ForegroundColor Yellow; Read-Host "Press Enter"; exit
}

# 5. Process & Export
$excludedIDs = $excludedProxies.Valuation_ID
$excludedRecords = $jsonData | Where-Object { $excludedIDs -contains $_.Valuation_ID }
$includedRecords = $jsonData | Where-Object { $excludedIDs -notcontains $_.Valuation_ID }

$fileInfo = Get-Item -LiteralPath $InputFile
$base = $fileInfo.BaseName; $dir = $fileInfo.DirectoryName
$incPath = Join-Path $dir "${base}_PropertiesIncluded.json"
$excPath = Join-Path $dir "${base}_PropertiesExcluded.json"

$includedRecords | ConvertTo-Json -Depth 10 | Set-Content -Path $incPath
$excludedRecords | ConvertTo-Json -Depth 10 | Set-Content -Path $excPath

Write-Host "`nDone! Files saved:" -ForegroundColor Green
Write-Host "Included: $incPath"
Write-Host "Excluded: $excPath"
# SIG # Begin signature block
# MIIyugYJKoZIhvcNAQcCoIIyqzCCMqcCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDaIsCQsW7LOagW
# g99kThVbUevpRBL+pU0JbeCL991qeqCCK+cwggVvMIIEV6ADAgECAhBI/JO0YFWU
# jTanyYqJ1pQWMA0GCSqGSIb3DQEBDAUAMHsxCzAJBgNVBAYTAkdCMRswGQYDVQQI
# DBJHcmVhdGVyIE1hbmNoZXN0ZXIxEDAOBgNVBAcMB1NhbGZvcmQxGjAYBgNVBAoM
# EUNvbW9kbyBDQSBMaW1pdGVkMSEwHwYDVQQDDBhBQUEgQ2VydGlmaWNhdGUgU2Vy
# dmljZXMwHhcNMjEwNTI1MDAwMDAwWhcNMjgxMjMxMjM1OTU5WjBWMQswCQYDVQQG
# EwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMS0wKwYDVQQDEyRTZWN0aWdv
# IFB1YmxpYyBDb2RlIFNpZ25pbmcgUm9vdCBSNDYwggIiMA0GCSqGSIb3DQEBAQUA
# A4ICDwAwggIKAoICAQCN55QSIgQkdC7/FiMCkoq2rjaFrEfUI5ErPtx94jGgUW+s
# hJHjUoq14pbe0IdjJImK/+8Skzt9u7aKvb0Ffyeba2XTpQxpsbxJOZrxbW6q5KCD
# J9qaDStQ6Utbs7hkNqR+Sj2pcaths3OzPAsM79szV+W+NDfjlxtd/R8SPYIDdub7
# P2bSlDFp+m2zNKzBenjcklDyZMeqLQSrw2rq4C+np9xu1+j/2iGrQL+57g2extme
# me/G3h+pDHazJyCh1rr9gOcB0u/rgimVcI3/uxXP/tEPNqIuTzKQdEZrRzUTdwUz
# T2MuuC3hv2WnBGsY2HH6zAjybYmZELGt2z4s5KoYsMYHAXVn3m3pY2MeNn9pib6q
# RT5uWl+PoVvLnTCGMOgDs0DGDQ84zWeoU4j6uDBl+m/H5x2xg3RpPqzEaDux5mcz
# mrYI4IAFSEDu9oJkRqj1c7AGlfJsZZ+/VVscnFcax3hGfHCqlBuCF6yH6bbJDoEc
# QNYWFyn8XJwYK+pF9e+91WdPKF4F7pBMeufG9ND8+s0+MkYTIDaKBOq3qgdGnA2T
# OglmmVhcKaO5DKYwODzQRjY1fJy67sPV+Qp2+n4FG0DKkjXp1XrRtX8ArqmQqsV/
# AZwQsRb8zG4Y3G9i/qZQp7h7uJ0VP/4gDHXIIloTlRmQAOka1cKG8eOO7F/05QID
# AQABo4IBEjCCAQ4wHwYDVR0jBBgwFoAUoBEKIz6W8Qfs4q8p74Klf9AwpLQwHQYD
# VR0OBBYEFDLrkpr/NZZILyhAQnAgNpFcF4XmMA4GA1UdDwEB/wQEAwIBhjAPBgNV
# HRMBAf8EBTADAQH/MBMGA1UdJQQMMAoGCCsGAQUFBwMDMBsGA1UdIAQUMBIwBgYE
# VR0gADAIBgZngQwBBAEwQwYDVR0fBDwwOjA4oDagNIYyaHR0cDovL2NybC5jb21v
# ZG9jYS5jb20vQUFBQ2VydGlmaWNhdGVTZXJ2aWNlcy5jcmwwNAYIKwYBBQUHAQEE
# KDAmMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5jb21vZG9jYS5jb20wDQYJKoZI
# hvcNAQEMBQADggEBABK/oe+LdJqYRLhpRrWrJAoMpIpnuDqBv0WKfVIHqI0fTiGF
# OaNrXi0ghr8QuK55O1PNtPvYRL4G2VxjZ9RAFodEhnIq1jIV9RKDwvnhXRFAZ/ZC
# J3LFI+ICOBpMIOLbAffNRk8monxmwFE2tokCVMf8WPtsAO7+mKYulaEMUykfb9gZ
# pk+e96wJ6l2CxouvgKe9gUhShDHaMuwV5KZMPWw5c9QLhTkg4IUaaOGnSDip0TYl
# d8GNGRbFiExmfS9jzpjoad+sPKhdnckcW67Y8y90z7h+9teDnRGWYpquRRPaf9xH
# +9/DUp/mBlXpnYzyOmJRvOwkDynUWICE5EV7WtgwggYUMIID/KADAgECAhB6I67a
# U2mWD5HIPlz0x+M/MA0GCSqGSIb3DQEBDAUAMFcxCzAJBgNVBAYTAkdCMRgwFgYD
# VQQKEw9TZWN0aWdvIExpbWl0ZWQxLjAsBgNVBAMTJVNlY3RpZ28gUHVibGljIFRp
# bWUgU3RhbXBpbmcgUm9vdCBSNDYwHhcNMjEwMzIyMDAwMDAwWhcNMzYwMzIxMjM1
# OTU5WjBVMQswCQYDVQQGEwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMSww
# KgYDVQQDEyNTZWN0aWdvIFB1YmxpYyBUaW1lIFN0YW1waW5nIENBIFIzNjCCAaIw
# DQYJKoZIhvcNAQEBBQADggGPADCCAYoCggGBAM2Y2ENBq26CK+z2M34mNOSJjNPv
# IhKAVD7vJq+MDoGD46IiM+b83+3ecLvBhStSVjeYXIjfa3ajoW3cS3ElcJzkyZlB
# nwDEJuHlzpbN4kMH2qRBVrjrGJgSlzzUqcGQBaCxpectRGhhnOSwcjPMI3G0hedv
# 2eNmGiUbD12OeORN0ADzdpsQ4dDi6M4YhoGE9cbY11XxM2AVZn0GiOUC9+XE0wI7
# CQKfOUfigLDn7i/WeyxZ43XLj5GVo7LDBExSLnh+va8WxTlA+uBvq1KO8RSHUQLg
# zb1gbL9Ihgzxmkdp2ZWNuLc+XyEmJNbD2OIIq/fWlwBp6KNL19zpHsODLIsgZ+WZ
# 1AzCs1HEK6VWrxmnKyJJg2Lv23DlEdZlQSGdF+z+Gyn9/CRezKe7WNyxRf4e4bwU
# trYE2F5Q+05yDD68clwnweckKtxRaF0VzN/w76kOLIaFVhf5sMM/caEZLtOYqYad
# tn034ykSFaZuIBU9uCSrKRKTPJhWvXk4CllgrwIDAQABo4IBXDCCAVgwHwYDVR0j
# BBgwFoAU9ndq3T/9ARP/FqFsggIv0Ao9FCUwHQYDVR0OBBYEFF9Y7UwxeqJhQo1S
# gLqzYZcZojKbMA4GA1UdDwEB/wQEAwIBhjASBgNVHRMBAf8ECDAGAQH/AgEAMBMG
# A1UdJQQMMAoGCCsGAQUFBwMIMBEGA1UdIAQKMAgwBgYEVR0gADBMBgNVHR8ERTBD
# MEGgP6A9hjtodHRwOi8vY3JsLnNlY3RpZ28uY29tL1NlY3RpZ29QdWJsaWNUaW1l
# U3RhbXBpbmdSb290UjQ2LmNybDB8BggrBgEFBQcBAQRwMG4wRwYIKwYBBQUHMAKG
# O2h0dHA6Ly9jcnQuc2VjdGlnby5jb20vU2VjdGlnb1B1YmxpY1RpbWVTdGFtcGlu
# Z1Jvb3RSNDYucDdjMCMGCCsGAQUFBzABhhdodHRwOi8vb2NzcC5zZWN0aWdvLmNv
# bTANBgkqhkiG9w0BAQwFAAOCAgEAEtd7IK0ONVgMnoEdJVj9TC1ndK/HYiYh9lVU
# acahRoZ2W2hfiEOyQExnHk1jkvpIJzAMxmEc6ZvIyHI5UkPCbXKspioYMdbOnBWQ
# Un733qMooBfIghpR/klUqNxx6/fDXqY0hSU1OSkkSivt51UlmJElUICZYBodzD3M
# /SFjeCP59anwxs6hwj1mfvzG+b1coYGnqsSz2wSKr+nDO+Db8qNcTbJZRAiSazr7
# KyUJGo1c+MScGfG5QHV+bps8BX5Oyv9Ct36Y4Il6ajTqV2ifikkVtB3RNBUgwu/m
# SiSUice/Jp/q8BMk/gN8+0rNIE+QqU63JoVMCMPY2752LmESsRVVoypJVt8/N3qQ
# 1c6FibbcRabo3azZkcIdWGVSAdoLgAIxEKBeNh9AQO1gQrnh1TA8ldXuJzPSuALO
# z1Ujb0PCyNVkWk7hkhVHfcvBfI8NtgWQupiaAeNHe0pWSGH2opXZYKYG4Lbukg7H
# pNi/KqJhue2Keak6qH9A8CeEOB7Eob0Zf+fU+CCQaL0cJqlmnx9HCDxF+3BLbUuf
# rV64EbTI40zqegPZdA+sXCmbcZy6okx/SjwsusWRItFA3DE8MORZeFb6BmzBtqKJ
# 7l939bbKBy2jvxcJI98Va95Q5JnlKor3m0E7xpMeYRriWklUPsetMSf2NvUQa/E5
# vVyefQIwggYcMIIEBKADAgECAhAz1wiokUBTGeKlu9M5ua1uMA0GCSqGSIb3DQEB
# DAUAMFYxCzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQxLTAr
# BgNVBAMTJFNlY3RpZ28gUHVibGljIENvZGUgU2lnbmluZyBSb290IFI0NjAeFw0y
# MTAzMjIwMDAwMDBaFw0zNjAzMjEyMzU5NTlaMFcxCzAJBgNVBAYTAkdCMRgwFgYD
# VQQKEw9TZWN0aWdvIExpbWl0ZWQxLjAsBgNVBAMTJVNlY3RpZ28gUHVibGljIENv
# ZGUgU2lnbmluZyBDQSBFViBSMzYwggGiMA0GCSqGSIb3DQEBAQUAA4IBjwAwggGK
# AoIBgQC70f4et0JbePWQp64sg/GNIdMwhoV739PN2RZLrIXFuwHP4owoEXIEdiyB
# xasSekBKxRDogRQ5G19PB/YwMDB/NSXlwHM9QAmU6Kj46zkLVdW2DIseJ/jePiLB
# v+9l7nPuZd0o3bsffZsyf7eZVReqskmoPBBqOsMhspmoQ9c7gqgZYbU+alpduLye
# E9AKnvVbj2k4aOqlH1vKI+4L7bzQHkNDbrBTjMJzKkQxbr6PuMYC9ruCBBV5DFIg
# 6JgncWHvL+T4AvszWbX0w1Xn3/YIIq620QlZ7AGfc4m3Q0/V8tm9VlkJ3bcX9sR0
# gLqHRqwG29sEDdVOuu6MCTQZlRvmcBMEJd+PuNeEM4xspgzraLqVT3xE6NRpjSV5
# wyHxNXf4T7YSVZXQVugYAtXueciGoWnxG06UE2oHYvDQa5mll1CeHDOhHu5hiwVo
# HI717iaQg9b+cYWnmvINFD42tRKtd3V6zOdGNmqQU8vGlHHeBzoh+dYyZ+CcblSG
# oGSgg8sCAwEAAaOCAWMwggFfMB8GA1UdIwQYMBaAFDLrkpr/NZZILyhAQnAgNpFc
# F4XmMB0GA1UdDgQWBBSBMpJBKyjNRsjEosYqORLsSKk/FDAOBgNVHQ8BAf8EBAMC
# AYYwEgYDVR0TAQH/BAgwBgEB/wIBADATBgNVHSUEDDAKBggrBgEFBQcDAzAaBgNV
# HSAEEzARMAYGBFUdIAAwBwYFZ4EMAQMwSwYDVR0fBEQwQjBAoD6gPIY6aHR0cDov
# L2NybC5zZWN0aWdvLmNvbS9TZWN0aWdvUHVibGljQ29kZVNpZ25pbmdSb290UjQ2
# LmNybDB7BggrBgEFBQcBAQRvMG0wRgYIKwYBBQUHMAKGOmh0dHA6Ly9jcnQuc2Vj
# dGlnby5jb20vU2VjdGlnb1B1YmxpY0NvZGVTaWduaW5nUm9vdFI0Ni5wN2MwIwYI
# KwYBBQUHMAGGF2h0dHA6Ly9vY3NwLnNlY3RpZ28uY29tMA0GCSqGSIb3DQEBDAUA
# A4ICAQBfNqz7+fZyWhS38Asd3tj9lwHS/QHumS2G6Pa38Dn/1oFKWqdCSgotFZ3m
# lP3FaUqy10vxFhJM9r6QZmWLLXTUqwj3ahEDCHd8vmnhsNufJIkD1t5cpOCy1rTP
# 4zjVuW3MJ9bOZBHoEHJ20/ng6SyJ6UnTs5eWBgrh9grIQZqRXYHYNneYyoBBl6j4
# kT9jn6rNVFRLgOr1F2bTlHH9nv1HMePpGoYd074g0j+xUl+yk72MlQmYco+VAfSY
# Q6VK+xQmqp02v3Kw/Ny9hA3s7TSoXpUrOBZjBXXZ9jEuFWvilLIq0nQ1tZiao/74
# Ky+2F0snbFrmuXZe2obdq2TWauqDGIgbMYL1iLOUJcAhLwhpAuNMu0wqETDrgXkG
# 4UGVKtQg9guT5Hx2DJ0dJmtfhAH2KpnNr97H8OQYok6bLyoMZqaSdSa+2UA1E2+u
# pjcaeuitHFFjBypWBmztfhj24+xkc6ZtCDaLrw+ZrnVrFyvCTWrDUUZBVumPwo3/
# E3Gb2u2e05+r5UWmEsUUWlJBl6MGAAjF5hzqJ4I8O9vmRsTvLQA1E802fZ3lqicI
# BczOwDYOSxlP0GOabb/FKVMxItt1UHeG0PL4au5rBhs+hSMrl8h+eplBDN1Yfw6o
# wxI9OjWb4J0sjBeBVESoeh2YnZZ/WVimVGX/UUIL+Efrz/jlvzCCBmIwggTKoAMC
# AQICEQCkKTtuHt3XpzQIh616TrckMA0GCSqGSIb3DQEBDAUAMFUxCzAJBgNVBAYT
# AkdCMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQxLDAqBgNVBAMTI1NlY3RpZ28g
# UHVibGljIFRpbWUgU3RhbXBpbmcgQ0EgUjM2MB4XDTI1MDMyNzAwMDAwMFoXDTM2
# MDMyMTIzNTk1OVowcjELMAkGA1UEBhMCR0IxFzAVBgNVBAgTDldlc3QgWW9ya3No
# aXJlMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQxMDAuBgNVBAMTJ1NlY3RpZ28g
# UHVibGljIFRpbWUgU3RhbXBpbmcgU2lnbmVyIFIzNjCCAiIwDQYJKoZIhvcNAQEB
# BQADggIPADCCAgoCggIBANOElfRupFN48j0QS3gSBzzclIFTZ2Gsn7BjsmBF659/
# kpA2Ey7NXK3MP6JdrMBNU8wdmkf+SSIyjX++UAYWtg3Y/uDRDyg8RxHeHRJ+0U1j
# HEyH5uPdk1ttiPC3x/gOxIc9P7Gn3OgW7DQc4x07exZ4DX4XyaGDq5LoEmk/BdCM
# 1IelVMKB3WA6YpZ/XYdJ9JueOXeQObSQ/dohQCGyh0FhmwkDWKZaqQBWrBwZ++zq
# lt+z/QYTgEnZo6dyIo2IhXXANFkCHutL8765NBxvolXMFWY8/reTnFxk3MajgM5N
# X6wzWdWsPJxYRhLxtJLSUJJ5yWRNw+NBqH1ezvFs4GgJ2ZqFJ+Dwqbx9+rw+F2gB
# dgo4j7CVomP49sS7CbqsdybbiOGpB9DJhs5QVMpYV73TVV3IwLiBHBECrTgUfZVO
# MF0KSEq2zk/LsfvehswavE3W4aBXJmGjgWSpcDz+6TqeTM8f1DIcgQPdz0IYgnT3
# yFTgiDbFGOFNt6eCidxdR6j9x+kpcN5RwApy4pRhE10YOV/xafBvKpRuWPjOPWRB
# lKdm53kS2aMh08spx7xSEqXn4QQldCnUWRz3Lki+TgBlpwYwJUbR77DAayNwAANE
# 7taBrz2v+MnnogMrvvct0iwvfIA1W8kp155Lo44SIfqGmrbJP6Mn+Udr3MR2oWoz
# AgMBAAGjggGOMIIBijAfBgNVHSMEGDAWgBRfWO1MMXqiYUKNUoC6s2GXGaIymzAd
# BgNVHQ4EFgQUiGGMoSo3ZIEoYKGbMdCM/SwCzk8wDgYDVR0PAQH/BAQDAgbAMAwG
# A1UdEwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwSgYDVR0gBEMwQTA1
# BgwrBgEEAbIxAQIBAwgwJTAjBggrBgEFBQcCARYXaHR0cHM6Ly9zZWN0aWdvLmNv
# bS9DUFMwCAYGZ4EMAQQCMEoGA1UdHwRDMEEwP6A9oDuGOWh0dHA6Ly9jcmwuc2Vj
# dGlnby5jb20vU2VjdGlnb1B1YmxpY1RpbWVTdGFtcGluZ0NBUjM2LmNybDB6Bggr
# BgEFBQcBAQRuMGwwRQYIKwYBBQUHMAKGOWh0dHA6Ly9jcnQuc2VjdGlnby5jb20v
# U2VjdGlnb1B1YmxpY1RpbWVTdGFtcGluZ0NBUjM2LmNydDAjBggrBgEFBQcwAYYX
# aHR0cDovL29jc3Auc2VjdGlnby5jb20wDQYJKoZIhvcNAQEMBQADggGBAAKBPqSG
# clEh+WWpLj1SiuHlm8xLE0SThI2yLuq+75s11y6SceBchpnKpxWaGtXc8dya1Aq3
# RuW//y3wMThsvT4fSba2AoSWlR67rA4fTYGMIhgzocsids0ct/pHaocLVJSwnTYx
# Y2pE0hPoZAvRebctbsTqENmZHyOVjOFlwN2R3DRweFeNs4uyZN5LRJ5EnVYlcTOq
# 3bl1tI5poru9WaQRWQ4eynXp7Pj0Fz4DKr86HYECRJMWiDjeV0QqAcQMFsIjJtrY
# Tw7mU81qf4FBc4u4swphLeKRNyn9DDrd3HIMJ+CpdhSHEGleeZ5I79YDg3B3A/fm
# VY2GaMik1Vm+FajEMv4/EN2mmHf4zkOuhYZNzVm4NrWJeY4UAriLBOeVYODdA1Gx
# Fr1ycbcUEGlUecc4RCPgYySs4d00NNuicR4a9n7idJlevAJbha/arIYMEuUqTeRR
# bWkhJwMKmb9yEvppRudKyu1t6l21sIuIZqcpVH8oLWCxHS0LpDRF9Y4jijCCBoEw
# ggRpoAMCAQICEAJ8OQEMp1rDOrXuDVQO+eUwDQYJKoZIhvcNAQEMBQAwgYgxCzAJ
# BgNVBAYTAlVTMRMwEQYDVQQIEwpOZXcgSmVyc2V5MRQwEgYDVQQHEwtKZXJzZXkg
# Q2l0eTEeMBwGA1UEChMVVGhlIFVTRVJUUlVTVCBOZXR3b3JrMS4wLAYDVQQDEyVV
# U0VSVHJ1c3QgUlNBIENlcnRpZmljYXRpb24gQXV0aG9yaXR5MB4XDTIxMDMyMjAw
# MDAwMFoXDTM4MDExODIzNTk1OVowVjELMAkGA1UEBhMCR0IxGDAWBgNVBAoTD1Nl
# Y3RpZ28gTGltaXRlZDEtMCsGA1UEAxMkU2VjdGlnbyBQdWJsaWMgQ29kZSBTaWdu
# aW5nIFJvb3QgUjQ2MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAjeeU
# EiIEJHQu/xYjApKKtq42haxH1CORKz7cfeIxoFFvrISR41KKteKW3tCHYySJiv/v
# EpM7fbu2ir29BX8nm2tl06UMabG8STma8W1uquSggyfamg0rUOlLW7O4ZDakfko9
# qXGrYbNzszwLDO/bM1flvjQ345cbXf0fEj2CA3bm+z9m0pQxafptszSswXp43JJQ
# 8mTHqi0Eq8Nq6uAvp6fcbtfo/9ohq0C/ue4NnsbZnpnvxt4fqQx2sycgoda6/YDn
# AdLv64IplXCN/7sVz/7RDzaiLk8ykHRGa0c1E3cFM09jLrgt4b9lpwRrGNhx+swI
# 8m2JmRCxrds+LOSqGLDGBwF1Z95t6WNjHjZ/aYm+qkU+blpfj6Fby50whjDoA7NA
# xg0POM1nqFOI+rgwZfpvx+cdsYN0aT6sxGg7seZnM5q2COCABUhA7vaCZEao9XOw
# BpXybGWfv1VbHJxXGsd4RnxwqpQbghesh+m2yQ6BHEDWFhcp/FycGCvqRfXvvdVn
# TyheBe6QTHrnxvTQ/PrNPjJGEyA2igTqt6oHRpwNkzoJZplYXCmjuQymMDg80EY2
# NXycuu7D1fkKdvp+BRtAypI16dV60bV/AK6pkKrFfwGcELEW/MxuGNxvYv6mUKe4
# e7idFT/+IAx1yCJaE5UZkADpGtXChvHjjuxf9OUCAwEAAaOCARYwggESMB8GA1Ud
# IwQYMBaAFFN5v1qqK0rPVIDh2JvAnfKyA2bLMB0GA1UdDgQWBBQy65Ka/zWWSC8o
# QEJwIDaRXBeF5jAOBgNVHQ8BAf8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zATBgNV
# HSUEDDAKBggrBgEFBQcDAzARBgNVHSAECjAIMAYGBFUdIAAwUAYDVR0fBEkwRzBF
# oEOgQYY/aHR0cDovL2NybC51c2VydHJ1c3QuY29tL1VTRVJUcnVzdFJTQUNlcnRp
# ZmljYXRpb25BdXRob3JpdHkuY3JsMDUGCCsGAQUFBwEBBCkwJzAlBggrBgEFBQcw
# AYYZaHR0cDovL29jc3AudXNlcnRydXN0LmNvbTANBgkqhkiG9w0BAQwFAAOCAgEA
# Xx2BzlL7YfuN0nHhLSOGKoJ5Srj6GhPtbnDrJL6p72v8iwg+AWU+HWCxLdOGBt5v
# oXn/mV3RCnhbHAGaXuBHrKrDwfl+yHx4U40tsjteVcBbRnQeell+x4BcizJmhICf
# TSoxVWjhWW+JiErXHWppUuYg2xVxVBhrSJSHbYMvp4XaT10eEy/s9ekGODxw+/mm
# eSev8/Lg/cKZ8yNYxe3hfuyP3pLwgoi8ObxWFXKr5TlYiPVWZp2LQ4NRwHUwjqj2
# z4Vas0vikX7cfPlRpiQk6VU8TppFu7l23Qwzkhue9mTw1lFOJXB3MJ32kdcyqG+b
# uLr24IoKnvqafm5olutvFqsde++RvS6oltun6AQpnhy6uwGJa7d9ygFtP6KHFlfB
# RdPwUkWOZIqvSB4fwk7frQI14wMMtES7bF8n7xI4is2kFvFtkFNbZSyVV1Zi5nzc
# RpSSxuuUb3UfXKWRNdAfClpXh5uinzVn3GJnUxW4NU6VfAYfRYSXF8To262aUDk2
# mm/YE8cqjszng95qlJh42/vpYOpPYMqdqhDmqmPpnydf8HOIp7bt6gkRUYhEBeZo
# 4a6L4XtEtjWIMIw1o5XLSDtcGddwsKucY8tFu7Yst5B4oMWQRdDLqh5K7RNZN402
# 2GXbepon7IUNLoj/+wtVKf4GTIRr3AHyscXZxNOaEyQwggaCMIIEaqADAgECAhA2
# wrC9fBs656Oz3TbLyXVoMA0GCSqGSIb3DQEBDAUAMIGIMQswCQYDVQQGEwJVUzET
# MBEGA1UECBMKTmV3IEplcnNleTEUMBIGA1UEBxMLSmVyc2V5IENpdHkxHjAcBgNV
# BAoTFVRoZSBVU0VSVFJVU1QgTmV0d29yazEuMCwGA1UEAxMlVVNFUlRydXN0IFJT
# QSBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTAeFw0yMTAzMjIwMDAwMDBaFw0zODAx
# MTgyMzU5NTlaMFcxCzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0
# ZWQxLjAsBgNVBAMTJVNlY3RpZ28gUHVibGljIFRpbWUgU3RhbXBpbmcgUm9vdCBS
# NDYwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQCIndi5RWedHd3ouSaB
# mlRUwHxJBZvMWhUP2ZQQRLRBQIF3FJmp1OR2LMgIU14g0JIlL6VXWKmdbmKGRDIL
# RxEtZdQnOh2qmcxGzjqemIk8et8sE6J+N+Gl1cnZocew8eCAawKLu4TRrCoqCAT8
# uRjDeypoGJrruH/drCio28aqIVEn45NZiZQI7YYBex48eL78lQ0BrHeSmqy1uXe9
# xN04aG0pKG9ki+PC6VEfzutu6Q3IcZZfm00r9YAEp/4aeiLhyaKxLuhKKaAdQjRa
# f/h6U13jQEV1JnUTCm511n5avv4N+jSVwd+Wb8UMOs4netapq5Q/yGyiQOgjsP/J
# RUj0MAT9YrcmXcLgsrAimfWY3MzKm1HCxcquinTqbs1Q0d2VMMQyi9cAgMYC9jKc
# +3mW62/yVl4jnDcw6ULJsBkOkrcPLUwqj7poS0T2+2JMzPP+jZ1h90/QpZnBkhdt
# ixMiWDVgh60KmLmzXiqJc6lGwqoUqpq/1HVHm+Pc2B6+wCy/GwCcjw5rmzajLbmq
# GygEgaj/OLoanEWP6Y52Hflef3XLvYnhEY4kSirMQhtberRvaI+5YsD3XVxHGBjl
# Ili5u+NrLedIxsE88WzKXqZjj9Zi5ybJL2WjeXuOTbswB7XjkZbErg7ebeAQUQiS
# /uRGZ58NHs57ZPUfECcgJC+v2wIDAQABo4IBFjCCARIwHwYDVR0jBBgwFoAUU3m/
# WqorSs9UgOHYm8Cd8rIDZsswHQYDVR0OBBYEFPZ3at0//QET/xahbIICL9AKPRQl
# MA4GA1UdDwEB/wQEAwIBhjAPBgNVHRMBAf8EBTADAQH/MBMGA1UdJQQMMAoGCCsG
# AQUFBwMIMBEGA1UdIAQKMAgwBgYEVR0gADBQBgNVHR8ESTBHMEWgQ6BBhj9odHRw
# Oi8vY3JsLnVzZXJ0cnVzdC5jb20vVVNFUlRydXN0UlNBQ2VydGlmaWNhdGlvbkF1
# dGhvcml0eS5jcmwwNQYIKwYBBQUHAQEEKTAnMCUGCCsGAQUFBzABhhlodHRwOi8v
# b2NzcC51c2VydHJ1c3QuY29tMA0GCSqGSIb3DQEBDAUAA4ICAQAOvmVB7WhEuOWh
# xdQRh+S3OyWM637ayBeR7djxQ8SihTnLf2sABFoB0DFR6JfWS0snf6WDG2gtCGfl
# wVvcYXZJJlFfym1Doi+4PfDP8s0cqlDmdfyGOwMtGGzJ4iImyaz3IBae91g50Qyr
# VbrUoT0mUGQHbRcF57olpfHhQEStz5i6hJvVLFV/ueQ21SM99zG4W2tB1ExGL98i
# dX8ChsTwbD/zIExAopoe3l6JrzJtPxj8V9rocAnLP2C8Q5wXVVZcbw4x4ztXLsGz
# qZIiRh5i111TW7HV1AtsQa6vXy633vCAbAOIaKcLAo/IU7sClyZUk62XD0VUnHD+
# YvVNvIGezjM6CRpcWed/ODiptK+evDKPU2K6synimYBaNH49v9Ih24+eYXNtI38b
# yt5kIvh+8aW88WThRpv8lUJKaPn37+YHYafob9Rg7LyTrSYpyZoBmwRWSE4W6iPj
# B7wJjJpH29308ZkpKKdpkiS9WNsf/eeUtvRrtIEiSJHN899L1P4l6zKVsdrUu1FX
# 1T/ubSrsxrYJD+3f3aKg6yxdbugot06YwGXXiy5UUGZvOu3lXlxA+fC13dQ5OlL2
# gIb5lmF6Ii8+CQOYDwXM+yd9dbmocQsHjcRPsccUd5E9FiswEqORvz8g3s+jR3SF
# CgXhN4wz7NgAnOgpCdUo4uDyllU9PzCCBscwggUvoAMCAQICEDYyMT8E4BUW9QfP
# VZJR6jAwDQYJKoZIhvcNAQELBQAwVzELMAkGA1UEBhMCR0IxGDAWBgNVBAoTD1Nl
# Y3RpZ28gTGltaXRlZDEuMCwGA1UEAxMlU2VjdGlnbyBQdWJsaWMgQ29kZSBTaWdu
# aW5nIENBIEVWIFIzNjAeFw0yNTA3MDcwMDAwMDBaFw0yODA3MDYyMzU5NTlaMIGp
# MRcwFQYDVQQFEw4zOSA2MjAgMjE5IDMwMTETMBEGCysGAQQBgjc8AgEDEwJBVTEd
# MBsGA1UEDxMUUHJpdmF0ZSBPcmdhbml6YXRpb24xCzAJBgNVBAYTAkFVMREwDwYD
# VQQIDAhUYXNtYW5pYTEcMBoGA1UECgwTQ291bmNpbFdpc2UgUHR5IEx0ZDEcMBoG
# A1UEAwwTQ291bmNpbFdpc2UgUHR5IEx0ZDCCAiIwDQYJKoZIhvcNAQEBBQADggIP
# ADCCAgoCggIBAPuByyTya61letB3dExiWvOaqzKsiHPhmUWvhlWeOAyRfxIJ7HDx
# fm+u59MJHdmCSIVJvc9qEfCDUL4Wqo2zSJhHlChDPcDr6B+wvSKdkQA0jQFSa5x3
# BEfgMPcQSQfVQ7KD2skEw9dZ+ZVlr3pvguJcQBWpQ/rRmE5zqCFpUqf7vWcwDi6A
# 2SS/14JDvv2hn4kmXKLEy99m0WMLytmlzMdpYfDPWv5N9QlfuMDVDWtd/fF02Ids
# 3NBg6F39ah12qJJIrI3evUTxaYqKA2LmxJp/pFrSn624Ki1pn2w9yVsjqWsl3KTZ
# Zy/sq+5Uy8ZuPi6z6nSxX/XeE1pDzk76TIEhuCkSxPYMMIaiDR6W27xeKn8Ddl/i
# dzvlTmXJCLwKyjYb4tboYJ5Be6+7hTm9M58a0h9PvMpTWE+yTE1VW0qYsotLAyv2
# QGZ1TJEkhIW2HT+0hg9zpoUxI4PgDT5ttzavcndOwEZgHFVmJ7CS2wYfSbcVieJR
# 8s2grVm+hMcWI3JzJ2BeK3LNG8DkdpbyCMLlsSEX0y0stqeqJ0rcZhOcjBgPKF/w
# rnsxfO5fdK2V2MCOMypTRfjJHr8pqjSMIpXftfcPG3uEmjYEU1ZnR0LguEceFI+v
# qpo2MCxamaLZVHorx/PkH58p0gXa09214gl/GGQGtOkl8Mpg6HEro/ONAgMBAAGj
# ggG6MIIBtjAfBgNVHSMEGDAWgBSBMpJBKyjNRsjEosYqORLsSKk/FDAdBgNVHQ4E
# FgQU5B+wfe1jSt4KacI1PqnEnSj6GoowDgYDVR0PAQH/BAQDAgeAMAwGA1UdEwEB
# /wQCMAAwEwYDVR0lBAwwCgYIKwYBBQUHAwMwSQYDVR0gBEIwQDA1BgwrBgEEAbIx
# AQIBBgEwJTAjBggrBgEFBQcCARYXaHR0cHM6Ly9zZWN0aWdvLmNvbS9DUFMwBwYF
# Z4EMAQMwSwYDVR0fBEQwQjBAoD6gPIY6aHR0cDovL2NybC5zZWN0aWdvLmNvbS9T
# ZWN0aWdvUHVibGljQ29kZVNpZ25pbmdDQUVWUjM2LmNybDB7BggrBgEFBQcBAQRv
# MG0wRgYIKwYBBQUHMAKGOmh0dHA6Ly9jcnQuc2VjdGlnby5jb20vU2VjdGlnb1B1
# YmxpY0NvZGVTaWduaW5nQ0FFVlIzNi5jcnQwIwYIKwYBBQUHMAGGF2h0dHA6Ly9v
# Y3NwLnNlY3RpZ28uY29tMCwGA1UdEQQlMCOgIQYIKwYBBQUHCAOgFTATDBFBVS0z
# OSA2MjAgMjE5IDMwMTANBgkqhkiG9w0BAQsFAAOCAYEAFeZsZ7vUBecUWGkvv9wL
# NI7VY8i/A+or627o9jSZuJknuE+tGa564IFzqVDNt9OCJsbuvxfpKN4zgn6pE862
# M7bb6LmeENTz8Q9CvjlWqbI21Qyt21n+QzTWDyr4tDDpLGMaf458luY9XQRpCd57
# LrFVRaCRf47rw3qcg6PWvoWjL5Qyz/Y3yuDMtOJAsjRWH0n2kZ1T3yNNgz/J6p/a
# Rac4vXYAbQPXCwgidofiIaBwrk9oq7qbg5STRf5OsibN+fJ2CPu7vRgNwRvX4Wz4
# GFzLp1DuQihyfaytIrULpZiWjioxxGrxGewS4KwFjSqUGLV3NTLQ/t2v9FAuTwzi
# DKjfBdStdXIP91xJ/ULhv9tcg7vvMX+TTpcSBG+XUMFe+1bpSIFlOj/JqrLEClde
# kSsgf6Mw4zmjp4rXVrrxrpRSTxzD8oT5VdRymYSV6sJIGPerGDrq+wlObLDyKT1i
# tS46vai0ZKaMAwA7asgp7TEUgeuarnqq7YS2XSkLOuIgMYIGKTCCBiUCAQEwazBX
# MQswCQYDVQQGEwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMS4wLAYDVQQD
# EyVTZWN0aWdvIFB1YmxpYyBDb2RlIFNpZ25pbmcgQ0EgRVYgUjM2AhA2MjE/BOAV
# FvUHz1WSUeowMA0GCWCGSAFlAwQCAQUAoGowGQYJKoZIhvcNAQkDMQwGCisGAQQB
# gjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkE
# MSIEIBU0KpAfd/cgvKcYsay8N/SZswwqkOUJcyi6IBS6aBhaMA0GCSqGSIb3DQEB
# AQUABIICAOvGYZoxo8Dm0LHQZfwMHKdxCwH8HQuttT0v2wXYcBTwOEKGPyXatlod
# xyaUN7Mgs6z/467lBXWVuktgqFbLXL/sF/FuMgvHLX8mTgaD7U1SVqPnqPEWOA6u
# CiK+zoNISSTKy4VldSKTvtnOazlyVsKjgfipJxmRbhglhibccgpvB3+/Ia4ABMYN
# VjJfn5Lf64iTRMJyfsYWKjQN698yAW63qmoOEm+KHvPVBB5mPRLWLVLZ0Ni9ucyL
# Rj97SYHCvCyfn2y2iX9kFAPslg0YaCGU0CxgDkMJAQY7AtQEB1SfYyCNWQF16Xkc
# 5XXvRvgeVHp0/WYzswLBo10dfV9B/Xk6F/nO5iNdnk3YDdgjOOOABY9zLREKnIzL
# GJkyWOMNo7WhYSptEWUr0Vm79a8EgWG6NUbPXMN8o2wy7DI7uCb48RVziVnAy1lw
# azh0PBcHfFzZC+X55hfYv1Z37LrvyMUBWdVJZUbsO0FP+j0he3bO+IE+/58Z2gX8
# hHx0hQTIlJnfImo7+h+vOLowSElJ7bXF6XxBkYxeiDCkuKJfIRzlV7jYqHJi+zMm
# AuQHIrth4m/AMVWkO5GS49EjTXjdGKbZNroFaAjd2qdHAgXxSGAUZeNcePvxyoRM
# 4DJEMLD7URE8qA48wrUjaLZJi5CMLHmdceRl5n+dKEdtljj+CeMfoYIDIzCCAx8G
# CSqGSIb3DQEJBjGCAxAwggMMAgEBMGowVTELMAkGA1UEBhMCR0IxGDAWBgNVBAoT
# D1NlY3RpZ28gTGltaXRlZDEsMCoGA1UEAxMjU2VjdGlnbyBQdWJsaWMgVGltZSBT
# dGFtcGluZyBDQSBSMzYCEQCkKTtuHt3XpzQIh616TrckMA0GCWCGSAFlAwQCAgUA
# oHkwGAYJKoZIhvcNAQkDMQsGCSqGSIb3DQEHATAcBgkqhkiG9w0BCQUxDxcNMjYw
# MTE0MDYxMjMxWjA/BgkqhkiG9w0BCQQxMgQwS0aU+ARy/Mq0Pa0L/fKKqDqT9wDw
# IXqAQua+GyktdyjVhNNQOs/lwGvn72AUsdbOMA0GCSqGSIb3DQEBAQUABIICAGZc
# a+stHv7ZHMNSuiyXvpn5N5gw8/WIWL8s1HZYM0NrkXWWFwK7gcM1RHp3bvpPODFP
# qPrMmUAMMPa1hl8OS3xsjIyGKmrEt+YglqrY1BuR1VXXKbclbp7r5nKo92jiaGIR
# yMLhG4d9C8UJ0/fGtzLAtzgy5j/1/YGt3+n+s2R8Ze4txxW9LGsYmVbcfTCBmc/V
# lcDKKIQ4or4fXdQia8SAl4uM5Hl6k1qsJBBm0uRUbiZucLJjEQfJL3qkTHN6nrdf
# ABS5W+hxSmydL/jw8wKcHbt/egixERjAzMeT6qCIQU360gKNN198ksoU67mYnt6f
# Nii0ipOERDMaYqt6Ep6SP0tStMfXu4u6tqSVl/rEHndkW5sIW7x3AkTBHiSTDyEE
# zY03mtu4PO6nyZGYzdpEQznGkd95nIDPsar3jNTskiqE1eFjN1aO0YxZ4G7geqTh
# QuWfhepLIzryhjpNwyAhJ7GiszFHbgwEG+oR+upCkEyFmrhcWi8Xkh8wLBgePTqJ
# usUH+SoJia/6Tnl8a537RNd+IYk/clVe3R8YTbl+6huerGbX/cUKPERyJjnWH/Td
# ZsJATuGeBmWNYOjx9cTrqMKUE90yKNkpbkp6P04mOvIfDYZ49ZL6rrbrvQYIE/zc
# MYuGZgwiQ55ZQdUBWki1FbepZccRDGCdaZwNheNL
# SIG # End signature block
