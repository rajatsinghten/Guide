param(
    [switch]$SkipDockerCheck
)

$ErrorActionPreference = "Stop"
$RootDir = Split-Path -Parent $PSScriptRoot

function Fail([string]$Message) {
    Write-Error $Message
    exit 1
}

function Has-Command([string]$Name) {
    return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

if (-not (Has-Command "python")) {
    Fail "Python not found. Install Python 3.11+ first."
}
if (-not (Has-Command "node")) {
    Fail "Node.js not found. Install Node 20+ first."
}
if (-not (Has-Command "npm")) {
    Fail "npm not found. Install npm first."
}

python -c "import sys; assert sys.version_info >= (3, 11), 'Python 3.11+ is required'; print(f'Python {sys.version.split()[0]}')"
Write-Host "Node $(node -v)"
Write-Host "npm $(npm -v)"

if (-not (Test-Path "$RootDir/server/requirements.txt")) {
    Fail "Missing server/requirements.txt"
}
if (-not (Test-Path "$RootDir/client/package.json")) {
    Fail "Missing client/package.json"
}
if (-not (Test-Path "$RootDir/notebooks/xg_bost.pkl")) {
    Fail "Missing notebooks/xg_bost.pkl model artifact"
}
if (-not (Test-Path "$RootDir/data/processed/gigshield_training_ready.csv")) {
    Fail "Missing data/processed/gigshield_training_ready.csv reference dataset"
}

if ($SkipDockerCheck) {
    Write-Host "Docker preflight skipped (-SkipDockerCheck)."
} else {
    if (Has-Command "docker") {
        $dockerReady = $true
        try {
            docker info *> $null
        } catch {
            $dockerReady = $false
        }

        if ($dockerReady) {
            try {
                docker compose version *> $null
                Write-Host "Docker daemon and docker compose are available."
            } catch {
                Fail "docker compose is not available. Install Docker Compose plugin."
            }
        } else {
            Write-Warning "Docker installed but daemon is not running. Optional DB check will be skipped."
        }
    } else {
        Write-Warning "Docker is not installed. Optional DB check will be skipped."
    }
}

Write-Host "Preflight checks passed."
