using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public static class BuildWeaverDash
{
	const int Frames = 8;

	public static void Main(string[] args)
	{
		string root = args.Length > 0 ? args[0] : @"e:\dreamweaver\assets\images\enemies";
		var walk = Load(System.IO.Path.Combine(root, "shadow_weaver_walk.png"));
		var lunge = Load(System.IO.Path.Combine(root, "shadow_weaver_lunge.png"));
		int w = walk.W;
		int h = walk.H;
		int fw = w / Frames;
		var dst = new byte[h * w * 4];
		int stride = w * 4;

		// coil, lean, launch, streak, streak, arrive, skid, settle
		var plan = new FramePlan[]
		{
			new FramePlan("walk", 0, 0, new Ghost[0], false),
			new FramePlan("walk", 2, 2, new[] { new Ghost("walk", 0, -10, 100) }, false),
			new FramePlan("lunge", 1, 4, new[] { new Ghost("walk", 2, -14, 120), new Ghost("walk", 0, -26, 70) }, true),
			new FramePlan("lunge", 2, 4, new[] { new Ghost("lunge", 1, -12, 140), new Ghost("walk", 2, -24, 90) }, true),
			new FramePlan("walk", 5, 2, new[] { new Ghost("lunge", 2, -12, 150), new Ghost("lunge", 1, -24, 95) }, true),
			new FramePlan("walk", 6, 0, new[] { new Ghost("walk", 5, -12, 110), new Ghost("lunge", 2, -22, 70) }, true),
			new FramePlan("lunge", 7, 0, new[] { new Ghost("walk", 6, -10, 80) }, false),
			new FramePlan("walk", 0, 0, new Ghost[0], false),
		};

		for (int i = 0; i < plan.Length; i++)
		{
			var spec = plan[i];
			foreach (var ghost in spec.Ghosts)
			{
				var sheet = ghost.Sheet == "lunge" ? lunge : walk;
				Blit(sheet, dst, stride, w, h, fw, ghost.Frame, i, spec.Shift + ghost.Dx, 186, 28, 214, 62, ghost.Alpha);
			}
			if (spec.Streaks)
				DrawStreaks(dst, stride, w, h, fw, i);
			var body = spec.Src == "lunge" ? lunge : walk;
			int mix = (i == 3 || i == 4) ? 18 : 0;
			Blit(body, dst, stride, w, h, fw, spec.Frame, i, spec.Shift, 210, 40, 230, mix, 255);
		}

		var outBmp = new Bitmap(w, h, PixelFormat.Format32bppArgb);
		var rect = new Rectangle(0, 0, w, h);
		var data = outBmp.LockBits(rect, ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
		Marshal.Copy(dst, 0, data.Scan0, dst.Length);
		outBmp.UnlockBits(data);
		string outPath = System.IO.Path.Combine(root, "shadow_weaver_dash.png");
		outBmp.Save(outPath, ImageFormat.Png);
		outBmp.Dispose();
		Console.WriteLine("wrote " + outPath);
	}

	static void Blit(Sheet src, byte[] dst, int stride, int w, int h, int fw, int srcFrame, int dstFrame, int shift, int tintR, int tintG, int tintB, int tintMix, int alpha)
	{
		int x0 = srcFrame * fw;
		int dx0 = dstFrame * fw;
		int dx1 = dx0 + fw;
		int keep = 100 - tintMix;
		for (int y = 0; y < h; y++)
		{
			for (int x = 0; x < fw; x++)
			{
				int sx = x0 + x;
				if (sx < 0 || sx >= src.W) continue;
				int si = y * src.Stride + sx * 4;
				int b = src.Bytes[si];
				int g = src.Bytes[si + 1];
				int r = src.Bytes[si + 2];
				if (IsPlate(r, g, b)) continue;
				int nr = (r * keep + tintR * tintMix) / 100;
				int ng = (g * keep + tintG * tintMix) / 100;
				int nb = (b * keep + tintB * tintMix) / 100;
				int dx = dx0 + x + shift;
				if (dx < dx0 || dx >= dx1) continue;
				Put(dst, stride, w, h, dx, y, nr, ng, nb, alpha);
			}
		}
	}

	static void DrawStreaks(byte[] dst, int stride, int w, int h, int fw, int frame)
	{
		int x0 = frame * fw;
		int count = 12 + frame;
		for (int n = 0; n < count; n++)
		{
			int y = 268 + ((n * 37) % 150);
			int len = 26 + ((n * 13) % 46);
			int x = x0 + 18 + ((n * 19) % 70);
			int x1 = x0 + fw;
			bool bright = (n % 3) == 0;
			int alpha = 168;
			for (int k = 0; k < len; k++)
			{
				int px = x + k;
				if (px < x0 || px >= x1) continue;
				if (bright) Put(dst, stride, w, h, px, y, 255, 214, 255, alpha);
				else Put(dst, stride, w, h, px, y, 168, 36, 214, 120);
			}
		}
	}

	static void Put(byte[] dst, int stride, int w, int h, int x, int y, int r, int g, int b, int a)
	{
		if ((uint)x >= (uint)w || (uint)y >= (uint)h) return;
		int i = y * stride + x * 4;
		int oa = dst[i + 3];
		if (oa >= a && a < 250) return;
		dst[i] = (byte)b;
		dst[i + 1] = (byte)g;
		dst[i + 2] = (byte)r;
		dst[i + 3] = (byte)a;
	}

	static bool IsPlate(int r, int g, int b)
	{
		return g < 26 && r > 96 && b > 55 && r > g * 4;
	}

	static Sheet Load(string path)
	{
		using (var src = new Bitmap(path))
		using (var bmp = new Bitmap(src.Width, src.Height, PixelFormat.Format32bppArgb))
		{
			using (var g = Graphics.FromImage(bmp))
				g.DrawImage(src, 0, 0, src.Width, src.Height);
			var rect = new Rectangle(0, 0, bmp.Width, bmp.Height);
			var data = bmp.LockBits(rect, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
			int stride = data.Stride;
			var bytes = new byte[stride * bmp.Height];
			Marshal.Copy(data.Scan0, bytes, 0, bytes.Length);
			bmp.UnlockBits(data);
			return new Sheet { Bytes = bytes, Stride = stride, W = bmp.Width, H = bmp.Height };
		}
	}

	class Sheet
	{
		public byte[] Bytes;
		public int Stride;
		public int W;
		public int H;
	}

	class Ghost
	{
		public string Sheet;
		public int Frame;
		public int Dx;
		public int Alpha;
		public Ghost(string sheet, int frame, int dx, int alpha)
		{
			Sheet = sheet; Frame = frame; Dx = dx; Alpha = alpha;
		}
	}

	class FramePlan
	{
		public string Src;
		public int Frame;
		public int Shift;
		public Ghost[] Ghosts;
		public bool Streaks;
		public FramePlan(string src, int frame, int shift, Ghost[] ghosts, bool streaks)
		{
			Src = src; Frame = frame; Shift = shift; Ghosts = ghosts; Streaks = streaks;
		}
	}
}
