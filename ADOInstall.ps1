# Script: Install-AdoAgent.ps1
# Description: Install and configure Azure DevOps agent on Windows VM

# ------------------------ VARIABLES ------------------------
$organizationUrl = "https://dev.azure.com/YourOrgName"
$projectName = "YourProjectName"
$agentPool = "YourAgentPoolName"
$agentName = "$env:COMPUTERNAME-Agent"
$personalAccessToken = "YOUR_PAT_HERE"  # Use a secure method in production
$installDir = "C:\ado-agent"
$agentZip = "agent.zip"

# ------------------------ STEP 1: PREREQUISITES ------------------------
Write-Host "Step 1: Checking for prerequisites..."

# Ensure .NET Framework is available (needed by ADO agent)
if (-not (Get-WindowsFeature -Name NET-Framework-Core)) {
    Write-Host "Installing .NET Framework..."
    Install-WindowsFeature -Name NET-Framework-Core -IncludeAllSubFeature
} else {
    Write-Host "✅ .NET Framework already installed"
}

# Ensure PowerShell can make HTTPS calls
try {
    $null = Invoke-WebRequest -Uri "https://www.bing.com" -UseBasicParsing
    Write-Host "✅ Internet connectivity confirmed"
} catch {
    Write-Error "❌ Internet connection failed. Exiting."
    exit 1
}

# ------------------------ STEP 2: CREATE INSTALL DIR ------------------------
Write-Host "Step 2: Preparing installation directory..."
if (-Not (Test-Path -Path $installDir)) {
    New-Item -ItemType Directory -Path $installDir | Out-Null
    Write-Host "✅ Directory created at $installDir"
} else {
    Write-Host "📁 Directory already exists at $installDir"
}

Set-Location $installDir

# ------------------------ STEP 3: DOWNLOAD ADO AGENT ------------------------
Write-Host "Step 3: Downloading Azure DevOps agent..."

# Get latest agent package URL
$agentDownloadUrl = "https://vstsagentpackage.azureedge.net/agent/3.229.2/vsts-agent-win-x64-3.229.2.zip"
# Always check for latest version: https://github.com/microsoft/azure-pipelines-agent/releases

Invoke-WebRequest -Uri $agentDownloadUrl -OutFile $agentZip -UseBasicParsing
Write-Host "✅ Agent downloaded to $agentZip"

# ------------------------ STEP 4: EXTRACT AGENT ------------------------
Write-Host "Step 4: Extracting agent package..."
Expand-Archive -Path $agentZip -DestinationPath $installDir -Force
Write-Host "✅ Agent extracted"

# ------------------------ STEP 5: CONFIGURE AGENT ------------------------
Write-Host "Step 5: Configuring agent..."

$env:VSTS_AGENT_INPUT_URL = $organizationUrl
$env:VSTS_AGENT_INPUT_AUTH = "pat"
$env:VSTS_AGENT_INPUT_TOKEN = $personalAccessToken
$env:VSTS_AGENT_INPUT_POOL = $agentPool
$env:VSTS_AGENT_INPUT_AGENT = $agentName
$env:VSTS_AGENT_INPUT_ACCEPTTOS = "Y"

Start-Process -Wait -FilePath ".\config.cmd" -ArgumentList "--unattended --url $organizationUrl --auth pat --token $personalAccessToken --pool $agentPool --agent $agentName --acceptTeeEula --runAsService"

Write-Host "✅ Agent configured successfully"

# ------------------------ STEP 6: INSTALL AS SERVICE ------------------------
Write-Host "Step 6: Installing agent as a service..."
Start-Process -Wait -FilePath ".\svc.sh" -ArgumentList "install"
Start-Process -Wait -FilePath ".\svc.sh" -ArgumentList "start"
Write-Host "✅ Agent service installed and started"

# ------------------------ STEP 7: VERIFY STATUS ------------------------
Write-Host "Step 7: Verifying agent status..."
$service = Get-Service -Name "vstsagent*" -ErrorAction SilentlyContinue
if ($service -and $service.Status -eq "Running") {
    Write-Host "🎉 ADO Agent is running and connected successfully!" -ForegroundColor Green
} else {
    Write-Error "❌ ADO Agent service is not running. Please check the logs."
}

# ------------------------ STEP 8: CLEANUP ------------------------
Write-Host "Cleaning up temporary files..."
Remove-Item $agentZip -Force
Write-Host "✅ Installation complete!"
