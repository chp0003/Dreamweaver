Add-Type -AssemblyName System.Speech
$out = "D:\Users\TEMP\Desktop\sideproj\Dreamweaver\assets\audio\voice"
New-Item -ItemType Directory -Force -Path $out | Out-Null

function Speak-Line($name, $voice, $rate, $text) {
	$synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
	$synth.SelectVoice($voice)
	$synth.Rate = $rate
	$path = Join-Path $out ($name + ".wav")
	$synth.SetOutputToWaveFile($path)
	$synth.Speak($text)
	$synth.Dispose()
	Write-Output $path
}

$narrator = "Microsoft David Desktop"
$slang = "Microsoft Zira Desktop"
$fun = "Microsoft Zira Desktop"

Speak-Line "prologue_1a" $narrator -2 "Long ago, our world was a living tapestry."
Speak-Line "prologue_1b" $narrator -2 "Every thread held a story. The deep blacks, the bright reds, and the shining golds were signs of life and heritage."
Speak-Line "prologue_2a" $narrator -2 "The spirits blessed our weavers with sacred dreams, called damgo."
Speak-Line "prologue_2b" $narrator -2 "Those dreams guided their hands to create the Tuh-nah-lahk cloth."
Speak-Line "prologue_2c" $narrator -2 "We were the guardians of these colors, keeping our culture alive through every stitch."
Speak-Line "prologue_3a" $narrator -3 "But a shadow crept in. The Shadow of Forgetfulness."
Speak-Line "prologue_3b" $narrator -2 "We neglected our traditions, and the spirits grew silent."
Speak-Line "prologue_3c" $narrator -2 "The colors fled. Our world unraveled into gray."
Speak-Line "prologue_4a" $slang 0 "The colors are gone. The loom is silent. How can I weave a dream, when the world itself has unraveled?"
Speak-Line "prologue_4b" $fun -3 "The bleaching has taken everyone, Sah-lang. But the rhythm still beats in you."
Speak-Line "prologue_4c" $fun -3 "Enter the ancestral houses. Gather the lost essences. And weave the colors back to life."
