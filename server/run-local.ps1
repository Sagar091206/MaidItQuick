param(
    [int]$Port = 8080
)

$ErrorActionPreference = 'Stop'
$serverRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Join-Path $env:USERPROFILE '.m2\repository'
$java = 'C:\Program Files\Microsoft\jdk-21.0.11.10-hotspot\bin\java.exe'

if (-not (Test-Path $java)) {
    throw "Java 21 was not found at $java"
}

# Run the already-compiled Spring Boot classes without requiring Maven on PATH.
# Maven/IDE builds remain the normal development path; this helper is for local
# simulator smoke tests on machines where only the JDK is installed.
$jars = Get-ChildItem $repoRoot -Recurse -Filter '*.jar' |
    Where-Object {
        $_.Name -notmatch '(sources|javadoc|tests)\.jar$' -and
        $_.FullName -notmatch '\\org\\apache\\maven\\' -and
        $_.FullName -notmatch '\\org\\flywaydb\\' -and
        $_.FullName -notmatch '\\spring-boot-devtools\\' -and
        $_.FullName -notmatch '\\org\\springframework\\.*\\(3\.3\.5|4\.1\.0|6\.1\.14|6\.3\.4|7\.0\.8)\\' -and
        $_.FullName -notmatch '\\org\\slf4j\\slf4j-api\\1\.7'
    } |
    ForEach-Object FullName
$classpath = @(
    (Join-Path $serverRoot 'target\classes')
    $jars
) -join ';'
# Java argument files treat backslashes as escape characters. Forward slashes
# keep Windows paths with spaces intact when the launcher reads the arg file.
$classpath = $classpath -replace '\\', '/'

$argFile = Join-Path $env:TEMP "maiditquick-server-$PID.args"
@(
    '-cp'
    ('"' + $classpath + '"')
    "-Dserver.port=$Port"
    'com.makeitquick.MakeItQuickApplication'
) | Set-Content -Path $argFile -Encoding ascii

try {
    Push-Location $serverRoot
    & $java "@$argFile"
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}
finally {
    Pop-Location
    Remove-Item $argFile -Force -ErrorAction SilentlyContinue
}
