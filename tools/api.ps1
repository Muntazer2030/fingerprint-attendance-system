# Helper for poking the terminal API from PowerShell.
#
# Windows curl.exe mangles inline JSON quoting, so this uses Invoke-RestMethod
# which takes real objects instead.
#
# Usage:
#   . .\tools\api.ps1 -Ip 192.168.137.245 -Token <device token>
#   Get-Info
#   New-Employee 1
#   Start-Enroll 1 0
#   Watch-Enroll

param(
    [string]$Ip    = $env:ATT_IP,
    [string]$Token = $env:ATT_TOKEN
)

if (-not $Ip)    { throw "Pass -Ip or set ATT_IP" }
if (-not $Token) { throw "Pass -Token or set ATT_TOKEN" }

$script:Base = "http://$Ip/api/v1"
$script:Hdr  = @{ Authorization = "Bearer $Token" }

Write-Host "targeting $script:Base" -ForegroundColor Cyan

function Invoke-Api {
    param([string]$Path, [string]$Method = "GET", $Body = $null)
    $args = @{ Uri = "$script:Base$Path"; Method = $Method; Headers = $script:Hdr }
    if ($null -ne $Body) {
        $args.Body = ($Body | ConvertTo-Json -Compress)
        $args.ContentType = "application/json"
    }
    Invoke-RestMethod @args
}

function Get-Info    { Invoke-Api "/info" }
function Get-Health  { Invoke-Api "/health" }
function Get-Users   { Invoke-Api "/users" }

function Get-Events {
    param([int]$Since = 0)
    Invoke-Api "/events?since=$Since"
}

function Send-Ack {
    param([Parameter(Mandatory)][int]$Through)
    Invoke-Api "/events/ack" -Method POST -Body @{ through_seq = $Through }
}

function Sync-DeviceTime {
    $now = [int][double]::Parse((Get-Date -UFormat %s))
    Invoke-Api "/time" -Method POST -Body @{ epoch = $now }
}

function New-Employee {
    param([Parameter(Mandatory)][int]$Id, [bool]$Active = $true)
    Invoke-Api "/users" -Method POST -Body @{ employee_id = $Id; active = $Active }
}

function Remove-Employee {
    param([Parameter(Mandatory)][int]$Id)
    Invoke-Api "/users?employee_id=$Id" -Method DELETE
}

function Start-Enroll {
    param([Parameter(Mandatory)][int]$Id, [int]$Finger = 0)
    Invoke-Api "/enroll/start" -Method POST -Body @{ employee_id = $Id; finger = $Finger }
}

function Get-Enroll  { Invoke-Api "/enroll" }

function Stop-Enroll {
    param([Parameter(Mandatory)][long]$Session)
    Invoke-Api "/enroll/cancel?session_id=$Session" -Method POST
}

# Follows an enrolment to completion, echoing each state change.
function Watch-Enroll {
    param([int]$TimeoutSec = 60)
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    $last = ""
    while ((Get-Date) -lt $deadline) {
        $s = Get-Enroll
        if ($s.state -ne $last) {
            $last = $s.state
            $msg = "  state: $($s.state)"
            if ($s.slot)   { $msg += "  slot=$($s.slot)" }
            if ($s.reason) { $msg += "  reason=$($s.reason)" }
            Write-Host $msg -ForegroundColor Yellow
        }
        if ($s.state -eq "stored" -or $s.state -eq "failed") { return $s }
        Start-Sleep -Milliseconds 400
    }
    Write-Host "  timed out" -ForegroundColor Red
}

Write-Host "commands: Get-Info Get-Health Get-Users Get-Events Send-Ack Sync-DeviceTime"
Write-Host "          New-Employee Remove-Employee Start-Enroll Get-Enroll Watch-Enroll Stop-Enroll"
