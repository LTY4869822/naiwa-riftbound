using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;
using System.Threading;

namespace NaiwaDesktop
{
    internal sealed class DropEntry
    {
        internal string Id, Path, Signature;
        internal long Bytes;
        internal bool IsDirectory;
        internal DropEntry Copy() { return new DropEntry { Id=Id, Path=Path, Signature=Signature, Bytes=Bytes, IsDirectory=IsDirectory }; }
    }
    internal sealed class DropPreview
    {
        internal readonly List<DropEntry> Entries=new List<DropEntry>();
        internal readonly List<string> Messages=new List<string>();
    }
    internal sealed class DropResult
    {
        internal DropEntry Entry;
        internal bool Recycled, Cancelled;
        internal int HResult;
        // Diagnostic state stays in memory. Growth receipts never contain paths.
        internal uint PreDeleteFlags,PostDeleteFlags;
        internal bool CreatedItemPresent,RecyclePathVerified,SourceAbsent,BytesMatch,MetadataMatch,TypeMatch;
        internal string ErrorMessage="";
    }
    internal static class DropRecycleStatus
    {
        // Microsoft Windows SDK sherrors.h: the copy engine completed a whole item
        // (for example by recycling the directory) and must not process its children.
        internal const int DontProcessChildren=0x00270008;
        internal static bool IsCompleted(int value){return value==0||value==DontProcessChildren;}
    }
    internal interface IFileDropStore
    {
        DropPreview Preview(string[] paths);
        List<DropResult> Recycle(IList<DropEntry> entries, IntPtr owner, Action<DropResult> completed);
    }

    [ComVisible(true), ComImport, Guid("43826D1E-E718-42EE-BC55-A1E261C37BFE"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IDropShellItem
    {
        [PreserveSig] int BindToHandler(IntPtr bind, ref Guid handler, ref Guid iid, out IntPtr value);
        [PreserveSig] int GetParent(out IDropShellItem parent);
        [PreserveSig] int GetDisplayName(uint type, out IntPtr name);
        [PreserveSig] int GetAttributes(uint mask, out uint attributes);
        [PreserveSig] int Compare(IDropShellItem other, uint hint, out int order);
    }
    [ComVisible(true), Guid("04B0F1A7-9490-44BC-96E1-4296A31252E2"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IDropOperationSink
    {
        [PreserveSig] int StartOperations();
        [PreserveSig] int FinishOperations(int result);
        [PreserveSig] int PreRenameItem(uint flags, IDropShellItem item, [MarshalAs(UnmanagedType.LPWStr)] string name);
        [PreserveSig] int PostRenameItem(uint flags, IDropShellItem item, [MarshalAs(UnmanagedType.LPWStr)] string name, int result, IDropShellItem created);
        [PreserveSig] int PreMoveItem(uint flags, IDropShellItem item, IDropShellItem destination, [MarshalAs(UnmanagedType.LPWStr)] string name);
        [PreserveSig] int PostMoveItem(uint flags, IDropShellItem item, IDropShellItem destination, [MarshalAs(UnmanagedType.LPWStr)] string name, int result, IDropShellItem created);
        [PreserveSig] int PreCopyItem(uint flags, IDropShellItem item, IDropShellItem destination, [MarshalAs(UnmanagedType.LPWStr)] string name);
        [PreserveSig] int PostCopyItem(uint flags, IDropShellItem item, IDropShellItem destination, [MarshalAs(UnmanagedType.LPWStr)] string name, int result, IDropShellItem created);
        [PreserveSig] int PreDeleteItem(uint flags, IDropShellItem item);
        [PreserveSig] int PostDeleteItem(uint flags, IDropShellItem item, int result, IDropShellItem created);
        [PreserveSig] int PreNewItem(uint flags, IDropShellItem destination, [MarshalAs(UnmanagedType.LPWStr)] string name);
        [PreserveSig] int PostNewItem(uint flags, IDropShellItem destination, [MarshalAs(UnmanagedType.LPWStr)] string name, [MarshalAs(UnmanagedType.LPWStr)] string template, uint attributes, int result, IDropShellItem created);
        [PreserveSig] int UpdateProgress(uint total, uint done);
        [PreserveSig] int ResetTimer();
        [PreserveSig] int PauseTimer();
        [PreserveSig] int ResumeTimer();
    }

    // Source paths originate only in the user's drop gesture. No disk-wide cleanup or
    // permanent-delete fallback exists. Folder measurement reads metadata, never contents.
    internal sealed class WindowsFileDropStore : IFileDropStore
    {
        internal const int Abort=unchecked((int)0x80004004);
        internal const long MaxBytes=32L*1024*1024*1024;
        private readonly List<string> protectedTrees=new List<string>();
        private readonly List<string> protectedWholeFolders=new List<string>();
        private static readonly Guid ShellItemId=new Guid("43826D1E-E718-42EE-BC55-A1E261C37BFE");

        internal WindowsFileDropStore(string gameRoot)
        {
            AddProtected(gameRoot);
            AddProtected(Settings.Folder);
            foreach(Environment.SpecialFolder folder in new[] {Environment.SpecialFolder.Windows,Environment.SpecialFolder.System,Environment.SpecialFolder.SystemX86,Environment.SpecialFolder.ProgramFiles,Environment.SpecialFolder.ProgramFilesX86,Environment.SpecialFolder.CommonApplicationData})
                AddProtected(Environment.GetFolderPath(folder));
            foreach(Environment.SpecialFolder folder in new[] {Environment.SpecialFolder.UserProfile,Environment.SpecialFolder.DesktopDirectory,Environment.SpecialFolder.MyDocuments,Environment.SpecialFolder.ApplicationData,Environment.SpecialFolder.LocalApplicationData})
            {
                string path=Environment.GetFolderPath(folder);
                if(!String.IsNullOrWhiteSpace(path))protectedWholeFolders.Add(Canonical(path));
            }
        }
        private void AddProtected(string path) { if(!String.IsNullOrWhiteSpace(path))protectedTrees.Add(Canonical(path)); }
        private static string Canonical(string path)
        {
            if(String.IsNullOrWhiteSpace(path)||path.IndexOf('\0')>=0||!System.IO.Path.IsPathRooted(path))throw new IOException("只接收拖入的本地文件");
            return System.IO.Path.GetFullPath(path).TrimEnd(System.IO.Path.DirectorySeparatorChar,System.IO.Path.AltDirectorySeparatorChar);
        }
        private static bool Same(string a,string b) { return String.Equals(a,b,StringComparison.OrdinalIgnoreCase); }
        private static bool Inside(string path,string parent) { return Same(path,parent)||path.StartsWith(parent+System.IO.Path.DirectorySeparatorChar,StringComparison.OrdinalIgnoreCase); }
        private void Allowed(string path)
        {
            string volume=System.IO.Path.GetPathRoot(path);
            if(String.IsNullOrEmpty(volume)||Same(path,volume.TrimEnd('\\','/'))||path.StartsWith(@"\\",StringComparison.Ordinal))throw new IOException("磁盘根目录和网络位置不参与投喂");
            DriveInfo drive=new DriveInfo(volume);
            if(!drive.IsReady||drive.DriveType!=DriveType.Fixed)throw new IOException("此位置不支持可还原回收");
            foreach(string reserved in new[]{"$Recycle.Bin","System Volume Information","Boot","Recovery"})
                if(Inside(path,Canonical(System.IO.Path.Combine(volume,reserved))))throw new IOException("回收站和系统保留目录不参与投喂");
            foreach(string root in protectedTrees)if(Inside(path,root)||Inside(root,path))throw new IOException("系统、游戏和数据目录不参与投喂");
            foreach(string root in protectedWholeFolders)if(Same(path,root)||Inside(root,path))throw new IOException("整个用户或常用目录不参与投喂");
            string cursor=path;
            while(!String.IsNullOrEmpty(cursor)&&!Same(cursor,volume.TrimEnd('\\','/')))
            {
                FileAttributes attributes=File.GetAttributes(cursor);
                if((attributes&FileAttributes.ReparsePoint)!=0)throw new IOException("链接或云端占位项已跳过");
                cursor=System.IO.Path.GetDirectoryName(cursor);
            }
        }
        public DropPreview Preview(string[] paths)
        {
            DropPreview result=new DropPreview();
            if(paths==null||paths.Length==0)return result;
            if(paths.Length>1000)throw new IOException("一次最多拖入1000个文件或文件夹");
            List<string> candidates=new List<string>();
            foreach(string raw in paths)
            {
                try {string path=Canonical(raw);Allowed(path);if(!candidates.Exists(p=>Same(p,path)))candidates.Add(path);}
                catch(Exception error){result.Messages.Add(error.Message);}
            }
            candidates.Sort((a,b)=>a.Length.CompareTo(b.Length));
            long bytes=0;
            foreach(string path in candidates)
            {
                if(result.Entries.Exists(entry=>entry.IsDirectory&&Inside(path,entry.Path)))continue;
                try
                {
                    DropEntry entry=Snapshot(path);
                    if(bytes>MaxBytes-entry.Bytes)throw new IOException("本批超过32 GiB，请分批拖入");
                    bytes+=entry.Bytes;result.Entries.Add(entry);
                }
                catch(Exception error){result.Messages.Add(error.Message);}
            }
            return result;
        }
        private sealed class SnapshotState { internal long Bytes; internal int Count; internal readonly List<string> Records=new List<string>(); }
        private static DropEntry Snapshot(string path)
        {
            FileAttributes attributes=File.GetAttributes(path);
            SnapshotState state=new SnapshotState();
            Measure(path,"",state,0);
            state.Records.Sort(StringComparer.OrdinalIgnoreCase);
            string signature=Hash(String.Join("\n",state.Records.ToArray()));
            return new DropEntry {Path=path,Bytes=state.Bytes,IsDirectory=(attributes&FileAttributes.Directory)!=0,Signature=signature,Id=Hash(path.ToUpperInvariant()+"\n"+signature)};
        }
        private static void Measure(string path,string relative,SnapshotState state,int depth)
        {
            if(depth>128)throw new IOException("文件夹层级过深，请分批投喂");
            if(++state.Count>100000)throw new IOException("文件夹内容太多，请分批投喂");
            FileAttributes attributes=File.GetAttributes(path);
            if((attributes&FileAttributes.ReparsePoint)!=0)throw new IOException("文件夹包含链接或云端占位项，已跳过");
            bool directory=(attributes&FileAttributes.Directory)!=0;
            FileSystemInfo info=directory?(FileSystemInfo)new DirectoryInfo(path):new FileInfo(path);
            long bytes=directory?0:((FileInfo)info).Length;
            if(bytes<0||bytes>MaxBytes||state.Bytes>MaxBytes-bytes)throw new IOException("文件夹或文件超过32 GiB，请分批投喂");
            state.Bytes+=bytes;
            state.Records.Add(relative.ToUpperInvariant()+"|"+(directory?"D":"F")+"|"+bytes.ToString(CultureInfo.InvariantCulture)+"|"+info.CreationTimeUtc.Ticks.ToString(CultureInfo.InvariantCulture)+"|"+info.LastWriteTimeUtc.Ticks.ToString(CultureInfo.InvariantCulture));
            if(directory)foreach(string child in Directory.GetFileSystemEntries(path))Measure(child,relative+"/"+System.IO.Path.GetFileName(child),state,depth+1);
        }
        internal static string Hash(string text) {using(SHA256 algorithm=SHA256.Create())return BitConverter.ToString(algorithm.ComputeHash(Encoding.UTF8.GetBytes(text))).Replace("-","").ToLowerInvariant();}
        private static bool SnapshotMatches(DropEntry a,DropEntry b){return a.Id==b.Id&&a.Bytes==b.Bytes&&a.IsDirectory==b.IsDirectory&&a.Signature==b.Signature&&Same(a.Path,b.Path);}
        private bool Revalidate(DropEntry entry){try{Allowed(entry.Path);return SnapshotMatches(entry,Snapshot(entry.Path));}catch{return false;}}
        public List<DropResult> Recycle(IList<DropEntry> entries,IntPtr owner,Action<DropResult> completed)
        {
            if(Thread.CurrentThread.GetApartmentState()!=ApartmentState.STA)throw new InvalidOperationException("文件回收需要STA线程");
            if(Environment.OSVersion.Version.Major<6||(Environment.OSVersion.Version.Major==6&&Environment.OSVersion.Version.Minor<2))throw new IOException("当前Windows不支持强制可还原回收");
            List<DropResult> results=new List<DropResult>();
            if(entries==null||entries.Count==0)return results;
            if(entries.Count>1000)throw new IOException("本批项目过多");
            List<DropEntry> admitted=new List<DropEntry>();
            foreach(DropEntry entry in entries)
            {
                if(entry==null||!Revalidate(entry))results.Add(new DropResult {Entry=entry,HResult=Abort,ErrorMessage="文件已变化或不能安全回收，已保留"});
                else admitted.Add(entry.Copy());
            }
            if(admitted.Count==0)return results;
            IDropFileOperation operation=null;
            List<IDropShellItem> native=new List<IDropShellItem>();
            Sink sink=new Sink(this,admitted,completed);
            uint cookie=0;bool advised=false,aborted=true;int hr=Abort;
            try
            {
                operation=(IDropFileOperation)Activator.CreateInstance(Type.GetTypeFromCLSID(new Guid("3AD05575-8857-4850-9277-11B85BDB8E09")));
                Check(operation.SetOwnerWindow(owner));
                // RECYCLEONDELETE forces recycling. No raw DeleteFile/SHFileOperation or
                // permanent-delete retry is provided. A second non-recycle callback aborts.
                const uint flags=0x00080000|0x20000000|0x00100000|0x00000400|0x00000010|0x00002000;
                Check(operation.SetOperationFlags(flags));Check(operation.Advise(sink,out cookie));advised=true;
                foreach(DropEntry entry in admitted)
                {
                    IDropShellItem item;Guid iid=ShellItemId;Check(SHCreateItemFromParsingName(entry.Path,IntPtr.Zero,ref iid,out item));native.Add(item);Check(operation.DeleteItem(item,null));
                }
                hr=operation.PerformOperations();int status=operation.GetAnyOperationsAborted(out aborted);if(status<0)aborted=true;
            }
            catch(Exception error){hr=Marshal.GetHRForException(error);aborted=true;}
            finally
            {
                if(advised&&operation!=null)try{operation.Unadvise(cookie);}catch{}
                foreach(IDropShellItem item in native)Release(item);Release(operation);GC.KeepAlive(sink);
            }
            foreach(DropEntry entry in admitted)
            {
                DropResult result;
                if(!sink.Results.TryGetValue(entry.Id,out result))result=new DropResult {Entry=entry,HResult=hr==0?Abort:hr,Cancelled=aborted,ErrorMessage="没有确认可还原回收，未计成长"};
                else if(!result.Recycled&&aborted)result.Cancelled=true;
                results.Add(result);
            }
            if(sink.PersistenceFailure!=null)throw new IOException("成长记录保存受阻，后续回收已停止",sink.PersistenceFailure);
            return results;
        }
        private static string ItemPath(IDropShellItem item)
        {
            IntPtr value;Check(item.GetDisplayName(0x80058000,out value));
            try{return Canonical(Marshal.PtrToStringUni(value));}finally{Marshal.FreeCoTaskMem(value);}
        }
        [ComVisible(true),ClassInterface(ClassInterfaceType.None)]
        private sealed class Sink:IDropOperationSink
        {
            private readonly WindowsFileDropStore store;
            private readonly List<DropEntry> entries;
            private readonly Action<DropResult> completed;
            private readonly Dictionary<string,uint> preDeleteFlags=new Dictionary<string,uint>(StringComparer.Ordinal);
            internal readonly Dictionary<string,DropResult> Results=new Dictionary<string,DropResult>(StringComparer.Ordinal);
            internal Exception PersistenceFailure;
            internal Sink(WindowsFileDropStore owner,List<DropEntry> allowed,Action<DropResult> callback){store=owner;entries=allowed;completed=callback;}
            public int PreDeleteItem(uint flags,IDropShellItem item)
            {
                try
                {
                    string path=ItemPath(item);DropEntry root=entries.Find(e=>Same(e.Path,path));
                    if(root!=null)preDeleteFlags[root.Id]=flags;
                    if(PersistenceFailure!=null||(flags&0x80)==0)return Abort;
                    if(root!=null)return store.Revalidate(root)?0:Abort;
                    // Folder children may have callbacks; only descendants of a selected
                    // measured tree are admitted, and never independently rewarded.
                    if(!entries.Exists(e=>e.IsDirectory&&Inside(path,e.Path)))return Abort;
                    store.Allowed(path);return 0;
                }
                catch{return Abort;}
            }
            public int PostDeleteItem(uint flags,IDropShellItem item,int result,IDropShellItem created)
            {
                DropEntry entry;
                try{string path=ItemPath(item);entry=entries.Find(e=>Same(e.Path,path));if(entry==null)return 0;}catch{return Abort;}
                DropResult previous;if(Results.TryGetValue(entry.Id,out previous)&&previous.Recycled)return 0;
                uint preFlags;preDeleteFlags.TryGetValue(entry.Id,out preFlags);
                DropResult status=new DropResult {Entry=entry,HResult=result,PreDeleteFlags=preFlags,PostDeleteFlags=flags,CreatedItemPresent=created!=null,ErrorMessage="未确认可还原回收，未计成长"};
                // Non-null newlyCreated proves a recycled item, whereas null means full
                // deletion. Merely disappearing from the source never earns a reward.
                if(DropRecycleStatus.IsCompleted(result)&&created!=null&&(preFlags&0x80)!=0)
                {
                    try
                    {
                        string recycled=ItemPath(created);
                        string recycleRoot=System.IO.Path.GetPathRoot(entry.Path)+"$Recycle.Bin";
                        status.RecyclePathVerified=Inside(recycled,Canonical(recycleRoot));
                        status.SourceAbsent=!File.Exists(entry.Path)&&!Directory.Exists(entry.Path);
                        if(status.RecyclePathVerified&&status.SourceAbsent)
                        {
                            DropEntry actual=Snapshot(recycled);
                            status.BytesMatch=actual.Bytes==entry.Bytes;status.MetadataMatch=actual.Signature==entry.Signature;status.TypeMatch=actual.IsDirectory==entry.IsDirectory;
                            status.Recycled=status.BytesMatch&&status.MetadataMatch&&status.TypeMatch;
                            if(status.Recycled)status.ErrorMessage="";
                        }
                    }
                    catch{status.ErrorMessage="已回收但无法核实大小，未计成长";}
                }
                Results[entry.Id]=status;
                if(status.Recycled&&completed!=null)try{completed(status);}catch(Exception error){PersistenceFailure=error;return Abort;}
                return 0;
            }
            public int StartOperations(){return PersistenceFailure==null?0:Abort;}
            public int FinishOperations(int result){return 0;}
            public int PreRenameItem(uint f,IDropShellItem i,string n){return Abort;}
            public int PostRenameItem(uint f,IDropShellItem i,string n,int r,IDropShellItem c){return 0;}
            public int PreMoveItem(uint f,IDropShellItem i,IDropShellItem d,string n){return Abort;}
            public int PostMoveItem(uint f,IDropShellItem i,IDropShellItem d,string n,int r,IDropShellItem c){return 0;}
            public int PreCopyItem(uint f,IDropShellItem i,IDropShellItem d,string n){return Abort;}
            public int PostCopyItem(uint f,IDropShellItem i,IDropShellItem d,string n,int r,IDropShellItem c){return 0;}
            public int PreNewItem(uint f,IDropShellItem d,string n){return Abort;}
            public int PostNewItem(uint f,IDropShellItem d,string n,string t,uint a,int r,IDropShellItem c){return 0;}
            public int UpdateProgress(uint t,uint d){return PersistenceFailure==null?0:Abort;}
            public int ResetTimer(){return 0;}public int PauseTimer(){return 0;}public int ResumeTimer(){return 0;}
        }
        private static void Check(int hr){if(hr<0)Marshal.ThrowExceptionForHR(hr);}
        private static void Release(object value){if(value!=null&&Marshal.IsComObject(value))Marshal.ReleaseComObject(value);}
        [ComImport,Guid("947AAB5F-0A5C-4C13-B4D6-4BF7836FC9F8"),InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
        private interface IDropFileOperation
        {
            [PreserveSig]int Advise(IDropOperationSink sink,out uint cookie);[PreserveSig]int Unadvise(uint cookie);
            [PreserveSig]int SetOperationFlags(uint flags);[PreserveSig]int SetProgressMessage([MarshalAs(UnmanagedType.LPWStr)]string message);
            [PreserveSig]int SetProgressDialog([MarshalAs(UnmanagedType.Interface)]object dialog);[PreserveSig]int SetProperties([MarshalAs(UnmanagedType.Interface)]object properties);
            [PreserveSig]int SetOwnerWindow(IntPtr owner);[PreserveSig]int ApplyPropertiesToItem(IDropShellItem item);
            [PreserveSig]int ApplyPropertiesToItems([MarshalAs(UnmanagedType.IUnknown)]object items);
            [PreserveSig]int RenameItem(IDropShellItem item,[MarshalAs(UnmanagedType.LPWStr)]string name,IDropOperationSink sink);
            [PreserveSig]int RenameItems([MarshalAs(UnmanagedType.IUnknown)]object items,[MarshalAs(UnmanagedType.LPWStr)]string name);
            [PreserveSig]int MoveItem(IDropShellItem item,IDropShellItem destination,[MarshalAs(UnmanagedType.LPWStr)]string name,IDropOperationSink sink);
            [PreserveSig]int MoveItems([MarshalAs(UnmanagedType.IUnknown)]object items,IDropShellItem destination);
            [PreserveSig]int CopyItem(IDropShellItem item,IDropShellItem destination,[MarshalAs(UnmanagedType.LPWStr)]string name,IDropOperationSink sink);
            [PreserveSig]int CopyItems([MarshalAs(UnmanagedType.IUnknown)]object items,IDropShellItem destination);
            [PreserveSig]int DeleteItem(IDropShellItem item,IDropOperationSink sink);[PreserveSig]int DeleteItems([MarshalAs(UnmanagedType.IUnknown)]object items);
            [PreserveSig]int NewItem(IDropShellItem destination,uint attributes,[MarshalAs(UnmanagedType.LPWStr)]string name,[MarshalAs(UnmanagedType.LPWStr)]string template,IDropOperationSink sink);
            [PreserveSig]int PerformOperations();[PreserveSig]int GetAnyOperationsAborted([MarshalAs(UnmanagedType.Bool)]out bool aborted);
        }
        [DllImport("shell32.dll",CharSet=CharSet.Unicode)]private static extern int SHCreateItemFromParsingName(string path,IntPtr context,ref Guid iid,out IDropShellItem item);
    }
}
