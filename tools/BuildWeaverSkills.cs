using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public static class BuildWeaverSkills
{
	const int Frames = 8;

	public static void Main(string[] args)
	{
		string root = args.Length > 0 ? args[0] : @"e:\dreamweaver\assets\images\enemies";
		var claw = Load(System.IO.Path.Combine(root, "shadow_weaver_claw.png"));
		var cast = Load(System.IO.Path.Combine(root, "shadow_weaver_cast.png"));
		var nova = Load(System.IO.Path.Combine(root, "shadow_weaver_nova.png"));
		Save(BuildBlind(claw, cast, nova), System.IO.Path.Combine(root, "shadow_weaver_blind.png"));
		Console.WriteLine("claw " + claw.W + "x" + claw.H + " blind written");
	}

	static Sheet BuildClaw(Sheet src)
	{
		int fw = src.W / Frames;
		var dst = Copy(src);
		for (int frame = 4; frame <= 6; frame++)
			ExtendSlash(src, dst, fw, frame, frame == 6);
		Bloom(dst, fw, 7, 10);
		return dst;
	}

	static void ExtendSlash(Sheet src, Sheet dst, int fw, int frame, bool backhand)
	{
		int x0 = frame * fw;
		int cx = 0;
		int count = 0;
		for (int y = 0; y < src.H; y++)
		{
			for (int x = 0; x < fw; x++)
			{
				int r, g, b, a;
				Read(src, x0 + x, y, out r, out g, out b, out a);
				if (a < 40) continue;
				cx += x;
				count++;
			}
		}
		if (count < 8) return;
		cx /= count;
		for (int y = 0; y < src.H; y++)
		{
			for (int x = 0; x < fw; x++)
			{
				int r, g, b, a;
				Read(src, x0 + x, y, out r, out g, out b, out a);
				if (!IsSlash(r, g, b, a)) continue;
				int ox = x;
				if (backhand)
					ox = cx - (x - cx);
				else
					ox = x + 28;
				Put(dst, x0 + ox, y - 4, 236, 210, 255, 230);
				Put(dst, x0 + ox + (backhand ? -8 : 10), y + 2, 186, 64, 230, 200);
				Put(dst, x0 + ox + (backhand ? -16 : 18), y + 8, 255, 236, 255, 160);
			}
		}
	}

	static void Bloom(Sheet dst, int fw, int frame, int radius)
	{
		int x0 = frame * fw;
		int cx = x0 + fw / 2 + fw / 7;
		int cy = (int)(dst.H * 0.46);
		for (int y = cy - radius * 3; y <= cy + radius * 2; y++)
		{
			for (int x = cx - radius * 3; x <= cx + radius * 3; x++)
			{
				int dx = x - cx;
				int dy = (y - cy) * 2;
				if (dx * dx + dy * dy > radius * radius * 4) continue;
				int a = 90 + (dx * dx + dy * dy) / 8;
				if (a > 180) a = 180;
				Put(dst, x, y, 230, 180, 255, a);
			}
		}
	}

	static Sheet BuildBlind(Sheet body, Sheet cast, Sheet nova)
	{
		var dst = new Sheet
		{
			W = body.W,
			H = body.H,
			Stride = body.W * 4,
			Bytes = new byte[body.H * body.W * 4]
		};
		int fw = body.W / Frames;
		int[] srcFrame = { 0, 1, 2, 3, 4, 5, 6, 7 };
		for (int i = 0; i < Frames; i++)
		{
			var sheet = i < 4 ? cast : nova;
			BlitFrame(sheet, dst, srcFrame[i], i, fw);
			if (i >= 4)
				Flash(dst, fw, i, i == 4 ? 36 : (i == 7 ? 18 : 28));
		}
		return dst;
	}

	static void BlitFrame(Sheet src, Sheet dst, int srcFrame, int dstFrame, int dstFw)
	{
		if (src.W < Frames || src.H < 2) return;
		int srcFw = src.W / Frames;
		int x0 = dstFrame * dstFw;
		int ox = x0 + (dstFw - srcFw) / 2;
		int oy = (dst.H - src.H) / 2;
		for (int y = 0; y < src.H; y++)
		{
			for (int x = 0; x < srcFw; x++)
			{
				int r, g, b, a;
				Read(src, srcFrame * srcFw + x, y, out r, out g, out b, out a);
				if (a < 16 || IsPlate(r, g, b)) continue;
				Put(dst, ox + x, oy + y, r, g, b, a);
			}
		}
	}

	static void Flash(Sheet dst, int fw, int frame, int radius)
	{
		int x0 = frame * fw;
		int cx = x0 + fw / 2;
		int cy = (int)(dst.H * 0.42);
		for (int y = cy - radius * 2; y <= cy + radius * 2; y++)
		{
			for (int x = cx - radius * 2; x <= cx + radius * 2; x++)
			{
				if (x < x0 + 2 || x >= x0 + fw - 2) continue;
				int dx = x - cx;
				int dy = y - cy;
				int d2 = dx * dx + dy * dy;
				int limit = radius * radius;
				if (d2 > limit) continue;
				int a = 255 - (d2 * 220) / Math.Max(1, limit);
				if (a < 24) continue;
				int r, g, b, oa;
				Read(dst, x, y, out r, out g, out b, out oa);
				if (oa > 30)
				{
					Put(dst, x, y, (r + 255) / 2, (g + 244) / 2, 255, Math.Max(oa, a));
				}
				else
				{
					Put(dst, x, y, 236, 242, 255, a / 3);
				}
			}
		}
	}

	static bool IsSlash(int r, int g, int b, int a)
	{
		return a > 70 && b > 90 && r > 80 && g < 210 && (b + r) > g + 80;
	}

	static bool IsPlate(int r, int g, int b)
	{
		return g < 26 && r > 96 && b > 55 && r > g * 4;
	}

	static Sheet Copy(Sheet src)
	{
		var bytes = new byte[src.Bytes.Length];
		Buffer.BlockCopy(src.Bytes, 0, bytes, 0, bytes.Length);
		return new Sheet { Bytes = bytes, Stride = src.Stride, W = src.W, H = src.H };
	}

	static void Read(Sheet src, int x, int y, out int r, out int g, out int b, out int a)
	{
		r = g = b = a = 0;
		if ((uint)x >= (uint)src.W || (uint)y >= (uint)src.H) return;
		int i = y * src.Stride + x * 4;
		b = src.Bytes[i];
		g = src.Bytes[i + 1];
		r = src.Bytes[i + 2];
		a = src.Bytes[i + 3];
	}

	static void Put(Sheet dst, int x, int y, int r, int g, int b, int a)
	{
		if ((uint)x >= (uint)dst.W || (uint)y >= (uint)dst.H) return;
		int i = y * dst.Stride + x * 4;
		int oa = dst.Bytes[i + 3];
		if (oa > a && a < 240) return;
		dst.Bytes[i] = (byte)b;
		dst.Bytes[i + 1] = (byte)g;
		dst.Bytes[i + 2] = (byte)r;
		dst.Bytes[i + 3] = (byte)a;
	}

	static void Save(Sheet sheet, string path)
	{
		var bmp = new Bitmap(sheet.W, sheet.H, PixelFormat.Format32bppArgb);
		var rect = new Rectangle(0, 0, sheet.W, sheet.H);
		var data = bmp.LockBits(rect, ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
		if (data.Stride == sheet.Stride)
			Marshal.Copy(sheet.Bytes, 0, data.Scan0, sheet.Bytes.Length);
		else
		{
			for (int y = 0; y < sheet.H; y++)
				Marshal.Copy(sheet.Bytes, y * sheet.Stride, data.Scan0 + y * data.Stride, sheet.W * 4);
		}
		bmp.UnlockBits(data);
		bmp.Save(path, ImageFormat.Png);
		bmp.Dispose();
		Console.WriteLine("wrote " + path);
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
}
