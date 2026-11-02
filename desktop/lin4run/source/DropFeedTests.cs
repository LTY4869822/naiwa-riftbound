using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Web.Script.Serialization;

namespace NaiwaDesktop
{
    // All recycle calls here are fake list mutations. No Windows recycle adapter
    // is instantiated and no user file is moved, removed, or enumerated.
    internal static class DropFeedTests
    {
        private sealed class FakeStore:IFileDropStore
        {
            internal readonly List<DropEntry> Entries=new List<DropEntry>();
            internal readonly Dictionary<string,string> Outcomes=new Dictionary<string,string>();
            internal int Calls;
            internal bool DuplicateCallback,WrongIdentity;
            public DropPreview Preview(string[] paths){DropPreview p=new DropPreview();foreach(DropEntry e in Entries)p.Entries.Add(e.Copy());return p;}
            public List<DropResult> Recycle(IList<DropEntry> entries,IntPtr owner,Action<DropResult> completed)
            {
                Calls++;List<DropResult> results=new List<DropResult>();
                foreach(DropEntry entry in entries)
                {
                    string kind;if(!Outcomes.TryGetValue(entry.Id,out kind))kind="ok";
                    int hr=kind=="ok"?0:kind=="whole"||kind=="whole_noproof"||kind=="whole_cancel"?DropRecycleStatus.DontProcessChildren:kind=="skip"?1:kind=="ignored"?0x00270005:kind=="retry"?0x00270004:kind=="pending"?0x0027000B:kind=="already"?0x0027000A:unchecked((int)0x80004004);
                    DropResult r=new DropResult {Entry=entry.Copy(),Recycled=kind=="ok"||kind=="whole"||kind=="whole_cancel",Cancelled=kind=="cancel"||kind=="whole_cancel",HResult=hr};
                    // Deliberately dishonest positive claims exercise the service's
                    // explicit HRESULT allowlist rather than trusting Recycled alone.
                    if(kind=="skip"||kind=="ignored"||kind=="retry"||kind=="pending"||kind=="already")r.Recycled=true;
                    if(WrongIdentity)r.Entry.Bytes++;
                    if(r.Recycled&&!r.Cancelled&&DropRecycleStatus.IsCompleted(r.HResult))Entries.RemoveAll(e=>e.Id==entry.Id);
                    results.Add(r);if(completed!=null){completed(r);if(DuplicateCallback)completed(r);}
                }
                return results;
            }
        }
        private sealed class FaultWriter:IDropFeedWriter
        {
            private readonly DropFeedWriter actual=new DropFeedWriter();
            internal bool Probe,Intent,Receipt,Completed;
            public void WriteAtomic(string path,string json)
            {
                if(Probe&&path.EndsWith(".tmp",StringComparison.Ordinal))throw new IOException("injected probe failure");
                if(Intent&&json.Contains("\"state\":\"prepared\""))throw new IOException("injected intent failure");
                if(Receipt&&System.IO.Path.GetDirectoryName(path).EndsWith("receipts",StringComparison.Ordinal)&&path.EndsWith(".json",StringComparison.Ordinal))throw new IOException("injected receipt failure");
                if(Completed&&json.Contains("\"state\":\"completed\""))throw new IOException("injected completed marker failure");
                actual.WriteAtomic(path,json);
            }
        }
        private static readonly JavaScriptSerializer Json=new JavaScriptSerializer();
        private static List<string> lines;
        private static int failures;
        private static string run;
        private static DropEntry Entry(int n,long bytes,bool directory=false){return new DropEntry {Id=n.ToString("x64"),Path="fixture-only-item-"+n,Signature="fixture-signature-"+n,Bytes=bytes,IsDirectory=directory};}
        private static FakeStore Source(params DropEntry[] entries){FakeStore s=new FakeStore();s.Entries.AddRange(entries);return s;}
        private static string Folder(string label){string path=System.IO.Path.Combine(run,label);Directory.CreateDirectory(path);return path;}
        private static string[] Files(string folder){string path=System.IO.Path.Combine(folder,"receipts");return Directory.Exists(path)?Directory.GetFiles(path,"*.json"):new string[0];}
        private static bool Throws(Action action){try{action();return false;}catch{return true;}}
        private static void Check(bool ok,string title){lines.Add((ok?"PASS ":"FAIL ")+title);if(!ok)failures++;}
        private static void Journal(string folder,string id,object[] candidates,object[] successful,string state="operating")
        {
            new DropFeedWriter().WriteAtomic(System.IO.Path.Combine(folder,"drop-transactions",id+".json"),Json.Serialize(new Dictionary<string,object>{{"version",1},{"id",id},{"state",state},{"candidates",candidates},{"successful",successful}}));
        }
        private static object Record(string id,object bytes){return new Dictionary<string,object>{{"id",id},{"bytes",bytes}};}
        internal static void Run(string output)
        {
            string destination=System.IO.Path.GetFullPath(output);Directory.CreateDirectory(destination);
            run=System.IO.Path.Combine(destination,"run-"+Guid.NewGuid().ToString("N").Substring(0,8));Directory.CreateDirectory(run);lines=new List<string>();failures=0;
            try
            {
                string folder=Folder("success");FakeStore source=Source(Entry(1,8388608));DropFeedService service=new DropFeedService(source,folder);
                DropFeedOutcome result=service.Feed(new[]{"fixture"},IntPtr.Zero);
                string[] receipts=Files(folder);Dictionary<string,object> receipt=Json.Deserialize<Dictionary<string,object>>(File.ReadAllText(receipts[0]));
                Check(result.Items==1&&result.Bytes==8388608&&result.ReceiptSaved&&source.Calls==1,"one direct drop records the exact successfully recycled byte count");
                Check(Convert.ToInt32(receipt["version"])==1&&Convert.ToString(receipt["kind"])=="recycle_feed"&&Convert.ToString(receipt["id"]).Length==32&&Convert.ToInt64(receipt["completed_bytes"])==8388608,"receipt is compatible with the existing Godot protocol");
                Check(!File.ReadAllText(receipts[0]).Contains("fixture-only-item")&&!File.ReadAllText(System.IO.Path.Combine(folder,"drop-transactions",result.Id+".json")).Contains("fixture-only-item"),"receipts and recovery journals exclude names and paths");

                folder=Folder("empty");source=Source();service=new DropFeedService(source,folder);result=service.Feed(new string[0],IntPtr.Zero);
                Check(source.Calls==0&&Files(folder).Length==0&&result.Items==0,"an empty drop never invokes recycling or rewards");
                folder=Folder("zero");source=Source(Entry(2,0));service=new DropFeedService(source,folder);result=service.Feed(new[]{"zero"},IntPtr.Zero);
                Check(result.Items==1&&result.Bytes==0&&result.ReceiptSaved,"zero-byte items retain exact zero-byte growth");
                folder=Folder("partial");source=Source(Entry(3,10),Entry(4,100),Entry(5,1000));source.Outcomes[Entry(4,0).Id]="cancel";source.Outcomes[Entry(5,0).Id]="skip";
                service=new DropFeedService(source,folder);result=service.Feed(new[]{"partial"},IntPtr.Zero);
                Check(result.Items==1&&result.Bytes==10&&result.Skipped==2,"partial cancellation and nonzero skip HRESULTs never inflate growth");
                folder=Folder("cancel");source=Source(Entry(6,10));source.Outcomes[Entry(6,0).Id]="cancel";service=new DropFeedService(source,folder);result=service.Feed(new[]{"cancel"},IntPtr.Zero);
                Check(result.Items==0&&Files(folder).Length==0&&!service.HasPendingReward,"all-cancelled drops publish no reward");
                folder=Folder("negative");source=Source(Entry(7,-1));service=new DropFeedService(source,folder);
                Check(Throws(()=>service.Feed(new[]{"negative"},IntPtr.Zero))&&source.Calls==0,"negative sizes are refused before recycling");
                folder=Folder("duplicate");source=Source(Entry(8,1),Entry(8,1));service=new DropFeedService(source,folder);
                Check(Throws(()=>service.Feed(new[]{"duplicate"},IntPtr.Zero))&&source.Calls==0,"duplicate item identities are refused before recycling");
                folder=Folder("limit");source=Source(Entry(9,DropFeedService.MaxBatchBytes+1));service=new DropFeedService(source,folder);
                Check(Throws(()=>service.Feed(new[]{"oversize"},IntPtr.Zero))&&source.Calls==0,"over-limit logical size never reaches recycling");
                folder=Folder("count");source=Source();for(int i=1;i<=1001;i++)source.Entries.Add(Entry(i,0));service=new DropFeedService(source,folder);
                Check(Throws(()=>service.Feed(new[]{"too-many"},IntPtr.Zero))&&source.Calls==0,"more than 1000 dropped roots is refused");
                folder=Folder("identity");source=Source(Entry(10,10));source.WrongIdentity=true;service=new DropFeedService(source,folder);result=service.Feed(new[]{"changed"},IntPtr.Zero);
                Check(result.Items==0&&Files(folder).Length==0,"a callback with replacement metadata cannot earn growth");
                folder=Folder("probe");source=Source(Entry(11,10));FaultWriter writer=new FaultWriter {Probe=true};service=new DropFeedService(source,folder,writer);
                Check(Throws(()=>service.Feed(new[]{"probe"},IntPtr.Zero))&&source.Calls==0,"unwritable receipt preflight blocks all file operations");
                folder=Folder("intent");source=Source(Entry(12,10));writer=new FaultWriter {Intent=true};service=new DropFeedService(source,folder,writer);
                Check(Throws(()=>service.Feed(new[]{"intent"},IntPtr.Zero))&&source.Calls==0,"intent persistence failure blocks all file operations");
                folder=Folder("retry");source=Source(Entry(13,10));writer=new FaultWriter {Receipt=true};service=new DropFeedService(source,folder,writer);result=service.Feed(new[]{"retry"},IntPtr.Zero);
                Check(result.Items==1&&result.HasPendingReward&&!result.ReceiptSaved&&service.HasPendingReward,"confirmed movement is retained when receipt persistence fails");
                Check(Throws(()=>service.Feed(new[]{"another"},IntPtr.Zero))&&source.Calls==1,"pending growth blocks another drop without moving again");
                writer.Receipt=false;
                Check(service.RetryPendingReward()&&source.Calls==1&&Files(folder).Length==1&&!service.HasPendingReward,"retry saves the result without repeating recycling");
                folder=Folder("recover");source=Source(Entry(14,10));writer=new FaultWriter {Receipt=true};service=new DropFeedService(source,folder,writer);service.Feed(new[]{"recover"},IntPtr.Zero);
                FakeStore recoveryStore=Source();DropFeedService restarted=new DropFeedService(recoveryStore,folder);
                Check(restarted.RecoverConfirmedRewards()==1&&recoveryStore.Calls==0&&Files(folder).Length==1,"restart recovers durable confirmed success without recycling");
                string before=File.ReadAllText(Files(folder)[0]);
                Check(restarted.RecoverConfirmedRewards()==0&&File.ReadAllText(Files(folder)[0])==before,"completed recovery is idempotent and leaves immutable receipts intact");
                folder=Folder("unknown");string batch=new string('a',32);Journal(folder,batch,new[]{Record(Entry(15,0).Id,10)},new object[0]);restarted=new DropFeedService(Source(),folder);
                Check(restarted.RecoverConfirmedRewards()==0&&Files(folder).Length==0,"an intent and missing source never imply success");
                folder=Folder("outside");Journal(folder,batch,new[]{Record(Entry(16,0).Id,10)},new[]{Record(Entry(17,0).Id,10)});restarted=new DropFeedService(Source(),folder);
                Check(restarted.RecoverConfirmedRewards()==0&&Files(folder).Length==0,"recovery rejects success outside the recorded selection");
                folder=Folder("fractional");Journal(folder,batch,new[]{Record(Entry(18,0).Id,1.5)},new[]{Record(Entry(18,0).Id,1.5)});restarted=new DropFeedService(Source(),folder);
                Check(restarted.RecoverConfirmedRewards()==0&&Files(folder).Length==0,"recovery rejects fractional byte counts");
                folder=Folder("traversal");Journal(folder,batch,new[]{Record(Entry(19,0).Id,10)},new[]{Record(Entry(19,0).Id,10)});string file=System.IO.Path.Combine(folder,"drop-transactions",batch+".json");
                Dictionary<string,object> bad=Json.Deserialize<Dictionary<string,object>>(File.ReadAllText(file));bad["id"]="../escape";File.WriteAllText(file,Json.Serialize(bad));restarted=new DropFeedService(Source(),folder);
                Check(restarted.RecoverConfirmedRewards()==0&&Files(folder).Length==0&&!File.Exists(System.IO.Path.Combine(folder,"escape.json")),"recovery identifiers cannot escape the receipt directory");
                folder=Folder("marker");source=Source(Entry(20,10));writer=new FaultWriter {Completed=true};service=new DropFeedService(source,folder,writer);result=service.Feed(new[]{"marker"},IntPtr.Zero);
                Check(result.ReceiptSaved&&result.HasPendingReward&&Files(folder).Length==1,"a published receipt remains successful if only bookkeeping fails");
                string published=File.ReadAllText(Files(folder)[0]);writer.Completed=false;
                Check(service.RetryPendingReward()&&source.Calls==1&&File.ReadAllText(Files(folder)[0])==published,"published receipt retry completes bookkeeping without republishing");
                folder=Folder("none-marker");source=Source(Entry(21,10));source.Outcomes[Entry(21,0).Id]="cancel";writer=new FaultWriter {Completed=true};service=new DropFeedService(source,folder,writer);service.Feed(new[]{"cancel"},IntPtr.Zero);
                Check(!service.HasPendingReward,"zero-success bookkeeping failure cannot trap future drops");
                folder=Folder("doublecallback");source=Source(Entry(22,10,true));source.DuplicateCallback=true;service=new DropFeedService(source,folder);result=service.Feed(new[]{"folder"},IntPtr.Zero);
                Check(result.Items==1&&result.Bytes==10&&Files(folder).Length==1,"folder roots and duplicate callbacks are counted once");
                folder=Folder("whole-item");source=Source(Entry(23,8388608));source.Outcomes[Entry(23,0).Id]="whole";service=new DropFeedService(source,folder);result=service.Feed(new[]{"whole"},IntPtr.Zero);
                Check(result.Items==1&&result.Bytes==8388608&&result.ReceiptSaved,"SDK COPYENGINE_S_DONT_PROCESS_CHILDREN with verified recycling earns exact bytes");
                foreach(string kind in new[]{"ignored","retry","pending","already"})
                {
                    folder=Folder("positive-"+kind);source=Source(Entry(24,10));source.Outcomes[Entry(24,0).Id]=kind;service=new DropFeedService(source,folder);result=service.Feed(new[]{kind},IntPtr.Zero);
                    Check(result.Items==0&&Files(folder).Length==0,"SDK positive "+kind+" status cannot masquerade as completed recycling");
                }
                folder=Folder("whole-noproof");source=Source(Entry(25,10));source.Outcomes[Entry(25,0).Id]="whole_noproof";service=new DropFeedService(source,folder);result=service.Feed(new[]{"whole_noproof"},IntPtr.Zero);
                Check(result.Items==0&&Files(folder).Length==0,"known whole-item HRESULT without verified recycled-item proof earns nothing");
                folder=Folder("whole-cancel");source=Source(Entry(26,10));source.Outcomes[Entry(26,0).Id]="whole_cancel";service=new DropFeedService(source,folder);result=service.Feed(new[]{"whole_cancel"},IntPtr.Zero);
                Check(result.Items==0&&Files(folder).Length==0,"a cancelled result cannot earn growth even with a known whole-item HRESULT");
                folder=Folder("whole-identity");source=Source(Entry(27,10));source.Outcomes[Entry(27,0).Id]="whole";source.WrongIdentity=true;service=new DropFeedService(source,folder);result=service.Feed(new[]{"whole-identity"},IntPtr.Zero);
                Check(result.Items==0&&Files(folder).Length==0,"whole-item success still rejects replacement byte metadata");
            }
            catch(Exception error){Check(false,"unexpected test exception: "+error);}
            lines.Add("Failures="+failures);lines.Add("Fake stores only. No real Windows recycle adapter or user files were used.");
            File.WriteAllLines(System.IO.Path.Combine(destination,"drop-feed-tests.txt"),lines.ToArray(),new UTF8Encoding(false));
            Environment.ExitCode=failures==0?0:1;
        }
    }
}
