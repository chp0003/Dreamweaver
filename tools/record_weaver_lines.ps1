# Records the Shadow Weaver's raw lines with the Windows speech engine.
#   powershell -ExecutionPolicy Bypass -File tools/record_weaver_lines.ps1
# Then run tools/make_weaver_voice.py to turn them into the demon voice.

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Speech

$lines = [ordered]@{
    "intro_1"      = "So. The little weaver comes to the loom, at last."
    "intro_2"      = "I am what is left, when nobody remembers. I have swallowed a thousand forgotten names."
    "intro_3"      = "Your village. Your ancestors. Your colour. All of it, is mine."
    "intro_4"      = "Then come, child. And be forgotten."
    "phase_2"      = "Enough! You will drown in the dark!"
    "phase_3"      = "No! I will not fade! I will not be forgotten!"
    "taunt_summon" = "Rise, my children."
    "taunt_blind"  = "See nothing."
    "taunt_nova"   = "Kneel!"
    "taunt_hit"    = "Too slow."
    "defeat"       = "Remember... me."
    "laugh_1"      = "Hah! Hah! Hah! Hah!"
    "laugh_2"      = "Heh heh heh heh heh."
}

$outDir = Join-Path $PSScriptRoot "..\assets\audio\_src\voice"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
if (-not (Test-Path (Join-Path $outDir ".gdignore"))) {
    New-Item -ItemType File -Path (Join-Path $outDir ".gdignore") | Out-Null
}

$format = New-Object System.Speech.AudioFormat.SpeechAudioFormatInfo(22050, [System.Speech.AudioFormat.AudioBitsPerSample]::Sixteen, [System.Speech.AudioFormat.AudioChannel]::Mono)
$synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
$synth.SelectVoice("Microsoft David Desktop")

foreach ($key in $lines.Keys) {
    $text = [System.Security.SecurityElement]::Escape($lines[$key])
    $ssml = "<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='en-US'>" +
            "<prosody rate='-10%' pitch='x-low'>$text</prosody></speak>"
    $path = Join-Path $outDir "$key.wav"
    $synth.SetOutputToWaveFile($path, $format)
    $synth.SpeakSsml($ssml)
    $synth.SetOutputToNull()
    Write-Output "recorded $key"
}
$synth.Dispose()
