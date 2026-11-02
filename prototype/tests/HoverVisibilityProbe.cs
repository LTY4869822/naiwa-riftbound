using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Reflection;
using System.Threading;
using System.Web.Script.Serialization;
using System.Windows.Forms;

namespace NaiwaDesktop
{
    // Isolated native OLE-hover rendering probe. No drop service is attached;
    // test:true blocks OnFileDrop and every input is the literal fixture token.
    internal static class HoverVisibilityProbe
    {
        private static readonly BindingFlags Private = BindingFlags.Instance | BindingFlags.NonPublic;
        private static readonly List<object> frames = new List<object>();
        private static int failures;
        private static string output;

        [STAThread]
        private static int Main(string[] args)
        {
            try
            {
                if (args.Length != 1) throw new ArgumentException("Pass a new workspace artifact directory.");
                output = Path.GetFullPath(args[0]);
                string taskRoot = FindWorkspace();
                string allowed = Path.Combine(taskRoot, "file-feeder", "prototype", "artifacts") + Path.DirectorySeparatorChar;
                if (!output.StartsWith(allowed, StringComparison.OrdinalIgnoreCase)) throw new IOException("Output must stay in workspace artifacts.");
                if (Directory.Exists(output)) throw new IOException("Probe output must be new.");
                Directory.CreateDirectory(output);
                Settings.TestFolderOverride = Path.Combine(output, "isolated-appdata");
                Directory.CreateDirectory(Settings.TestFolderOverride);
                Native.SetProcessDPIAware(); Application.EnableVisualStyles();
                Application.SetCompatibleTextRenderingDefault(false);
                Application.ThreadException += delegate(object sender, ThreadExceptionEventArgs error)
                { failures++; File.AppendAllText(Path.Combine(output, "ui-errors.txt"), error.Exception + Environment.NewLine); Application.ExitThread(); };
                using (Assets assets = new Assets(Path.Combine(taskRoot, "file-feeder", "desktop", "lin4run")))
                {
                    foreach (int scale in new[] { 50, 85, 100, 150 })
                    using (PetWindow pet = new PetWindow(assets, true))
                    {
                        pet.SetSize(scale); pet.SetSound(false); pet.SetAutoHide(false);
                        pet.TopMost = false; pet.ShowInTaskbar = false;
                        pet.StartPosition = FormStartPosition.Manual; pet.Location = new Point(-32000, -32000);
                        pet.Show(); Application.DoEvents(); pet.TickWithForeground(IntPtr.Zero);
                        Snapshot(pet, scale, "before");
                        Point hit = FindSadHit(pet);
                        Point global = pet.PointToScreen(hit);
                        DataObject fixture = new DataObject(); fixture.SetData(DataFormats.FileDrop, new[] { "fixture" });
                        DragEventArgs drag = new DragEventArgs(fixture, 0, global.X, global.Y, DragDropEffects.Copy, DragDropEffects.Copy);
                        Invoke(pet, "OnDragEnter", drag); Snapshot(pet, scale, "enter");
                        for (int frame = 0; frame < 150; frame++)
                        {
                            Invoke(pet, "OnDragOver", drag);
                            pet.TickWithForeground(IntPtr.Zero); Application.DoEvents();
                            if (frame % 15 == 0) Snapshot(pet, scale, "over-" + frame);
                            Thread.Sleep(16);
                        }
                        Invoke(pet, "OnDragLeave", EventArgs.Empty); Snapshot(pet, scale, "leave");
                        for (int frame = 0; frame < 80; frame++)
                        { pet.TickWithForeground(IntPtr.Zero); Application.DoEvents(); Thread.Sleep(16); }
                        Snapshot(pet, scale, "settled");
                        pet.Close(); Application.DoEvents();
                    }
                }
                Write(); Console.WriteLine("HOVER_VISIBILITY failures=" + failures + " output=" + output);
                return failures == 0 ? 0 : 1;
            }
            catch (Exception error)
            { failures++; if (output != null) File.WriteAllText(Path.Combine(output, "exception.txt"), error.ToString()); Console.Error.WriteLine(error); return 1; }
        }
        private static string FindWorkspace()
        {
            string cursor = AppDomain.CurrentDomain.BaseDirectory;
            while (!String.IsNullOrEmpty(cursor))
            { if (File.Exists(Path.Combine(cursor, "file-feeder", "prototype", "project.godot"))) return cursor; cursor = Path.GetDirectoryName(cursor.TrimEnd('\\', '/')); }
            throw new IOException("Run inside this task workspace.");
        }
        private static void Invoke(PetWindow pet, string name, object args)
        { typeof(Control).GetMethod(name, Private).Invoke(pet, new[] { args }); }
        private static Point FindSadHit(PetWindow pet)
        {
            MethodInfo method = typeof(PetWindow).GetMethod("SadHit", Private);
            for (int y = 58; y < pet.Height; y += 3) for (int x = 0; x < pet.Width; x += 3)
                if ((bool)method.Invoke(pet, new object[] { x, y })) return new Point(x, y);
            throw new IOException("No body drop target at this scale.");
        }
        private static void Snapshot(PetWindow pet, int scale, string phase)
        {
            LayeredSurface surface = (LayeredSurface)typeof(PetWindow).GetField("surface", Private).GetValue(pet);
            byte[] buffer = (byte[])typeof(LayeredSurface).GetField("buffer", Private).GetValue(surface);
            int opaque = 0; if (buffer != null) for (int i = 3; i < buffer.Length; i += 4) if (buffer[i] > 24) opaque++;
            bool ok = pet.Visible && !pet.HiddenForFullscreen && opaque > 1000;
            if (!ok) failures++;
            frames.Add(new { scale, phase, ok, visible = pet.Visible, hidden = pet.HiddenForFullscreen, opaque, bounds = pet.Bounds.ToString(), visual = pet.LastVisual, hover = pet.Motion.HoverOpen });
            Write();
        }
        private static void Write()
        { File.WriteAllText(Path.Combine(output, "result.json"), new JavaScriptSerializer().Serialize(new { failures, frames })); }
    }
}
