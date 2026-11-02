using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Windows.Forms;

namespace NaiwaDesktop
{
    // Keep the source pet's gestures, renderer and animation state in PetWindow.
    // This component only owns the lifetime of our existing Godot game window.
    internal sealed class GameBridge : IDisposable
    {
        private readonly PetWindow pet;
        private readonly bool isolated;
        private Process game;
        private string folder, lastState = "", lastRequest = "";
        private int sequence;
        private DateTime lastHeartbeat = DateTime.MinValue;
        private bool disposed;

        internal bool Active { get; private set; }
        internal bool HasGame { get { return game != null && !game.HasExited; } }
        internal int GameId { get { return HasGame ? game.Id : 0; } }
        internal string State { get { return ReadState(); } }
        internal string SessionFolder { get { return folder; } }
        internal string LastRequest { get { return lastRequest; } }

        internal GameBridge(PetWindow owner, bool test = false)
        {
            if (owner == null) throw new ArgumentNullException("owner");
            pet = owner; isolated = test;
        }

        internal void Enter()
        {
            if (disposed) return;
            try
            {
                if (!HasGame)
                {
                    if (game != null) { game.Dispose(); game = null; }
                    string root = Path.GetFullPath(Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "..", ".."));
                    string engine = Path.Combine(root, "tools", "Godot_v4.7.2-stable_win64.exe");
                    if (!File.Exists(engine)) throw new FileNotFoundException("缺少 Godot 运行器", engine);
                    string sessions = isolated
                        ? Path.Combine(root, "prototype", "artifacts", "lin4run-bridge")
                        : Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "NaiwaDesktopPet", "game-sessions");
                    folder = Path.Combine(sessions, Guid.NewGuid().ToString("N"));
                    Directory.CreateDirectory(folder);
                    lastHeartbeat = DateTime.MinValue;
                    lastState = lastRequest = "";
                    Heartbeat();
                    string arguments = "--path \"" + Path.Combine(root, "prototype") + "\" --log-file \"" + Path.Combine(folder, "game.log") + "\""
                        + (isolated ? " --position -32000,-32000" : "")
                        + " -- --bridge-dir \"" + folder + "\" --owner-pid " + Process.GetCurrentProcess().Id
                        + (isolated ? " --bridge-check" : "");
                    game = Process.Start(new ProcessStartInfo(engine, arguments) { UseShellExecute = false, WorkingDirectory = root });
                    if (game == null) throw new IOException("游戏进程未创建");
                }
                else
                {
                    lastState = ReadState();
                    Command("resume");
                }
                SetActive(true);
            }
            catch (Exception error)
            {
                SetActive(false);
                if (isolated) throw;
                MessageBox.Show("游戏没有启动：" + error.Message, "奶蛙", MessageBoxButtons.OK, MessageBoxIcon.Information);
            }
        }

        internal void Return()
        {
            if (disposed) return;
            if (HasGame) { lastState = ReadState(); Command("pet"); }
            SetActive(false);
        }

        private void Command(string name)
        {
            if (!String.IsNullOrEmpty(folder)) File.WriteAllText(Path.Combine(folder, "command.txt"), (++sequence) + "|" + name);
        }

        private string ReadState()
        {
            try { return File.ReadAllText(Path.Combine(folder, "state")).Trim(); }
            catch (IOException) { return ""; }
            catch (UnauthorizedAccessException) { return ""; }
            catch (ArgumentException) { return ""; }
        }

        internal void Tick()
        {
            if (disposed || game == null) return;
            if (!HasGame) { game.Dispose(); game = null; SetActive(false); return; }
            try { Heartbeat(); }
            catch (IOException) { return; }
            catch (UnauthorizedAccessException) { return; }
            string state = ReadState();
            if (state != lastState && state.Length > 0)
            {
                lastState = state;
                SetActive(state == "active");
            }
            // Retain the existing game request wire format; the new product action is
            // a short drag-to-feed hint, never the former permanent-delete dialog.
            try
            {
                string path = Path.Combine(folder, "desktop-request.txt");
                if (!File.Exists(path) || new FileInfo(path).Length > 256) return;
                string request = File.ReadAllText(path).Trim();
                if (request == lastRequest || !request.EndsWith("|recycle", StringComparison.Ordinal)) return;
                lastRequest = request;
                if (!isolated)
                {
                    Return();
                    pet.ShowFeedHint();
                }
            }
            catch (IOException) { }
            catch (UnauthorizedAccessException) { }
        }

        private void Heartbeat()
        {
            if (String.IsNullOrEmpty(folder) || (DateTime.UtcNow - lastHeartbeat).TotalSeconds < 0.5) return;
            File.WriteAllText(Path.Combine(folder, "owner-alive"), "alive");
            lastHeartbeat = DateTime.UtcNow;
        }

        private void SetActive(bool value)
        {
            if (Active == value) return;
            Active = value;
            pet.SetGameActive(value);
        }

        public void Dispose()
        {
            if (disposed) return;
            disposed = true;
            if (HasGame) { try { Command("quit"); } catch (IOException) { } catch (UnauthorizedAccessException) { } }
            if (game != null) game.Dispose();
            game = null;
        }

        internal void KillTestChild()
        {
            if (isolated && HasGame) { game.Kill(); game.WaitForExit(3000); }
        }
    }

    internal static class BridgeTests
    {
        private static void Wait(GameBridge bridge, Func<bool> condition)
        {
            Stopwatch watch = Stopwatch.StartNew();
            while (!condition() && watch.Elapsed.TotalSeconds < 15)
            {
                Application.DoEvents(); bridge.Tick(); System.Threading.Thread.Sleep(40);
            }
            if (!condition()) throw new Exception("Bridge condition timed out; state=" + bridge.State);
            bridge.Tick(); Application.DoEvents();
        }

        internal static void Run(string output)
        {
            Directory.CreateDirectory(output);
            List<string> log = new List<string>();
            try
            {
                using (Assets assets = new Assets(AppDomain.CurrentDomain.BaseDirectory))
                using (PetWindow pet = new PetWindow(assets, true))
                {
                    pet.SetAutoHide(false); pet.SetSound(false);
                    pet.TopMost = false; pet.ShowInTaskbar = false; pet.StartPosition = FormStartPosition.Manual;
                    pet.Location = new System.Drawing.Point(-32000, -32000);
                    pet.Show(); Application.DoEvents();
                    using (GameBridge bridge = pet.AttachTestBridge())
                    {
                        try
                        {
                            bridge.Enter(); Wait(bridge, delegate { return bridge.State == "active"; });
                            if (!bridge.Active || pet.Visible) throw new Exception("Pet must hide during game");
                            log.Add("PASS LIN4RUN pet hides after launching our game");
                            if (!bridge.SessionFolder.Contains(Path.Combine("prototype", "artifacts", "lin4run-bridge"))) throw new Exception("Test session escaped workspace");
                            log.Add("PASS isolated session stays inside workspace artifacts");
                            int first = bridge.GameId;
                            IntPtr gameWindow = IntPtr.Zero;
                            Wait(bridge, delegate {
                                using (Process process = Process.GetProcessById(first)) { process.Refresh(); gameWindow = process.MainWindowHandle; }
                                return gameWindow != IntPtr.Zero;
                            });
                            File.WriteAllText(Path.Combine(bridge.SessionFolder, "desktop-request.txt"), "fixture-request|recycle");
                            bridge.Tick();
                            if (bridge.LastRequest != "fixture-request|recycle" || !bridge.Active) throw new Exception("Isolated request triggered a real feed action");
                            log.Add("PASS isolated feed request is acknowledged without a real desktop action");
                            bridge.Return(); Wait(bridge, delegate { return bridge.State == "pet"; });
                            if (!pet.Visible) throw new Exception("Pet must restore");
                            log.Add("PASS returning from game restores LIN4RUN pet");
                            Wait(bridge, delegate { return Native.IsIconic(gameWindow); });
                            log.Add("PASS returning to the pet minimizes the actual game window");
                            bridge.Enter(); Wait(bridge, delegate { return bridge.State == "active"; });
                            if (bridge.GameId != first) throw new Exception("Resume spawned duplicate game");
                            log.Add("PASS resume reuses the same game process");
                            Wait(bridge, delegate { return !Native.IsIconic(gameWindow); });
                            log.Add("PASS resuming restores the same game window");
                            bridge.KillTestChild(); bridge.Tick();
                            if (bridge.Active || !pet.Visible) throw new Exception("Crash recovery failed");
                            log.Add("PASS child failure restores the pet");
                        }
                        finally { bridge.KillTestChild(); }
                    }
                    pet.Close();
                }
                log.Add("RESULT: PASS");
            }
            catch (Exception error) { log.Add("FAIL: " + error); Environment.ExitCode = 1; }
            File.WriteAllLines(Path.Combine(output, "bridge-test.txt"), log.ToArray());
        }
    }
}
