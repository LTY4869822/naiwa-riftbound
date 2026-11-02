using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Reflection;
using System.Text;
using System.Threading;
using System.Web.Script.Serialization;
using System.Windows.Forms;

namespace NaiwaDesktop
{
    // Exercises the real asynchronous OnFileDrop -> service -> growth-view UI
    // using only an in-memory store. No Windows recycle adapter is constructed.
    internal static class PetFeedUiTests
    {
        private sealed class UiFakeStore:IFileDropStore,IDisposable
        {
            internal readonly ManualResetEvent Entered=new ManualResetEvent(false);
            internal readonly ManualResetEvent Release=new ManualResetEvent(false);
            internal int Calls,PreviewCalls,WorkerId;
            internal ApartmentState Apartment;
            internal bool ExactFixtureOnly=true;
            private readonly DropEntry entry=new DropEntry {Id=new string('d',64),Path="fixture",Signature="ui-fixture-eight-mib",Bytes=8L*1024*1024,IsDirectory=false};
            public DropPreview Preview(string[] paths)
            {
                Interlocked.Increment(ref PreviewCalls);
                if(paths==null||paths.Length!=1||paths[0]!="fixture")
                {ExactFixtureOnly=false;throw new InvalidOperationException("UI fake accepts only the literal fixture token, never real paths");}
                DropPreview preview=new DropPreview();preview.Entries.Add(entry.Copy());return preview;
            }
            public List<DropResult> Recycle(IList<DropEntry> entries,IntPtr owner,Action<DropResult> completed)
            {
                Interlocked.Increment(ref Calls);WorkerId=Thread.CurrentThread.ManagedThreadId;Apartment=Thread.CurrentThread.GetApartmentState();
                if(entries==null||entries.Count!=1||entries[0].Path!="fixture"||entries[0].Id!=entry.Id||entries[0].Bytes!=entry.Bytes)
                {ExactFixtureOnly=false;throw new InvalidOperationException("Unexpected fake recycle payload");}
                Entered.Set();Thread.Sleep(250);
                if(!Release.WaitOne(3500))throw new TimeoutException("UI did not release the fake worker");
                DropResult result=new DropResult {Entry=entry.Copy(),Recycled=true,HResult=DropRecycleStatus.DontProcessChildren,PreDeleteFlags=0x80,PostDeleteFlags=0x80,CreatedItemPresent=true,RecyclePathVerified=true,SourceAbsent=true,BytesMatch=true,MetadataMatch=true,TypeMatch=true};
                if(completed!=null)completed(result);
                return new List<DropResult>{result};
            }
            public void Dispose(){Entered.Dispose();Release.Dispose();}
        }
        private static readonly List<string> lines=new List<string>();
        private static int failures;
        private static string progressPath;
        private static void Progress(string text){lines.Add(text);if(progressPath!=null)File.WriteAllLines(progressPath,lines.ToArray(),new UTF8Encoding(false));}
        private static void Check(bool ok,string title){Progress((ok?"PASS ":"FAIL ")+title);if(!ok)failures++;}
        private static Assets LoadAssets(){Progress("STEP loading source assets");Assets value=new Assets(AppDomain.CurrentDomain.BaseDirectory);Progress("STEP source assets ready");return value;}
        private static PetWindow CreatePet(Assets assets){Progress("STEP constructing isolated pet");PetWindow value=new PetWindow(assets,true);Progress("STEP isolated pet ready");return value;}
        private static bool Within(string path,string root)
        {return String.Equals(path,root,StringComparison.OrdinalIgnoreCase)||path.StartsWith(root+Path.DirectorySeparatorChar,StringComparison.OrdinalIgnoreCase);}
        private static string Workspace()
        {
            string cursor=Path.GetFullPath(AppDomain.CurrentDomain.BaseDirectory).TrimEnd('\\','/');
            while(!String.IsNullOrEmpty(cursor))
            {
                if(File.Exists(Path.Combine(cursor,"file-feeder","prototype","project.godot"))&&Directory.Exists(Path.Combine(cursor,".git")))return cursor;
                cursor=Path.GetDirectoryName(cursor);
            }
            throw new IOException("UI tests must run from this task's workspace");
        }
        private static bool Wait(Func<bool> ready,int milliseconds=5000)
        {
            Stopwatch clock=Stopwatch.StartNew();
            while(!ready()&&clock.ElapsedMilliseconds<milliseconds){Application.DoEvents();Thread.Sleep(10);}
            Application.DoEvents();return ready();
        }
        private static DragEventArgs Drop()
        {
            DataObject data=new DataObject();data.SetData(DataFormats.FileDrop,new[]{"fixture"});
            return new DragEventArgs(data,0,0,0,DragDropEffects.Copy,DragDropEffects.Copy);
        }
        private static bool HasFileList(Control parent)
        {
            if(parent is DataGridView||parent is ListView||parent is CheckedListBox||parent is TreeView)return true;
            foreach(Control child in parent.Controls)if(HasFileList(child))return true;
            return false;
        }
        private static Point BodyPoint(PetWindow pet)
        {
            MethodInfo hit=typeof(PetWindow).GetMethod("SadHit",BindingFlags.Instance|BindingFlags.NonPublic);
            for(int y=58;y<pet.Height;y+=3) for(int x=0;x<pet.Width;x+=3)
                if((bool)hit.Invoke(pet,new object[]{x,y})) return pet.PointToScreen(new Point(x,y));
            throw new InvalidOperationException("No visible drop target in the fixture window");
        }
        private static void DragEvent(PetWindow pet,string name,object args)
        { typeof(Control).GetMethod(name,BindingFlags.Instance|BindingFlags.NonPublic).Invoke(pet,new[]{args}); }
        private static int OpaquePixels(PetWindow pet)
        {
            object surface=typeof(PetWindow).GetField("surface",BindingFlags.Instance|BindingFlags.NonPublic).GetValue(pet);
            byte[] pixels=(byte[])surface.GetType().GetField("buffer",BindingFlags.Instance|BindingFlags.NonPublic).GetValue(surface);
            int opaque=0;if(pixels!=null)for(int i=3;i<pixels.Length;i+=4)if(pixels[i]>24)opaque++;
            return opaque;
        }
        private static void Capture(Assets assets,PetWindow pet,string path,string bubble)
        {
            try
            {
                using(Bitmap bitmap=Renderer.Render(assets,pet.Motion,100,false,100,bubble,false))bitmap.Save(path,ImageFormat.Png);
                lines.Add("NOTE fixture-only rendered preview: "+Path.GetFileName(path));
            }
            catch(Exception error){lines.Add("NOTE optional rendered preview unavailable: "+error.GetType().Name);}
        }
        internal static void Run(string output)
        {
            lines.Clear();failures=0;
            string destination=Path.GetFullPath(output);string fixture=null;bool allowedOutput=false;
            try
            {
                string allowed=Path.Combine(Workspace(),"file-feeder","prototype","artifacts");
                if(!Within(destination,allowed))throw new IOException("UI test output must stay in workspace prototype/artifacts");
                allowedOutput=true;
                if(String.IsNullOrEmpty(Settings.TestFolderOverride)||!Within(Path.GetFullPath(Settings.TestFolderOverride),destination))throw new IOException("Program must isolate Settings.TestFolderOverride before UI testing");
                Directory.CreateDirectory(destination);progressPath=Path.Combine(destination,"pet-feed-ui-progress.txt");fixture=Path.Combine(destination,"ui-"+Guid.NewGuid().ToString("N").Substring(0,8));Directory.CreateDirectory(fixture);
                string data=Path.Combine(fixture,"native"),profile=Path.Combine(fixture,"profile.json");
                string initial="{\"version\":1,\"level\":1,\"xp\":59,\"fed\":0,\"wins\":0,\"defeats\":0,\"next_id\":1,\"files\":[],\"consumed\":[]}";
                File.WriteAllText(profile,initial,new UTF8Encoding(false));
                Check(Thread.CurrentThread.GetApartmentState()==ApartmentState.STA,"UI test owns an STA thread and an isolated settings directory");
                int mainThread=Thread.CurrentThread.ManagedThreadId;
                using(Assets assets=LoadAssets())
                using(UiFakeStore fake=new UiFakeStore())
                using(PetWindow pet=CreatePet(assets))
                {
                    Progress("STEP preparing isolated window");
                    pet.SetSize(85);pet.SetSound(false);pet.SetAutoHide(false);
                    // LayeredSurface owns per-pixel alpha: Form.Opacity would mix
                    // SetLayeredWindowAttributes with UpdateLayeredWindow. Keep the
                    // test offscreen instead of changing the source pet's alpha mode.
                    pet.StartPosition=FormStartPosition.Manual;pet.Location=new Point(-32000,-32000);pet.ShowInTaskbar=false;pet.TopMost=false;
                    pet.AttachFeedTestStore(fake,data,profile);Progress("STEP fake store attached");pet.Show();Progress("STEP window shown");Application.DoEvents();Progress("STEP initial messages processed");
                    Check(pet.GrowthLabel.Contains("Lv.1"),"fake-store hook reads the fixture level before feeding");
                    Check(!HasFileList(pet),"the direct-drop UI contains no file-list or category controls");
                    Point hit=BodyPoint(pet);
                    DataObject hoverData=new DataObject();hoverData.SetData(DataFormats.FileDrop,new[]{"fixture"});
                    DragEventArgs hover=new DragEventArgs(hoverData,0,hit.X,hit.Y,DragDropEffects.Copy,DragDropEffects.Copy);
                    Stopwatch firstHover=Stopwatch.StartNew();DragEvent(pet,"OnDragEnter",hover);firstHover.Stop();
                    Progress("METRIC first visible hover milliseconds="+firstHover.ElapsedMilliseconds);
                    Check(pet.Motion.HoverOpen && pet.Visible && OpaquePixels(pet)>1000,"real drag-enter shows a nontransparent pet");
                    Check(assets.Drag.CachedCount<=2,"first drag-over decodes only the animation frame it needs");
                    pet.ApplyFullscreen(true);
                    Check(pet.Visible && !pet.HiddenForFullscreen,"fullscreen auto-hide cannot hide the pet during drag-over");
                    for(int index=0;index<assets.Drag.Count;index++) assets.Drag.Frame(index);
                    Check(assets.Drag.CachedCount<=12,"the complete 120-frame animation keeps a bounded frame cache");
                    byte[][] encoded=(byte[][])typeof(DragArt).GetField("encoded",BindingFlags.Instance|BindingFlags.NonPublic).GetValue(assets.Drag);
                    byte[] original=encoded[1];
                    try { encoded[1]=new byte[]{1,2,3}; Check(Object.ReferenceEquals(assets.Drag.Frame(1),assets.Eye(0.0)),"a damaged animation frame falls back to the visible idle pet"); }
                    finally { encoded[1]=original; }
                    DragEvent(pet,"OnDragLeave",EventArgs.Empty);
                    int windows=Application.OpenForms.Count;
                    try
                    {
                        Stopwatch returned=Stopwatch.StartNew();pet.OnFileDrop(pet,Drop());returned.Stop();
                        Check(returned.ElapsedMilliseconds<200,"OnFileDrop returns before the fake recycle operation completes");
                        Check(pet.FeedingBusy,"the real UI immediately marks the asynchronous feed busy");
                        Check(pet.Motion.Dragging,"the real drop starts the original swallowing animation");
                        Check(Wait(()=>fake.Entered.WaitOne(0)),"the fake recycle worker starts while UI messages remain responsive");
                        pet.ApplyFullscreen(true);
                        Check(pet.Visible && !pet.HiddenForFullscreen,"fullscreen auto-hide cannot hide the pet during feeding");
                        Check(fake.Apartment==ApartmentState.STA,"the recycle pipeline runs on a background STA");
                        Check(fake.WorkerId!=0&&fake.WorkerId!=mainThread,"recycling runs outside the UI thread");
                        returned.Restart();pet.OnFileDrop(pet,Drop());returned.Stop();
                        Check(returned.ElapsedMilliseconds<100&&fake.Calls==1&&fake.PreviewCalls==1,"a second busy drop returns without previewing or swallowing twice");
                        string receipts=Path.Combine(data,"receipts");
                        Check(!Directory.Exists(receipts)||Directory.GetFiles(receipts,"*.json").Length==0,"no growth receipt appears before successful completion");
                        Check(File.ReadAllText(profile)==initial,"the native UI leaves the game profile intact while recycling");
                        pet.Motion.Clock=Math.Max(pet.Motion.Clock,pet.Motion.DragStart+0.40);
                        Capture(assets,pet,Path.Combine(destination,"pet-feed-swallow-demo.png"),"正在吞下测试碎片…");
                        fake.Release.Set();
                        Check(Wait(()=>!pet.FeedingBusy),"the completed worker returns to the UI within five seconds");
                        string[] files=Directory.Exists(receipts)?Directory.GetFiles(receipts,"*.json"):new string[0];
                        Check(fake.Calls==1&&files.Length==1,"one direct drop produces exactly one recycle call and one receipt");
                        long bytes=-1;int items=-1;
                        if(files.Length==1)
                        {
                            Dictionary<string,object> receipt=new JavaScriptSerializer().Deserialize<Dictionary<string,object>>(File.ReadAllText(files[0]));
                            bytes=Convert.ToInt64(receipt["completed_bytes"]);items=((System.Collections.ICollection)receipt["items"]).Count;
                        }
                        Check(bytes==8L*1024*1024&&items==1,"the UI-to-service pipeline persists exactly one 8 MiB fixture");
                        Check(fake.ExactFixtureOnly,"the fake store receives only its literal fixture token");
                        Check(pet.GrowthLabel.Contains("Lv.2")&&pet.GrowthLabel.Contains("8 MiB"),"the native byte-growth label immediately previews level two");
                        Check(File.ReadAllText(profile)==initial&&!File.Exists(profile+".tmp")&&!File.Exists(profile+".bak"),"native growth does not rewrite the game's fixture profile or staging files");
                        Check(pet.Motion.Dancing,"successful feeding starts the original celebration dance");
                        Check(Application.OpenForms.Count==windows,"feeding opens no secondary file-selection or classification window");
                        pet.Motion.Clock=Math.Max(pet.Motion.Clock,pet.Motion.DanceStart+0.30);
                        Capture(assets,pet,Path.Combine(destination,"pet-feed-level-up-demo.png"),"吞下 8 MiB · Lv.2！");
                        pet.Motion.DragStart=-1.0;pet.Motion.HoverOpen=false;
                        typeof(PetWindow).GetField("feedVisibilityUntil",BindingFlags.Instance|BindingFlags.NonPublic).SetValue(pet,0.0);
                        if((Native.GetAsyncKeyState(1)&0x8000)==0)
                        {
                            pet.ApplyFullscreen(true);
                            Check(pet.HiddenForFullscreen && !pet.Visible,"normal fullscreen auto-hide still works after feeding");
                            pet.ApplyFullscreen(false);
                            Check(!pet.HiddenForFullscreen && pet.Visible,"leaving fullscreen restores the pet");
                        }
                        else Progress("NOTE fullscreen-after-feed check skipped while a real mouse button was held");
                    }
                    finally
                    {
                        fake.Release.Set();Wait(()=>!pet.FeedingBusy);pet.Close();Application.DoEvents();
                    }
                    Check(pet.IsDisposed,"the isolated pet window closes cleanly after its worker completes");
                }
            }
            catch(Exception error){Check(false,"unexpected UI test exception: "+error);}
            lines.Add("Failures="+failures);lines.Add("Fake store only. No WindowsFileDropStore, real desktop paths, or existing user files were used.");
            if(allowedOutput){Directory.CreateDirectory(destination);File.WriteAllLines(Path.Combine(destination,"pet-feed-ui-tests.txt"),lines.ToArray(),new UTF8Encoding(false));}
            else Console.Error.WriteLine(String.Join(Environment.NewLine,lines.ToArray()));
            Environment.ExitCode=failures==0?0:1;
        }
    }
}
