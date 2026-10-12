"""Replace the prologue voices with neural speech, saved as 16-bit wav."""
import asyncio
from pathlib import Path

import edge_tts
import miniaudio
import wave

OUT = Path(r"D:\Users\TEMP\Desktop\sideproj\Dreamweaver\assets\audio\voice")
NARRATOR = "en-US-GuyNeural"
SLANG = "en-US-JennyNeural"
FUN = "en-US-AriaNeural"

LINES = [
	("prologue_1a", NARRATOR, "-10%", "Long ago, our world was a living tapestry."),
	("prologue_1b", NARRATOR, "-10%", "Every thread held a story. The deep blacks, the bright reds, and the shining golds were signs of life and heritage."),
	("prologue_2a", NARRATOR, "-10%", "The spirits blessed our weavers with sacred dreams, called damgo."),
	("prologue_2b", NARRATOR, "-10%", "Those dreams guided their hands to create the Tuh-nah-lahk cloth."),
	("prologue_2c", NARRATOR, "-10%", "We were the guardians of these colors, keeping our culture alive through every stitch."),
	("prologue_3a", NARRATOR, "-14%", "But a shadow crept in. The Shadow of Forgetfulness."),
	("prologue_3b", NARRATOR, "-10%", "We neglected our traditions, and the spirits grew silent."),
	("prologue_3c", NARRATOR, "-12%", "The colors fled. Our world unraveled into gray."),
	("prologue_4a", SLANG, "+4%", "The colors are gone. The loom is silent. How can I weave a dream, when the world itself has unraveled?"),
	("prologue_4b", FUN, "-6%", "The bleaching has taken everyone, Sah-lang. But the rhythm still beats in you."),
	("prologue_4c", FUN, "-6%", "Enter the ancestral houses. Gather the lost essences. And weave the colors back to life."),
]


async def speak(name: str, voice: str, rate: str, text: str) -> None:
	mp3 = OUT / f"{name}.mp3"
	wav_path = OUT / f"{name}.wav"
	await edge_tts.Communicate(text, voice, rate=rate).save(str(mp3))
	decoded = miniaudio.decode_file(str(mp3), output_format=miniaudio.SampleFormat.SIGNED16)
	samples = decoded.samples
	raw = samples.tobytes() if hasattr(samples, "tobytes") else bytes(samples)
	with wave.open(str(wav_path), "wb") as handle:
		handle.setnchannels(decoded.nchannels)
		handle.setsampwidth(2)
		handle.setframerate(decoded.sample_rate)
		handle.writeframes(raw)
	mp3.unlink(missing_ok=True)
	print(name, decoded.sample_rate, decoded.nchannels, wav_path.stat().st_size)


async def main() -> None:
	for name, voice, rate, text in LINES:
		await speak(name, voice, rate, text)


if __name__ == "__main__":
	asyncio.run(main())
