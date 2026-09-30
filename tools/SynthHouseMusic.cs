using System;
using System.Collections.Generic;
using System.IO;

// Renders the five House music loops and their action stingers.
//
//   Add-Type -Path tools\SynthHouseMusic.cs
//   [SynthHouseMusic]::Run("e:\dreamweaver")
//
// Writes 16-bit stereo WAVs to assets/audio/music and assets/audio/sfx. Every
// recipe is seeded, so re-running produces identical files. Loops are rendered
// twice through their reverbs and delays so the tail of the loop feeds its own
// start: the files wrap without a seam.
//
// Instrument palette follows the T'boli ensemble the Houses are drawn from:
// agung (large bossed gong), kulintang (gong-chime row), dabakan (goblet drum),
// sloli (bamboo flute), bamboo clackers, plus pads and a formant choir.
//
// Written for the C# 5 compiler that ships with Windows PowerShell 5.1.
public static class SynthHouseMusic
{
	public const int SR = 32000;
	const double TAU = Math.PI * 2.0;

	static string _musicDir;
	static string _sfxDir;

	public static void Run(string root)
	{
		_musicDir = Path.Combine(root, "assets", "audio", "music");
		_sfxDir = Path.Combine(root, "assets", "audio", "sfx");
		Directory.CreateDirectory(_musicDir);
		Directory.CreateDirectory(_sfxDir);

		Save(_musicDir, "house1_mourning_pad", Master(House1(), -21.0));
		Save(_musicDir, "house2_hulo_drums", Master(House2(), -17.0));
		Save(_musicDir, "house3_sloli_flute", Master(House3(), -21.0));
		Save(_musicDir, "house4_ancestor_choir", Master(House4(), -20.0));

		St motion;
		St siege = House5(out motion);
		double gain = LoudnessGain(Sum(siege, motion), -15.5);
		Save(_musicDir, "house5_siege_drums", Limit(Scale(siege, gain)));
		Save(_musicDir, "house5_siege_motion", Limit(Scale(motion, gain)));

		Save(_sfxDir, "house2_impact", Peak(Impact(), -1.0));
		Save(_sfxDir, "house3_brass_bell", Peak(BrassBell(), -1.0));
		Save(_sfxDir, "house5_brass_shockwave", Peak(BrassShockwave(), -0.8));
	}

	// ======================================================================
	// House 1 — Black Foundation. Low, melancholy ambient pad.
	// D minor, four chords of ten seconds, no pulse. Sparse, mellow bells
	// fall into a long room; a low wind moves underneath.
	// ======================================================================
	static St House1()
	{
		var rng = new Random(101);
		double chordLen = 10.0;
		int n = Sec(chordLen * 4);
		var mix = new St(n);

		int[][] chords = {
			new[] { 50, 57, 64, 65 },   // Dm(add9)
			new[] { 46, 53, 57, 62 },   // Bbmaj7
			new[] { 43, 50, 58, 65 },   // Gm7
			new[] { 45, 52, 55, 62 },   // A7sus4 — never resolves
		};
		for (int c = 0; c < chords.Length; c++)
		{
			double at = c * chordLen;
			foreach (int m in chords[c])
			{
				var pad = Pad(Midi(m), chordLen + 0.6, 3.2, 3.6, 6, 9.0, 620.0, 0.35, 0.8, rng);
				mix.MixSt(pad, at - 0.3, 0.16, true);
			}
			var bass = Pad(Midi(chords[c][0] - 12), chordLen + 0.6, 2.6, 3.4, 3, 4.0, 260.0, 0.15, 0.7, rng);
			mix.MixSt(bass, at - 0.3, 0.26, true);
		}

		mix.Mix(Drone(73.42, n, 0.0), 0, 0.10, 0.0, true);
		mix.Mix(Drone(36.71, n, 0.0), 0, 0.12, 0.0, true);

		// Mellow bells: a phrase that sinks a step at a time.
		double[][] bells = {
			new[] { 1.5, 69 }, new[] { 4.2, 65 }, new[] { 6.8, 64 },
			new[] { 11.8, 74 }, new[] { 14.0, 72 }, new[] { 16.4, 69 },
			new[] { 21.6, 65 }, new[] { 24.0, 67 }, new[] { 26.9, 64 },
			new[] { 31.5, 69 }, new[] { 33.8, 62 }, new[] { 36.6, 64 },
		};
		for (int i = 0; i < bells.Length; i++)
		{
			double f = Midi(bells[i][1]);
			var tone = Partials(f, 6.0, new[] { 1.0, 2.0, 3.0, 4.2 }, new[] { 1.0, 0.22, 0.07, 0.03 },
				new[] { 0.55, 1.1, 1.9, 3.2 }, 0.012, 0.0, rng);
			mix.Mix(tone, bells[i][0], 0.075, (i % 3 - 1) * 0.45, true);
		}

		// Low wind through the loom house.
		var wind = new float[n];
		var wf = new Svf();
		for (int i = 0; i < n; i++)
		{
			double t = (double)i / SR;
			double swell = 0.55 + 0.45 * Math.Sin(TAU * t * 2.0 / (n / (double)SR) - 1.2);
			wf.Process(rng.NextDouble() * 2.0 - 1.0, 320.0 + 140.0 * swell, 0.9);
			wind[i] = (float)(wf.Lp * swell);
		}
		mix.Mix(wind, 0, 0.09, -0.2, true);

		return ReverbLoop(mix, 0.9, 0.45, 0.5, 0.045);
	}

	// ======================================================================
	// House 2 — Red Courage. Faster ethnic drums.
	// 120 BPM, 16 bars in A: agung, war drum, dabakan, bamboo and shaker
	// under a kulintang ostinato. The drone pumps under the war drum.
	// ======================================================================
	static St House2()
	{
		var rng = new Random(202);
		double beat = 60.0 / 120.0;
		double step = beat / 4.0;
		int bars = 16;
		int n = Sec(bars * 4 * beat);
		var drums = new St(n);
		var tonal = new St(n);
		var kicks = new List<double>();

		int[] kul = { 69, 72, 74, 76, 79, 81 };
		int[] phraseA = { 0, 2, 1, 2, 3, 2, 1, 0, 0, 2, 1, 2, 4, 3, 2, -1 };
		int[] phraseB = { 5, 4, 3, 2, 3, 2, 1, 2, 5, 4, 3, 4, 2, 1, 0, -1 };

		for (int bar = 0; bar < bars; bar++)
		{
			double bt = bar * 4 * beat;
			bool fill = bar % 8 == 7;

			if (bar % 2 == 0)
			{
				double f = bar % 4 == 0 ? 55.0 : 82.41;
				drums.Mix(Agung(f, 4.5, rng), bt, 0.55, 0.0, true);
			}

			int[] war = fill ? new[] { 0, 7, 8 } : new[] { 0, 7, 8, 11 };
			foreach (int s in war)
			{
				double at = bt + s * step + Jit(rng);
				kicks.Add(at);
				drums.Mix(WarDrum(rng, s % 8 == 0 ? 1.0 : 0.8), at, s % 8 == 0 ? 0.9 : 0.62, 0.0, true);
			}

			foreach (int s in new[] { 0, 3, 6, 10, 12 })
				drums.Mix(Dabakan(rng, false), bt + s * step + Jit(rng), 0.42 * Vel(rng), 0.18, true);
			foreach (int s in new[] { 4, 14 })
				drums.Mix(Dabakan(rng, true), bt + s * step + Jit(rng), 0.5 * Vel(rng), 0.18, true);
			foreach (int s in new[] { 2, 9, 13, 15 })
				drums.Mix(Dabakan(rng, false), bt + s * step + Jit(rng), 0.16 * Vel(rng), 0.25, true);

			if (bar >= 4)
				foreach (int s in new[] { 2, 6, 10, 14 })
					drums.Mix(Clack(rng), bt + s * step + Jit(rng), 0.24 * Vel(rng), -0.45, true);
			if (bar >= 2)
				for (int s = 0; s < 16; s++)
					drums.Mix(Shaker(rng), bt + s * step + Jit(rng), (s % 2 == 1 ? 0.2 : 0.11) * Vel(rng), 0.5, true);

			if (fill)
			{
				double[] toms = { 196.0, 165.0, 139.0, 110.0 };
				for (int k = 0; k < 4; k++)
					drums.Mix(Tom(rng, toms[k]), bt + (12 + k) * step, 0.5 + k * 0.08, 0.3 - k * 0.2, true);
			}

			int[] phrase = bar >= 8 ? phraseB : phraseA;
			int half = (bar % 2) * 8;
			for (int e = 0; e < 8; e++)
			{
				int idx = phrase[half + e];
				if (idx < 0) continue;
				double at = bt + e * 2 * step + Jit(rng);
				tonal.Mix(Kulintang(Midi(kul[idx]), rng), at, 0.2 * Vel(rng), -0.25, true);
				if (e == 3 || e == 7)
					tonal.Mix(Kulintang(Midi(kul[idx]), rng), at + step, 0.12, -0.25, true);
			}
		}

		var drone = new St(n);
		double seg = n / (double)SR / 4.0;
		for (int k = 0; k < 4; k++)
		{
			drone.MixSt(Pad(110.0, seg + 1.0, 1.0, 1.5, 4, 7.0, 380.0, 0.2, 0.9, rng), k * seg - 0.5, 0.22, true);
			drone.MixSt(Pad(164.81, seg + 1.0, 1.0, 1.5, 4, 7.0, 420.0, 0.2, 0.9, rng), k * seg - 0.5, 0.12, true);
		}
		Duck(drone, kicks, 0.28, 0.4);

		var mix = Sum(drums, Sum(tonal, drone));
		return ReverbLoop(mix, 0.78, 0.5, 0.22, 0.02);
	}

	// ======================================================================
	// House 3 — Golden Sun. Ethereal flute.
	// 80 BPM, 16 bars in D major pentatonic. A sloli line with a dotted
	// echo floats over a glassy pad and soft kulintang glints.
	// ======================================================================
	static St House3()
	{
		var rng = new Random(303);
		double beat = 60.0 / 80.0;
		int bars = 16;
		int n = Sec(bars * 4 * beat);
		var mix = new St(n);

		int[][] chords = {
			new[] { 50, 57, 64, 66, 73 },   // Dmaj9
			new[] { 47, 54, 57, 62, 64 },   // Bm11
			new[] { 43, 50, 54, 59, 61 },   // Gmaj7#11
			new[] { 45, 52, 54, 59, 62 },   // A6sus
		};
		double chordLen = 16 * beat;
		for (int c = 0; c < chords.Length; c++)
		{
			foreach (int m in chords[c])
			{
				var pad = SoftPad(Midi(m), chordLen + 0.5, 2.6, 3.0, rng);
				mix.MixSt(pad, c * chordLen - 0.25, 0.12, true);
			}
		}

		var line = new List<Note>();
		// Phrase A
		Add(line, 1.0, 1.5, 74); Add(line, 2.5, 0.5, 76); Add(line, 3.0, 2.0, 78); Add(line, 5.0, 1.0, 81);
		Add(line, 6.0, 1.0, 78); Add(line, 7.0, 3.5, 76);
		Add(line, 12.0, 0.5, 78); Add(line, 12.5, 0.5, 81); Add(line, 13.0, 2.0, 83); Add(line, 15.0, 1.0, 81);
		// Phrase B
		Add(line, 16.0, 3.0, 78); Add(line, 19.0, 1.0, 76); Add(line, 20.0, 1.0, 74); Add(line, 21.0, 1.0, 71);
		Add(line, 22.0, 4.0, 74);
		Add(line, 27.0, 0.5, 76); Add(line, 27.5, 0.5, 78); Add(line, 28.0, 2.0, 81); Add(line, 30.0, 2.0, 78);
		// Phrase C — the line climbs toward the sun.
		Add(line, 32.0, 2.0, 83); Add(line, 34.0, 1.0, 86); Add(line, 35.0, 1.0, 83); Add(line, 36.0, 2.0, 81);
		Add(line, 38.0, 0.5, 78); Add(line, 38.5, 0.5, 81); Add(line, 39.0, 3.0, 83);
		Add(line, 43.0, 1.0, 81); Add(line, 44.0, 1.0, 78); Add(line, 45.0, 3.0, 76);
		// Phrase D — home.
		Add(line, 48.0, 1.5, 74); Add(line, 49.5, 0.5, 76); Add(line, 50.0, 2.0, 78); Add(line, 52.0, 2.0, 76);
		Add(line, 54.0, 4.0, 74);
		Add(line, 59.0, 0.5, 69); Add(line, 59.5, 0.5, 71); Add(line, 60.0, 3.0, 74);

		var flute = new St(n);
		foreach (var note in Flute(line, beat, rng))
			flute.Mix(note.Samples, note.At, 0.3, -0.1, true);
		DelayLoop(flute, beat * 0.75, 0.42, 0.34, 2600.0);
		mix.MixSt(flute, 0, 1.0, true);

		// Kulintang glints on each chord change.
		int[] glint = { 86, 83, 81, 78 };
		for (int c = 0; c < 4; c++)
		{
			double at = c * chordLen + 2 * beat;
			mix.Mix(Kulintang(Midi(glint[c]), rng), at, 0.06, 0.55, true);
			mix.Mix(Kulintang(Midi(glint[c] - 5), rng), at + beat * 1.5, 0.045, -0.55, true);
		}

		// Breath of air in the rafters.
		var air = new float[n];
		var af = new Svf();
		for (int i = 0; i < n; i++)
		{
			af.Process(rng.NextDouble() * 2.0 - 1.0, 2400.0, 0.6);
			double t = (double)i / SR;
			air[i] = (float)(af.Bp * (0.6 + 0.4 * Math.Sin(TAU * t / (n / (double)SR) * 3.0)));
		}
		mix.Mix(air, 0, 0.018, 0.3, true);

		return ReverbLoop(mix, 0.9, 0.3, 0.46, 0.06);
	}

	// ======================================================================
	// House 4 — Dream Ancestors. Choral vocal pad.
	// Four-part formant choir in C minor, twelve seconds a chord, closing on
	// a suspended fourth. A soprano hums a line in the second half; a distant
	// agung marks the halves. Cathedral-length room.
	// ======================================================================
	static St House4()
	{
		var rng = new Random(404);
		double chordLen = 12.0;
		int n = Sec(chordLen * 4);
		var mix = new St(n);

		int[][] chords = {
			new[] { 48, 55, 63, 67 },   // Cm
			new[] { 44, 56, 60, 63 },   // Ab
			new[] { 41, 53, 60, 68 },   // Fm
			new[] { 43, 50, 60, 67 },   // Gsus4
		};
		for (int c = 0; c < chords.Length; c++)
		{
			for (int p = 0; p < 4; p++)
			{
				bool female = p >= 2;
				int[] vowels = p == 0 ? new[] { 2, 1, 2 } : (p == 3 ? new[] { 1, 0, 1 } : new[] { 2, 0, 1 });
				var part = ChoirPart(Midi(chords[c][p]), chordLen + 0.8, 3.0, 3.8, female, 4, vowels, rng);
				double level = p == 0 ? 0.3 : (p == 3 ? 0.2 : 0.24);
				mix.MixSt(part, c * chordLen - 0.4, level, true);
			}
		}

		// Humming soprano over the Fm and Gsus4.
		double[][] hum = {
			new[] { 24.5, 3.5, 72 }, new[] { 28.0, 2.5, 70 }, new[] { 30.5, 3.5, 68 },
			new[] { 36.5, 3.0, 67 }, new[] { 39.5, 2.5, 65 }, new[] { 42.0, 5.0, 67 },
		};
		foreach (var h in hum)
		{
			var voice = ChoirPart(Midi(h[2]), h[1], 0.9, 1.6, true, 2, new[] { 2, 1 }, rng);
			mix.MixSt(voice, h[0], 0.16, true);
		}

		mix.Mix(Drone(65.41, n, 0.25), 0, 0.12, 0.0, true);
		mix.Mix(Drone(32.70, n, 0.0), 0, 0.1, 0.0, true);
		mix.Mix(Agung(65.41, 8.0, rng), 0.0, 0.2, -0.3, true);
		mix.Mix(Agung(87.31, 8.0, rng), chordLen * 2, 0.16, 0.3, true);

		return ReverbLoop(mix, 0.94, 0.4, 0.58, 0.07);
	}

	// ======================================================================
	// House 5 — Sacred Loom. Aggressive ethnic combat drums.
	// 150 BPM, 32 bars in D phrygian. `motion` is a second stem of the same
	// length — tom runs, shakers, clacks and a tremolo — that the game fades
	// in while S'lang is moving and fighting.
	// ======================================================================
	static St House5(out St motion)
	{
		var rng = new Random(505);
		double beat = 60.0 / 150.0;
		double step = beat / 4.0;
		int bars = 32;
		int n = Sec(bars * 4 * beat);
		var drums = new St(n);
		var tonal = new St(n);
		motion = new St(n);
		var kicks = new List<double>();

		int[] kul = { 62, 63, 65, 69, 70, 74 };
		int[] ostA = { 0, 0, 3, 0, 1, 0, 3, 4, 0, 0, 3, 0, 5, 4, 3, 1 };
		int[] ostB = { 5, 4, 3, 4, 1, 0, 1, 3, 5, 4, 3, 4, 5, 4, 1, 0 };

		for (int bar = 0; bar < bars; bar++)
		{
			double bt = bar * 4 * beat;
			bool sectionB = bar >= 16;
			bool fill = bar % 4 == 3;

			if (bar % 4 == 0)
				drums.Mix(Agung(bar % 8 == 0 ? 73.42 : 77.78, 3.5, rng), bt, 0.62, 0.0, true);

			int[] war = sectionB ? new[] { 0, 3, 6, 8, 10, 11, 14, 15 } : new[] { 0, 3, 6, 8, 10, 11, 14 };
			if (fill) war = new[] { 0, 3, 6, 8 };
			foreach (int s in war)
			{
				double at = bt + s * step + Jit(rng) * 0.6;
				bool accent = s == 0 || s == 8;
				if (accent) kicks.Add(at);
				drums.Mix(WarDrum(rng, accent ? 1.1 : 0.85), at, accent ? 1.0 : 0.66, 0.0, true);
			}

			for (int s = 0; s < 16; s++)
			{
				bool slap = s == 2 || s == 10;
				double v = s % 4 == 0 ? 0.42 : (slap ? 0.46 : 0.2);
				drums.Mix(Dabakan(rng, slap), bt + s * step + Jit(rng) * 0.6, v * Vel(rng), 0.2, true);
			}

			if (fill)
			{
				double[] toms = { 220.0, 196.0, 175.0, 147.0, 131.0, 117.0, 98.0, 87.0 };
				for (int k = 0; k < 8; k++)
					drums.Mix(Tom(rng, toms[k]), bt + (8 + k) * step, 0.5 + k * 0.05, 0.5 - k * 0.14, true);
			}

			int[] ost = sectionB && bar % 2 == 1 ? ostB : ostA;
			int lift = sectionB && bar % 4 >= 2 ? 12 : 0;
			for (int s = 0; s < 16; s++)
			{
				double v = (s % 4 == 0 ? 0.2 : 0.13) * Vel(rng);
				tonal.Mix(Kulintang(Midi(kul[ost[s]] + lift), rng), bt + s * step + Jit(rng) * 0.5, v, -0.3, true);
			}

			if (bar % 2 == 0 || bar >= 28)
			{
				int[] stabs = bar >= 28 ? new[] { 0, 6, 12 } : new[] { 0 };
				foreach (int s in stabs)
				{
					double at = bt + s * step;
					tonal.Mix(Brass(Midi(50), 0.34, 5, 14.0, 0.012, 300, 2400, 500, 0.6, rng), at, 0.16, -0.35, true);
					tonal.Mix(Brass(Midi(57), 0.34, 5, 14.0, 0.012, 300, 2400, 500, 0.6, rng), at, 0.13, 0.35, true);
					tonal.Mix(Brass(Midi(51), 0.34, 3, 10.0, 0.012, 300, 1800, 400, 0.6, rng), at, bar >= 28 ? 0.08 : 0.0, 0.0, true);
				}
			}

			// Motion stem.
			for (int s = 0; s < 16; s++)
			{
				double at = bt + s * step + Jit(rng) * 0.5;
				double f = s % 2 == 0 ? 175.0 : 131.0;
				double v = (s % 4 == 2 ? 0.44 : 0.28) * Vel(rng);
				motion.Mix(Tom(rng, f), at, v, s % 2 == 0 ? 0.45 : -0.45, true);
				motion.Mix(Shaker(rng), at, (s % 2 == 1 ? 0.2 : 0.12) * Vel(rng), 0.65, true);
				if (s % 2 == 1)
					motion.Mix(Clack(rng), at, 0.2 * Vel(rng), -0.65, true);
			}
		}

		// Tremolo tension in the motion stem: D5 against Eb5, gated in sixteenths.
		var trem = new float[n];
		double pa = 0, pb = 0;
		var tf = new Svf();
		for (int i = 0; i < n; i++)
		{
			double t = (double)i / SR;
			double fa = Midi(74), fb = Midi(75);
			pa += fa / SR; pb += fb / SR;
			pa -= Math.Floor(pa); pb -= Math.Floor(pb);
			double saw = (2 * pa - 1 - Blep(pa, fa / SR)) + 0.6 * (2 * pb - 1 - Blep(pb, fb / SR));
			double gate = 0.5 - 0.5 * Math.Cos(TAU * ((t / step) % 1.0));
			tf.Process(saw, 1800.0, 0.8);
			trem[i] = (float)(tf.Lp * gate);
		}
		motion.Mix(trem, 0, 0.05, 0.0, true);

		var drone = new St(n);
		double seg = n / (double)SR / 8.0;
		for (int k = 0; k < 8; k++)
		{
			drone.MixSt(Pad(36.71, seg + 0.6, 0.3, 0.8, 4, 10.0, 220.0, 0.15, 1.1, rng), k * seg - 0.3, 0.4, true);
			drone.MixSt(Pad(73.42, seg + 0.6, 0.3, 0.8, 4, 12.0, 300.0, 0.2, 1.1, rng), k * seg - 0.3, 0.2, true);
		}
		for (int i = 0; i < n; i++)
		{
			drone.L[i] = (float)Math.Tanh(drone.L[i] * 3.0) * 0.5f;
			drone.R[i] = (float)Math.Tanh(drone.R[i] * 3.0) * 0.5f;
		}
		Duck(drone, kicks, 0.22, 0.3);
		Duck(tonal, kicks, 0.12, 0.7);

		var mix = Sum(drums, Sum(tonal, drone));
		motion = ReverbLoop(motion, 0.7, 0.5, 0.14, 0.01);
		return ReverbLoop(mix, 0.8, 0.5, 0.2, 0.015);
	}

	// ======================================================================
	// Stingers
	// ======================================================================

	// House 2: sharp impact when S'lang's staff strikes something.
	static St Impact()
	{
		var rng = new Random(2020);
		double dur = 0.9;
		int n = Sec(dur);
		var o = new St(n);
		o.Mix(Drum(360.0, 82.0, 0.018, 0.16, 0.7, 0.0, 1000, 1, 0.01, 3.0, rng), 0, 0.9, 0.0, false);
		o.Mix(NoiseHit(rng, 3400.0, 1.4, 0.0015, 0.014, 0.25), 0, 1.0, -0.1, false);
		o.Mix(NoiseHit(rng, 7000.0, 0.9, 0.0005, 0.004, 0.05), 0, 0.6, 0.1, false);
		o.Mix(Partials(640.0, 0.3, new[] { 1.0, 2.17, 3.4 }, new[] { 1.0, 0.6, 0.3 },
			new[] { 32.0, 45.0, 60.0 }, 0.0008, 0.0, rng), 0.002, 0.35, 0.2, false);
		o.Mix(Dabakan(rng, true), 0.004, 0.55, 0.0, false);
		for (int i = 0; i < n; i++)
		{
			o.L[i] = (float)Math.Tanh(o.L[i] * 1.8);
			o.R[i] = (float)Math.Tanh(o.R[i] * 1.8);
		}
		return ReverbTail(o, 0.55, 0.6, 0.14, 0.4);
	}

	// House 3: a heavy brass bell that echoes down the hall.
	static St BrassBell()
	{
		var rng = new Random(3030);
		double dur = 6.5;
		int n = Sec(dur);
		var o = new St(n);
		double prime = 146.83;
		double[] ratios = { 0.5, 1.0, 1.19, 1.5, 2.0, 2.52, 2.98, 4.07, 5.4, 6.8 };
		double[] amps = { 0.55, 1.0, 0.55, 0.32, 0.75, 0.3, 0.24, 0.14, 0.08, 0.05 };
		double[] decays = { 0.32, 0.55, 0.75, 0.95, 1.05, 1.6, 2.1, 3.0, 4.4, 6.0 };
		var body = Partials(prime, dur, ratios, amps, decays, 0.0015, 0.004, rng);
		var shimmer = Partials(prime * 1.004, dur, ratios, amps, decays, 0.0015, 0.004, rng);
		o.Mix(body, 0, 0.5, -0.25, false);
		o.Mix(shimmer, 0, 0.5, 0.25, false);
		o.Mix(NoiseHit(rng, 2800.0, 2.0, 0.001, 0.02, 0.12), 0, 0.35, 0.0, false);
		o.Mix(Drum(120.0, 70.0, 0.03, 0.25, 0.6, 0.2, 500, 0.8, 0.03, 1.5, rng), 0, 0.35, 0.0, false);

		// Echoes: each return darker and further to the side.
		var echo = new St(n);
		double[] taps = { 0.42, 0.84, 1.26, 1.68 };
		for (int k = 0; k < taps.Length; k++)
		{
			var lp = new Svf();
			var lp2 = new Svf();
			float[] tapL = new float[n], tapR = new float[n];
			double cut = 2600.0 / (k + 1);
			for (int i = 0; i < n; i++)
			{
				lp.Process(o.L[i], cut, 0.7);
				lp2.Process(o.R[i], cut, 0.7);
				tapL[i] = (float)lp.Lp;
				tapR[i] = (float)lp2.Lp;
			}
			double g = 0.5 * Math.Pow(0.62, k);
			bool left = k % 2 == 0;
			echo.Mix(left ? tapL : tapR, taps[k], g, left ? -0.8 : 0.8, false);
		}
		var mix = Sum(o, echo);
		return ReverbTail(mix, 0.88, 0.35, 0.35, 2.5);
	}

	// House 5: a brass shockwave blast layered on every attack.
	static St BrassShockwave()
	{
		var rng = new Random(5050);
		double dur = 2.4;
		int n = Sec(dur);
		var o = new St(n);

		double[] notes = { 73.42, 110.0, 146.83, 155.56 };
		double[] levels = { 0.5, 0.4, 0.32, 0.12 };
		for (int k = 0; k < notes.Length; k++)
		{
			var blast = Brass(notes[k], 1.1, 6, 16.0, 0.01, 220, 3600, 260, 1.2, rng);
			// Fall off the note as the blast spends itself.
			var fallen = PitchFall(blast, 0.25, 1.0);
			o.Mix(fallen, 0, levels[k], (k - 1.5) * 0.35, false);
		}

		o.Mix(Drum(120.0, 30.0, 0.09, 0.55, 1.4, 0.0, 100, 1, 0.01, 2.4, rng), 0, 1.0, 0.0, false);

		// Explosion: noise with a falling low-pass, decorrelated left and right.
		for (int ch = 0; ch < 2; ch++)
		{
			var boom = new float[n];
			var f = new Svf();
			for (int i = 0; i < n; i++)
			{
				double t = (double)i / SR;
				double env = Math.Min(1.0, t / 0.003) * Math.Exp(-t / 0.28);
				double cut = 180.0 + 6500.0 * Math.Exp(-t / 0.12);
				f.Process(rng.NextDouble() * 2.0 - 1.0, cut, 0.9);
				boom[i] = (float)(f.Lp * env);
			}
			o.Mix(boom, 0, 0.7, ch == 0 ? -0.6 : 0.6, false);
		}
		o.Mix(NoiseHit(rng, 5200.0, 0.8, 0.0005, 0.012, 0.08), 0, 0.5, 0.0, false);

		for (int i = 0; i < n; i++)
		{
			o.L[i] = (float)Math.Tanh(o.L[i] * 1.6);
			o.R[i] = (float)Math.Tanh(o.R[i] * 1.6);
		}
		return ReverbTail(o, 0.84, 0.45, 0.28, 1.2);
	}

	// ======================================================================
	// Instruments
	// ======================================================================

	// Detuned polyBLEP saws through a slowly breathing low-pass, spread wide.
	static St Pad(double freq, double dur, double attack, double release, int voices, double cents,
		double cutoff, double lfoDepth, double q, Random rng)
	{
		int n = Sec(dur + release);
		var o = new St(n);
		for (int v = 0; v < voices; v++)
		{
			double spread = voices > 1 ? v / (voices - 1.0) * 2.0 - 1.0 : 0.0;
			double f = freq * Math.Pow(2.0, spread * cents / 1200.0 + (rng.NextDouble() - 0.5) * 0.001);
			double dt = f / SR;
			double ph = rng.NextDouble();
			double lfoPh = rng.NextDouble();
			double lfoRate = 0.05 + rng.NextDouble() * 0.08;
			var flt = new Svf();
			var m = new float[n];
			for (int i = 0; i < n; i++)
			{
				double t = (double)i / SR;
				double saw = 2.0 * ph - 1.0 - Blep(ph, dt);
				ph += dt;
				if (ph >= 1.0) ph -= 1.0;
				double c = cutoff * (1.0 + lfoDepth * Math.Sin(TAU * (lfoPh + lfoRate * t)));
				flt.Process(saw, c, q);
				m[i] = (float)(flt.Lp * Env(t, attack, dur, release));
			}
			o.Mix(m, 0, 1.0 / voices, spread * 0.85, false);
		}
		return o;
	}

	// Glassy pad: sine + triangle with a quiet octave shimmer.
	static St SoftPad(double freq, double dur, double attack, double release, Random rng)
	{
		int n = Sec(dur + release);
		var o = new St(n);
		for (int v = 0; v < 4; v++)
		{
			double spread = v / 3.0 * 2.0 - 1.0;
			double f = freq * Math.Pow(2.0, spread * 6.0 / 1200.0);
			double ph = rng.NextDouble();
			double ph2 = rng.NextDouble();
			double trem = 0.12 + rng.NextDouble() * 0.1;
			var m = new float[n];
			for (int i = 0; i < n; i++)
			{
				double t = (double)i / SR;
				ph += f / SR; ph -= Math.Floor(ph);
				ph2 += f * 2.0 / SR; ph2 -= Math.Floor(ph2);
				double tri = 1.0 - 4.0 * Math.Abs(ph - 0.5);
				double s = 0.7 * Math.Sin(TAU * ph) + 0.25 * tri + 0.09 * Math.Sin(TAU * ph2);
				double wob = 0.85 + 0.15 * Math.Sin(TAU * trem * t + v);
				m[i] = (float)(s * wob * Env(t, attack, dur, release));
			}
			o.Mix(m, 0, 0.25, spread * 0.9, false);
		}
		return o;
	}

	// Sum of decaying sine partials. `bend` starts the pitch that fraction
	// sharp and lets it settle, like a struck gong.
	static float[] Partials(double f0, double dur, double[] ratios, double[] amps, double[] decays,
		double attack, double bend, Random rng)
	{
		int n = Sec(dur);
		var o = new float[n];
		for (int p = 0; p < ratios.Length; p++)
		{
			double ph = rng.NextDouble();
			for (int i = 0; i < n; i++)
			{
				double t = (double)i / SR;
				double f = f0 * ratios[p] * (1.0 + bend * Math.Exp(-t / 0.08));
				ph += f / SR;
				double env = amps[p] * Math.Exp(-t * decays[p]) * Math.Min(1.0, t / attack);
				o[i] += (float)(Math.Sin(TAU * ph) * env);
			}
		}
		Fade(o, 0.05);
		return o;
	}

	static float[] Agung(double f0, double dur, Random rng)
	{
		var body = Partials(f0, dur, new[] { 1.0, 1.0035, 2.0, 2.42, 3.0, 4.1, 5.3 },
			new[] { 1.0, 0.6, 0.35, 0.22, 0.16, 0.09, 0.05 },
			new[] { 0.55, 0.6, 1.1, 1.7, 2.4, 3.4, 5.0 }, 0.004, 0.03, rng);
		var thump = Drum(f0 * 2.2, f0, 0.02, 0.09, 0.3, 0.3, 400, 0.8, 0.02, 1.2, rng);
		for (int i = 0; i < thump.Length && i < body.Length; i++) body[i] += thump[i] * 0.5f;
		return body;
	}

	static float[] Kulintang(double f0, Random rng)
	{
		var tone = Partials(f0, 0.9, new[] { 1.0, 2.0, 2.76, 3.9, 5.4 }, new[] { 1.0, 0.28, 0.24, 0.1, 0.06 },
			new[] { 4.0, 5.5, 7.5, 10.0, 14.0 }, 0.0015, 0.006, rng);
		var tick = NoiseHit(rng, 3200.0, 1.5, 0.0005, 0.006, 0.02);
		for (int i = 0; i < tick.Length; i++) tone[i] += tick[i] * 0.25f;
		return tone;
	}

	// Pitched sine body with an exponential pitch drop, a filtered noise skin,
	// and soft saturation.
	static float[] Drum(double f0, double f1, double sweep, double decay, double dur,
		double noiseAmt, double noiseHz, double noiseQ, double noiseDecay, double drive, Random rng)
	{
		int n = Sec(dur);
		var o = new float[n];
		var nf = new Svf();
		double ph = 0.0;
		double norm = Math.Tanh(drive);
		for (int i = 0; i < n; i++)
		{
			double t = (double)i / SR;
			double f = f1 + (f0 - f1) * Math.Exp(-t / sweep);
			ph += f / SR;
			double body = Math.Sin(TAU * ph) * Math.Exp(-t / decay) * Math.Min(1.0, t / 0.0008);
			nf.Process(rng.NextDouble() * 2.0 - 1.0, noiseHz, noiseQ);
			double skin = nf.Bp * Math.Exp(-t / noiseDecay) * noiseAmt;
			o[i] = (float)(Math.Tanh(drive * (body + skin)) / norm);
		}
		Fade(o, 0.02);
		return o;
	}

	static float[] WarDrum(Random rng, double weight)
	{
		return Drum(150.0 * (0.95 + rng.NextDouble() * 0.1), 54.0, 0.03, 0.34 * weight, 0.9,
			0.4, 800.0, 0.8, 0.05, 2.0, rng);
	}

	static float[] Tom(Random rng, double f)
	{
		return Drum(f * 1.6, f, 0.025, 0.18, 0.5, 0.35, 1200.0, 1.0, 0.03, 1.6, rng);
	}

	static float[] Dabakan(Random rng, bool slap)
	{
		if (slap)
			return Drum(420.0, 250.0, 0.01, 0.06, 0.25, 1.0, 2500.0, 1.1, 0.022, 1.8, rng);
		return Drum(270.0, 182.0, 0.015, 0.15, 0.4, 0.45, 1500.0, 1.2, 0.03, 1.4, rng);
	}

	static float[] Clack(Random rng)
	{
		var knock = Partials(1150.0 * (0.97 + rng.NextDouble() * 0.06), 0.12,
			new[] { 1.0, 1.5, 2.3 }, new[] { 1.0, 0.7, 0.3 }, new[] { 45.0, 60.0, 80.0 }, 0.0004, 0.0, rng);
		var tick = NoiseHit(rng, 4000.0, 1.0, 0.0003, 0.004, 0.01);
		for (int i = 0; i < tick.Length && i < knock.Length; i++) knock[i] += tick[i] * 0.4f;
		return knock;
	}

	static float[] Shaker(Random rng)
	{
		int n = Sec(0.12);
		var o = new float[n];
		var hp = new Svf();
		for (int i = 0; i < n; i++)
		{
			double t = (double)i / SR;
			hp.Process(rng.NextDouble() * 2.0 - 1.0, 5500.0, 0.7);
			double env = Math.Min(1.0, t / 0.008) * Math.Exp(-t / 0.035);
			o[i] = (float)(hp.Hp * env);
		}
		return o;
	}

	static float[] NoiseHit(Random rng, double hz, double q, double attack, double decay, double dur)
	{
		int n = Sec(dur);
		var o = new float[n];
		var f = new Svf();
		for (int i = 0; i < n; i++)
		{
			double t = (double)i / SR;
			f.Process(rng.NextDouble() * 2.0 - 1.0, hz, q);
			o[i] = (float)(f.Bp * Math.Min(1.0, t / attack) * Math.Exp(-t / decay) * 2.0);
		}
		Fade(o, 0.005);
		return o;
	}

	// Brass section: detuned saws whose low-pass opens with the attack
	// ("blat") and closes as the note dies, with a small scoop up into pitch.
	static float[] Brass(double freq, double dur, int voices, double cents, double attack,
		double cutStart, double cutPeak, double cutEnd, double scoopSemis, Random rng)
	{
		int n = Sec(dur + 0.25);
		var o = new float[n];
		for (int v = 0; v < voices; v++)
		{
			double spread = voices > 1 ? v / (voices - 1.0) * 2.0 - 1.0 : 0.0;
			double f0 = freq * Math.Pow(2.0, spread * cents / 1200.0);
			double ph = rng.NextDouble();
			var flt = new Svf();
			for (int i = 0; i < n; i++)
			{
				double t = (double)i / SR;
				double f = f0 * Math.Pow(2.0, -scoopSemis / 12.0 * Math.Exp(-t / 0.03));
				double dt = f / SR;
				double saw = 2.0 * ph - 1.0 - Blep(ph, dt);
				ph += dt;
				if (ph >= 1.0) ph -= 1.0;
				double rise = Math.Min(1.0, t / (attack * 2.5));
				double cut = t < attack * 2.5
					? cutStart + (cutPeak - cutStart) * rise
					: cutEnd + (cutPeak - cutEnd) * Math.Exp(-(t - attack * 2.5) / (dur * 0.35));
				flt.Process(saw, cut, 1.1);
				double env = Math.Min(1.0, t / attack) * (t < dur ? Math.Exp(-t / (dur * 0.7)) : Math.Exp(-dur / (dur * 0.7)) * Math.Exp(-(t - dur) / 0.06));
				o[i] += (float)(flt.Lp * env / voices);
			}
		}
		for (int i = 0; i < n; i++) o[i] = (float)Math.Tanh(o[i] * 2.2);
		Fade(o, 0.02);
		return o;
	}

	static float[] PitchFall(float[] src, double semis, double overSec)
	{
		var o = new float[src.Length];
		double pos = 0.0;
		for (int i = 0; i < o.Length; i++)
		{
			int a = (int)pos;
			if (a + 1 >= src.Length) break;
			double frac = pos - a;
			o[i] = (float)(src[a] * (1.0 - frac) + src[a + 1] * frac);
			double t = (double)i / SR;
			pos += Math.Pow(2.0, -semis / 12.0 * Math.Min(1.0, t / overSec));
		}
		return o;
	}

	// Continuous sine with a whole number of cycles per loop, so it meets
	// itself at the seam. `swell` adds a slow breathing amplitude.
	static float[] Drone(double freq, int n, double swell)
	{
		double loopSec = n / (double)SR;
		double f = Math.Round(freq * loopSec) / loopSec;
		var o = new float[n];
		for (int i = 0; i < n; i++)
		{
			double t = (double)i / SR;
			double a = 1.0 - swell * (0.5 + 0.5 * Math.Cos(TAU * t * 2.0 / loopSec));
			o[i] = (float)(Math.Sin(TAU * f * t) * a);
		}
		return o;
	}

	struct Note { public double Beat, Len; public int Midi; }
	struct Rendered { public float[] Samples; public double At; }

	static void Add(List<Note> line, double beat, double len, int midi)
	{
		line.Add(new Note { Beat = beat, Len = len, Midi = midi });
	}

	// Sloli: breathy sine-and-harmonics voice with delayed vibrato, a chiff
	// on tongued notes, and a quick glide when notes are slurred together.
	static List<Rendered> Flute(List<Note> line, double beatSec, Random rng)
	{
		var result = new List<Rendered>();
		for (int k = 0; k < line.Count; k++)
		{
			var note = line[k];
			double start = note.Beat * beatSec;
			double len = note.Len * beatSec;
			double target = Midi(note.Midi);
			bool slurred = false;
			double from = target;
			if (k > 0)
			{
				var prev = line[k - 1];
				if (Math.Abs((prev.Beat + prev.Len) - note.Beat) < 0.01)
				{
					slurred = true;
					from = Midi(prev.Midi);
				}
			}
			double release = 0.22;
			int n = Sec(len + release);
			var o = new float[n];
			var breath = new Svf();
			var hiss = new Svf();
			var chiff = new Svf();
			double ph = rng.NextDouble();
			double vibRate = 5.0 + rng.NextDouble() * 0.6;
			double vibPh = rng.NextDouble();
			double attack = slurred ? 0.03 : 0.09;
			for (int i = 0; i < n; i++)
			{
				double t = (double)i / SR;
				double vibDepth = 0.006 * Math.Min(1.0, Math.Max(0.0, (t - 0.25) / 0.4));
				double f = target + (from - target) * Math.Exp(-t / 0.035);
				f *= 1.0 + vibDepth * Math.Sin(TAU * (vibPh + vibRate * t));
				ph += f / SR;
				ph -= Math.Floor(ph);
				double env = Env(t, attack, len, release) * (0.82 + 0.18 * Math.Min(1.0, t / Math.Max(len, 0.1)));
				double tone = Math.Sin(TAU * ph) + 0.2 * Math.Sin(2 * TAU * ph) + 0.05 * Math.Sin(3 * TAU * ph);
				double noise = rng.NextDouble() * 2.0 - 1.0;
				breath.Process(noise, f, 4.0);
				hiss.Process(noise, 5200.0, 0.6);
				double s = tone * 0.8 + breath.Bp * 0.55 + hiss.Bp * 0.05;
				if (!slurred && t < 0.05)
				{
					chiff.Process(noise, f * 2.0, 2.0);
					s += chiff.Bp * 0.6 * (1.0 - t / 0.05);
				}
				o[i] = (float)(s * env);
			}
			result.Add(new Rendered { Samples = o, At = start });
		}
		return result;
	}

	// Formant tables: F1, F2, F3 for "ah", "oh", "oo".
	static readonly double[][] MaleVowels = {
		new[] { 700.0, 1220.0, 2600.0 },
		new[] { 450.0, 800.0, 2830.0 },
		new[] { 325.0, 700.0, 2530.0 },
	};
	static readonly double[][] FemaleVowels = {
		new[] { 850.0, 1220.0, 2810.0 },
		new[] { 500.0, 900.0, 2830.0 },
		new[] { 350.0, 750.0, 2700.0 },
	};
	static readonly double[] FormantGain = { 1.0, 0.5, 0.18 };
	static readonly double[] FormantBw = { 80.0, 100.0, 140.0 };

	// A choir section: `voices` singers per part, each with its own vibrato
	// and drift, through three band-pass formants that morph along `vowels`.
	static St ChoirPart(double freq, double dur, double attack, double release, bool female,
		int voices, int[] vowels, Random rng)
	{
		int n = Sec(dur + release);
		var o = new St(n);
		var table = female ? FemaleVowels : MaleVowels;
		double total = dur + release;
		for (int v = 0; v < voices; v++)
		{
			double spread = voices > 1 ? v / (voices - 1.0) * 2.0 - 1.0 : 0.0;
			double f0 = freq * Math.Pow(2.0, spread * 9.0 / 1200.0);
			double vibRate = 4.6 + rng.NextDouble() * 1.0;
			double vibPh = rng.NextDouble();
			double drift = 0.0;
			double ph = rng.NextDouble();
			var src = new Svf();
			var f1 = new Svf();
			var f2 = new Svf();
			var f3 = new Svf();
			double[] fc = new double[3];
			var m = new float[n];
			for (int i = 0; i < n; i++)
			{
				double t = (double)i / SR;
				if ((i & 31) == 0)
				{
					double pos = Math.Min(1.0, t / total) * (vowels.Length - 1);
					int a = Math.Min((int)pos, vowels.Length - 1);
					int b = Math.Min(a + 1, vowels.Length - 1);
					double w = pos - a;
					w = w * w * (3.0 - 2.0 * w);
					for (int k = 0; k < 3; k++)
						fc[k] = table[vowels[a]][k] * (1.0 - w) + table[vowels[b]][k] * w;
					drift += (rng.NextDouble() - 0.5) * 0.0004;
					drift *= 0.995;
				}
				double f = f0 * (1.0 + 0.0045 * Math.Sin(TAU * (vibPh + vibRate * t)) + drift);
				double dt = f / SR;
				double saw = 2.0 * ph - 1.0 - Blep(ph, dt);
				ph += dt;
				if (ph >= 1.0) ph -= 1.0;
				double aspiration = (rng.NextDouble() * 2.0 - 1.0) * 0.12;
				src.Process(saw + aspiration, 3600.0, 0.7);
				double x = src.Lp;
				f1.Process(x, fc[0], fc[0] / FormantBw[0]);
				f2.Process(x, fc[1], fc[1] / FormantBw[1]);
				f3.Process(x, fc[2], fc[2] / FormantBw[2]);
				double y = f1.Bp * FormantBw[0] / fc[0] * FormantGain[0]
					+ f2.Bp * FormantBw[1] / fc[1] * FormantGain[1]
					+ f3.Bp * FormantBw[2] / fc[2] * FormantGain[2];
				m[i] = (float)(y * Env(t, attack, dur, release));
			}
			o.Mix(m, 0, 1.4 / voices, spread * 0.7, false);
		}
		return o;
	}

	// ======================================================================
	// Effects
	// ======================================================================

	// Freeverb, run twice over the loop so the room's tail wraps onto the start.
	static St ReverbLoop(St dry, double room, double damp, double wet, double predelay)
	{
		var verb = new Freeverb(room, damp);
		int n = dry.N;
		int pre = Math.Max(1, Sec(predelay));
		var preL = new float[pre];
		var preR = new float[pre];
		int pi = 0;
		var hpL = new Svf();
		var hpR = new Svf();
		var o = new St(n);
		for (int pass = 0; pass < 2; pass++)
		{
			for (int i = 0; i < n; i++)
			{
				float inL = preL[pi], inR = preR[pi];
				preL[pi] = dry.L[i];
				preR[pi] = dry.R[i];
				pi = (pi + 1) % pre;
				hpL.Process(inL, 160.0, 0.7);
				hpR.Process(inR, 160.0, 0.7);
				float wl, wr;
				verb.Process((float)hpL.Hp, (float)hpR.Hp, out wl, out wr);
				if (pass == 1)
				{
					o.L[i] = dry.L[i] + (float)(wl * wet);
					o.R[i] = dry.R[i] + (float)(wr * wet);
				}
			}
		}
		return o;
	}

	// One-shot reverb: pads the dry signal with `tail` seconds of room.
	static St ReverbTail(St dry, double room, double damp, double wet, double tail)
	{
		int n = dry.N + Sec(tail);
		var verb = new Freeverb(room, damp);
		var o = new St(n);
		for (int i = 0; i < n; i++)
		{
			float l = i < dry.N ? dry.L[i] : 0f;
			float r = i < dry.N ? dry.R[i] : 0f;
			float wl, wr;
			verb.Process(l, r, out wl, out wr);
			o.L[i] = l + (float)(wl * wet);
			o.R[i] = r + (float)(wr * wet);
		}
		Fade(o.L, 0.3);
		Fade(o.R, 0.3);
		return o;
	}

	// Ping-pong echo, darkened each return, looped like the reverb.
	static void DelayLoop(St buf, double time, double feedback, double mix, double lpHz)
	{
		int n = buf.N;
		int d = Sec(time);
		var lineL = new float[d];
		var lineR = new float[d];
		int di = 0;
		var lpL = new Svf();
		var lpR = new Svf();
		var outL = new float[n];
		var outR = new float[n];
		for (int pass = 0; pass < 2; pass++)
		{
			for (int i = 0; i < n; i++)
			{
				float eL = lineL[di], eR = lineR[di];
				lpL.Process(eL, lpHz, 0.7);
				lpR.Process(eR, lpHz, 0.7);
				float mono = (buf.L[i] + buf.R[i]) * 0.5f;
				lineL[di] = mono + (float)(lpR.Lp * feedback);
				lineR[di] = (float)(lpL.Lp * feedback);
				di = (di + 1) % d;
				if (pass == 1)
				{
					outL[i] = buf.L[i] + (float)(eL * mix);
					outR[i] = buf.R[i] + (float)(eR * mix);
				}
			}
		}
		buf.L = outL;
		buf.R = outR;
	}

	// Sidechain: dip `buf` after each hit and recover over `recover` seconds.
	static void Duck(St buf, List<double> hits, double recover, double floor)
	{
		int n = buf.N;
		var g = new float[n];
		for (int i = 0; i < n; i++) g[i] = 1f;
		int len = Sec(recover);
		foreach (double h in hits)
		{
			int s = (int)(h * SR);
			for (int j = 0; j < len; j++)
			{
				int k = ((s + j) % n + n) % n;
				double x = (double)j / len;
				float v = (float)(floor + (1.0 - floor) * x * x * (3.0 - 2.0 * x));
				if (v < g[k]) g[k] = v;
			}
		}
		for (int i = 0; i < n; i++)
		{
			buf.L[i] *= g[i];
			buf.R[i] *= g[i];
		}
	}

	// ======================================================================
	// Mastering and output
	// ======================================================================

	static St Master(St s, double rmsDb)
	{
		return Limit(Scale(s, LoudnessGain(s, rmsDb)));
	}

	static double LoudnessGain(St s, double rmsDb)
	{
		double sum = 0.0;
		for (int i = 0; i < s.N; i++) sum += s.L[i] * s.L[i] + s.R[i] * s.R[i];
		double rms = Math.Sqrt(sum / (2.0 * s.N));
		return Math.Pow(10.0, rmsDb / 20.0) / Math.Max(rms, 1e-9);
	}

	static St Scale(St s, double gain)
	{
		var o = new St(s.N);
		for (int i = 0; i < s.N; i++)
		{
			o.L[i] = (float)(s.L[i] * gain);
			o.R[i] = (float)(s.R[i] * gain);
		}
		return o;
	}

	// Soft knee above -2 dBFS so drum peaks round off instead of clipping.
	static St Limit(St s)
	{
		for (int i = 0; i < s.N; i++)
		{
			s.L[i] = Knee(s.L[i]);
			s.R[i] = Knee(s.R[i]);
		}
		return s;
	}

	static float Knee(float x)
	{
		double a = Math.Abs(x);
		const double k = 0.79;
		if (a <= k) return x;
		double y = k + (0.985 - k) * Math.Tanh((a - k) / (0.985 - k));
		return (float)(Math.Sign(x) * y);
	}

	static St Peak(St s, double peakDb)
	{
		float peak = 0f;
		for (int i = 0; i < s.N; i++) peak = Math.Max(peak, Math.Max(Math.Abs(s.L[i]), Math.Abs(s.R[i])));
		return Scale(s, Math.Pow(10.0, peakDb / 20.0) / Math.Max(peak, 1e-9f));
	}

	static void Save(string dir, string name, St s)
	{
		string path = Path.Combine(dir, name + ".wav");
		using (var fs = new FileStream(path, FileMode.Create))
		using (var w = new BinaryWriter(fs))
		{
			int bytes = s.N * 4;
			w.Write(new[] { 'R', 'I', 'F', 'F' });
			w.Write(36 + bytes);
			w.Write(new[] { 'W', 'A', 'V', 'E', 'f', 'm', 't', ' ' });
			w.Write(16);
			w.Write((short)1);
			w.Write((short)2);
			w.Write(SR);
			w.Write(SR * 4);
			w.Write((short)4);
			w.Write((short)16);
			w.Write(new[] { 'd', 'a', 't', 'a' });
			w.Write(bytes);
			for (int i = 0; i < s.N; i++)
			{
				w.Write((short)Math.Round(Math.Max(-1.0, Math.Min(1.0, s.L[i])) * 32767.0));
				w.Write((short)Math.Round(Math.Max(-1.0, Math.Min(1.0, s.R[i])) * 32767.0));
			}
		}
		Console.WriteLine(string.Format("{0}.wav  {1:F1}s", name, s.N / (double)SR));
	}

	// ======================================================================
	// Helpers
	// ======================================================================

	static int Sec(double seconds) { return (int)Math.Round(seconds * SR); }

	static double Midi(double m) { return 440.0 * Math.Pow(2.0, (m - 69.0) / 12.0); }

	static double Jit(Random rng) { return (rng.NextDouble() - 0.5) * 0.008; }

	static double Vel(Random rng) { return 0.88 + rng.NextDouble() * 0.2; }

	static double Blep(double t, double dt)
	{
		if (t < dt) { t /= dt; return t + t - t * t - 1.0; }
		if (t > 1.0 - dt) { t = (t - 1.0) / dt; return t * t + t + t + 1.0; }
		return 0.0;
	}

	// Sine-shaped attack, hold until `off`, cosine release.
	static double Env(double t, double attack, double off, double release)
	{
		if (t < 0.0) return 0.0;
		double a = t < attack ? Math.Sin(Math.PI * 0.5 * t / attack) : 1.0;
		a *= a;
		if (t <= off) return a;
		double r = (t - off) / release;
		if (r >= 1.0) return 0.0;
		double c = Math.Cos(Math.PI * 0.5 * r);
		return a * c * c;
	}

	static void Fade(float[] o, double seconds)
	{
		int len = Math.Min(o.Length, Sec(seconds));
		for (int i = 0; i < len; i++)
			o[o.Length - 1 - i] *= (float)i / len;
	}

	static St Sum(St a, St b)
	{
		var o = new St(Math.Max(a.N, b.N));
		o.MixSt(a, 0, 1.0, false);
		o.MixSt(b, 0, 1.0, false);
		return o;
	}

	public class St
	{
		public float[] L;
		public float[] R;
		public St(int n) { L = new float[n]; R = new float[n]; }
		public int N { get { return L.Length; } }

		// Equal-power pan, -1 left .. 1 right, unity in the centre.
		public void Mix(float[] mono, double at, double gain, double pan, bool wrap)
		{
			int s = (int)Math.Round(at * SR);
			double a = (Math.Max(-1.0, Math.Min(1.0, pan)) + 1.0) * Math.PI * 0.25;
			float gl = (float)(Math.Cos(a) * gain * 1.41421356);
			float gr = (float)(Math.Sin(a) * gain * 1.41421356);
			int n = N;
			for (int j = 0; j < mono.Length; j++)
			{
				int k = s + j;
				if (wrap) { k %= n; if (k < 0) k += n; }
				else if (k < 0 || k >= n) continue;
				L[k] += mono[j] * gl;
				R[k] += mono[j] * gr;
			}
		}

		public void MixSt(St src, double at, double gain, bool wrap)
		{
			int s = (int)Math.Round(at * SR);
			int n = N;
			float g = (float)gain;
			for (int j = 0; j < src.N; j++)
			{
				int k = s + j;
				if (wrap) { k %= n; if (k < 0) k += n; }
				else if (k < 0 || k >= n) continue;
				L[k] += src.L[j] * g;
				R[k] += src.R[j] * g;
			}
		}
	}

	// Topology-preserving state-variable filter (Zavalishin).
	class Svf
	{
		double _ic1, _ic2;
		double _lastCut = -1, _lastQ = -1, _g, _k, _a1, _a2, _a3;
		public double Lp, Bp, Hp;

		public void Process(double x, double cutoff, double q)
		{
			if (cutoff != _lastCut || q != _lastQ)
			{
				double c = Math.Max(10.0, Math.Min(cutoff, SR * 0.45));
				_g = Math.Tan(Math.PI * c / SR);
				_k = 1.0 / Math.Max(0.05, q);
				_a1 = 1.0 / (1.0 + _g * (_g + _k));
				_a2 = _g * _a1;
				_a3 = _g * _a2;
				_lastCut = cutoff;
				_lastQ = q;
			}
			double v3 = x - _ic2;
			double v1 = _a1 * _ic1 + _a2 * v3;
			double v2 = _ic2 + _a2 * _ic1 + _a3 * v3;
			_ic1 = 2.0 * v1 - _ic1;
			_ic2 = 2.0 * v2 - _ic2;
			Lp = v2;
			Bp = v1;
			Hp = x - _k * v1 - v2;
		}
	}

	class Comb
	{
		readonly float[] _buf;
		int _i;
		float _store;
		readonly float _fb, _damp;
		public Comb(int size, double fb, double damp) { _buf = new float[size]; _fb = (float)fb; _damp = (float)damp; }
		public float Process(float x)
		{
			float o = _buf[_i];
			_store = o * (1f - _damp) + _store * _damp;
			_buf[_i] = x + _store * _fb;
			if (++_i >= _buf.Length) _i = 0;
			return o;
		}
	}

	class Allpass
	{
		readonly float[] _buf;
		int _i;
		public Allpass(int size) { _buf = new float[size]; }
		public float Process(float x)
		{
			float b = _buf[_i];
			float o = -x + b;
			_buf[_i] = x + b * 0.5f;
			if (++_i >= _buf.Length) _i = 0;
			return o;
		}
	}

	class Freeverb
	{
		static readonly int[] CombTuning = { 1116, 1188, 1277, 1356, 1422, 1491, 1557, 1617 };
		static readonly int[] AllpassTuning = { 556, 441, 341, 225 };
		const int Spread = 23;
		readonly Comb[] _cl = new Comb[8], _cr = new Comb[8];
		readonly Allpass[] _al = new Allpass[4], _ar = new Allpass[4];

		public Freeverb(double room, double damp)
		{
			double s = SR / 44100.0;
			for (int i = 0; i < 8; i++)
			{
				_cl[i] = new Comb((int)(CombTuning[i] * s), room, damp);
				_cr[i] = new Comb((int)((CombTuning[i] + Spread) * s), room, damp);
			}
			for (int i = 0; i < 4; i++)
			{
				_al[i] = new Allpass((int)(AllpassTuning[i] * s));
				_ar[i] = new Allpass((int)((AllpassTuning[i] + Spread) * s));
			}
		}

		public void Process(float inL, float inR, out float outL, out float outR)
		{
			float x = (inL + inR) * 0.03f;
			float l = 0f, r = 0f;
			for (int i = 0; i < 8; i++)
			{
				l += _cl[i].Process(x);
				r += _cr[i].Process(x);
			}
			for (int i = 0; i < 4; i++)
			{
				l = _al[i].Process(l);
				r = _ar[i].Process(r);
			}
			outL = l;
			outR = r;
		}
	}
}
