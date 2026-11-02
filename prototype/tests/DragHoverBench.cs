using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;

// Read only the supplied application's own animation assets. No UI interaction,
// user profile, dragged file, recycle operation or persistence is involved.
internal static class DragHoverBench
{
    [STAThread]
    private static int Main(string[] args)
    {
        string project = Path.GetFullPath(Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "..", ".."));
        string appDir = Path.Combine(project, "desktop", "lin4run");
        string executable = args.Length == 0 ? "奶蛙桌宠-联动版.exe" : args[0];
        if (Path.GetFileName(executable) != executable) throw new ArgumentException("Pass only an executable filename");
        Assembly assembly = Assembly.LoadFrom(Path.Combine(appDir, executable));
        Type assetsType = assembly.GetType("NaiwaDesktop.Assets", true);
        object assets = Activator.CreateInstance(assetsType, BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic, null, new object[] { appDir }, null);
        try
        {
            object drag = assetsType.GetField("Drag", BindingFlags.Instance | BindingFlags.NonPublic).GetValue(assets);
            Type type = drag.GetType();
            Stopwatch timer = Stopwatch.StartNew();
            type.GetMethod("Ensure", BindingFlags.Instance | BindingFlags.NonPublic).Invoke(drag, new[] { assets });
            object first = type.GetMethod("Frame", BindingFlags.Instance | BindingFlags.NonPublic).Invoke(drag, new object[] { 1 });
            timer.Stop();
            bool ready = (bool)type.GetProperty("Ready", BindingFlags.Instance | BindingFlags.NonPublic).GetValue(drag, null);
            int frames = (int)type.GetField("Count", BindingFlags.Instance | BindingFlags.NonPublic).GetValue(drag);
            PropertyInfo cache = type.GetProperty("CachedCount", BindingFlags.Instance | BindingFlags.NonPublic);
            string report = "Ready=" + ready + "\r\nFrameAvailable=" + (first != null) + "\r\nFrames=" + frames + "\r\nCachedFrames=" + (cache == null ? frames : cache.GetValue(drag, null)) + "\r\nFirstHoverDecodeMs=" + timer.ElapsedMilliseconds + "\r\nPrivateMemoryMB=" + (Process.GetCurrentProcess().PrivateMemorySize64 / 1024 / 1024) + "\r\n";
            File.WriteAllText(Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "drag-hover-benchmark.txt"), report);
            Console.Write(report);
            return ready ? 0 : 1;
        }
        finally { ((IDisposable)assets).Dispose(); }
    }
}
