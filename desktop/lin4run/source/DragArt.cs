using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;
using System.IO.Compression;
using System.Web.Script.Serialization;

namespace NaiwaDesktop;

internal sealed class DragArt : IDisposable
{
	internal readonly int Count;

	internal readonly int Width;

	internal readonly int Height;

	internal readonly double Fps;

	internal readonly double Duration;

	private readonly byte[][] encoded;

	private const int CacheLimit = 12;
	private readonly Dictionary<int, Bitmap> frames = new Dictionary<int, Bitmap>();
	private readonly Queue<int> frameOrder = new Queue<int>();
	private Assets owner;
	private bool decodeFailureReported;

	internal bool Ready => owner != null && encoded != null && Count > 0;
	internal int CachedCount => frames.Count;

	internal DragArt(string folder)
	{
		string text = Path.Combine(folder, "drag.nwp");
		if (!File.Exists(text))
		{
			Count = 0;
			Width = (Height = 0);
			Fps = 15.0;
			Duration = 0.0;
			encoded = null;
			return;
		}
		using ZipArchive zipArchive = ZipFile.OpenRead(text);
		Dictionary<string, object> dictionary;
		using (StreamReader streamReader = new StreamReader(zipArchive.GetEntry("metadata.json").Open()))
		{
			dictionary = new JavaScriptSerializer().Deserialize<Dictionary<string, object>>(streamReader.ReadToEnd());
		}
		Count = Convert.ToInt32(dictionary["frames"]);
		Fps = Convert.ToDouble(dictionary["fps"]);
		Duration = (double)Count / Fps;
		Width = (dictionary.ContainsKey("width") ? Convert.ToInt32(dictionary["width"]) : 0) / 2;
		Height = (dictionary.ContainsKey("height") ? Convert.ToInt32(dictionary["height"]) : 0) / 2;
		if (Count < 1 || Count > 600 || Fps < 1.0 || Fps > 120.0)
		{
			throw new InvalidDataException("拖放素材信息无效");
		}
		encoded = new byte[Count][];
		for (int i = 0; i < Count; i++)
		{
			encoded[i] = Assets.Read(zipArchive, "drag/" + i.ToString("0000") + ".png");
		}
	}

	internal void Ensure(Assets a)
	{
		if (owner == null && encoded != null && Count > 0) owner = a;
	}

	internal Bitmap Frame(int index)
	{
		if (!Ready) throw new InvalidOperationException("拖放动画尚未准备");
		int frame = Math.Max(0, Math.Min(Count - 1, index));
		if (frames.TryGetValue(frame, out Bitmap cached)) return cached;
		try
		{
			int width = (Width > 0 ? Width : owner.Width) * 2;
			int height = (Height > 0 ? Height : owner.Height) * 2;
			Bitmap decoded = owner.DecodeTo(encoded[frame], width, height);
			if (decoded == null) return owner.Eye(0.0);
			frames.Add(frame, decoded);
			frameOrder.Enqueue(frame);
			if (frameOrder.Count > CacheLimit)
			{
				int oldest = frameOrder.Dequeue();
				frames[oldest].Dispose();
				frames.Remove(oldest);
			}
			return decoded;
		}
		catch (Exception error)
		{
			// Keep the pet visible even if an animation frame cannot be decoded.
			if (!decodeFailureReported)
			{
				decodeFailureReported = true;
				try
				{
					Directory.CreateDirectory(Settings.Folder);
					File.AppendAllText(Path.Combine(Settings.Folder, "error.log"), DateTime.Now.ToString("s") + " 拖放动画解码失败，已使用待机画面：" + error.GetType().Name + Environment.NewLine);
				}
				catch { }
			}
			return owner.Eye(0.0);
		}
	}

	public void Dispose()
	{
		foreach (Bitmap frame in frames.Values) frame.Dispose();
		frames.Clear();
		frameOrder.Clear();
		owner = null;
	}
}

