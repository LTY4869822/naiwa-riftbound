using System;
using System.Collections;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;
using System.Web.Script.Serialization;

namespace NaiwaDesktop
{
    internal interface IDropFeedWriter { void WriteAtomic(string path,string json); }
    internal sealed class DropFeedWriter:IDropFeedWriter
    {
        public void WriteAtomic(string path,string json)
        {
            Directory.CreateDirectory(System.IO.Path.GetDirectoryName(path));
            string temporary=System.IO.Path.Combine(System.IO.Path.GetDirectoryName(path),"write-"+Guid.NewGuid().ToString("N")+".tmp");
            try
            {
                byte[] bytes=new UTF8Encoding(false).GetBytes(json);
                using(FileStream file=new FileStream(temporary,FileMode.CreateNew,FileAccess.Write,FileShare.None,4096,FileOptions.WriteThrough)){file.Write(bytes,0,bytes.Length);file.Flush(true);}
                if(File.Exists(path))File.Replace(temporary,path,path+".bak",true);else File.Move(temporary,path);
            }
            finally{if(File.Exists(temporary))File.Delete(temporary);}
        }
    }
    internal sealed class DropFeedOutcome
    {
        internal string Id="",ErrorMessage="";
        internal int Items,Skipped;
        internal long Bytes;
        internal bool ReceiptSaved,HasPendingReward;
        internal readonly List<DropResult> Results=new List<DropResult>();
    }
    internal sealed class DropFeedService
    {
        internal const long MaxBatchBytes=32L*1024*1024*1024;
        internal const int MaxBatchItems=1000;
        private readonly IFileDropStore store;
        private readonly IDropFeedWriter writer;
        private readonly string root;
        private readonly JavaScriptSerializer json=new JavaScriptSerializer { MaxJsonLength=256*1024 };
        private string id,state;
        private List<DropEntry> pending;
        private readonly Dictionary<string,DropEntry> successes=new Dictionary<string,DropEntry>(StringComparer.Ordinal);
        private bool receiptPublished;
        internal bool HasPendingReward {get{return pending!=null&&successes.Count>0;}}
        internal string ReceiptRoot {get{return System.IO.Path.Combine(root,"receipts");}}
        internal DropFeedService(IFileDropStore source,string dataRoot,IDropFeedWriter persistence=null)
        {
            if(source==null||String.IsNullOrWhiteSpace(dataRoot))throw new ArgumentException("缺少文件投喂服务或数据目录");
            store=source;root=System.IO.Path.GetFullPath(dataRoot);writer=persistence??new DropFeedWriter();
        }
        // Call on a background STA. The drop gesture itself is the user's selection;
        // there is no classification, list, or additional permanent-delete control.
        internal DropFeedOutcome Feed(string[] paths,IntPtr owner)
        {
            if(pending!=null)throw new InvalidOperationException("上次成长尚未保存，请先重试保存");
            DropPreview preview=store.Preview(paths);
            DropFeedOutcome outcome=new DropFeedOutcome {Skipped=preview.Messages.Count};
            if(preview.Entries.Count==0){outcome.ErrorMessage=preview.Messages.Count>0?preview.Messages[0]:"没有收到可投喂的文件";return outcome;}
            List<DropEntry> entries=ValidateAndCopy(preview.Entries);
            string batch=Guid.NewGuid().ToString("N");outcome.Id=batch;
            // Durable intent and a writable receipt destination must precede recycling.
            Directory.CreateDirectory(ReceiptRoot);
            string probe=System.IO.Path.Combine(ReceiptRoot,"write-check-"+batch+".tmp");
            writer.WriteAtomic(probe,"{\"write_check\":true}");if(File.Exists(probe))File.Delete(probe);
            id=batch;pending=entries;successes.Clear();receiptPublished=false;state="prepared";
            try{SaveJournal();state="operating";SaveJournal();}
            catch{pending=null;throw;}
            try
            {
                List<DropResult> results=store.Recycle(entries,owner,delegate(DropResult result){Accept(result);SaveJournal();});
                if(results!=null)outcome.Results.AddRange(results);
                foreach(DropResult result in outcome.Results)Accept(result);
            }
            catch(Exception error){outcome.ErrorMessage="部分文件未完成投喂："+error.Message;}
            foreach(DropEntry entry in successes.Values){outcome.Items++;outcome.Bytes+=entry.Bytes;}
            outcome.Skipped+=Math.Max(0,entries.Count-outcome.Items);
            try{Finish();outcome.ReceiptSaved=outcome.Items>0;}
            catch(Exception error)
            {
                outcome.ReceiptSaved=receiptPublished;outcome.HasPendingReward=HasPendingReward;
                outcome.ErrorMessage=outcome.Items>0?"已回收文件，成长暂未保存完整；可重试保存，不会再次回收。 "+error.Message:"本次没有确认成功的投喂，未发放成长。";
            }
            if(String.IsNullOrEmpty(outcome.ErrorMessage)&&outcome.Skipped>0)outcome.ErrorMessage="部分项目已跳过；仅成功回收的大小计入成长";
            return outcome;
        }
        private static List<DropEntry> ValidateAndCopy(IList<DropEntry> entries)
        {
            if(entries==null||entries.Count<1||entries.Count>MaxBatchItems)throw new InvalidDataException("投喂项目数量无效");
            List<DropEntry> copy=new List<DropEntry>();HashSet<string> ids=new HashSet<string>(StringComparer.Ordinal);long bytes=0;
            foreach(DropEntry entry in entries)
            {
                if(entry==null||!Hex(entry.Id,64)||!ids.Add(entry.Id)||entry.Bytes<0||entry.Bytes>MaxBatchBytes||bytes>MaxBatchBytes-entry.Bytes)throw new InvalidDataException("投喂项目大小或身份无效");
                if(String.IsNullOrEmpty(entry.Path)||String.IsNullOrEmpty(entry.Signature))throw new InvalidDataException("缺少已核对的文件快照");
                bytes+=entry.Bytes;copy.Add(entry.Copy());
            }
            return copy;
        }
        private void Accept(DropResult result)
        {
            if(result==null||!result.Recycled||result.Cancelled||!DropRecycleStatus.IsCompleted(result.HResult)||result.Entry==null||pending==null)return;
            foreach(DropEntry expected in pending)if(expected.Id==result.Entry.Id&&expected.Bytes==result.Entry.Bytes&&expected.Path==result.Entry.Path&&expected.Signature==result.Entry.Signature&&expected.IsDirectory==result.Entry.IsDirectory)
            {successes[expected.Id]=expected;return;}
        }
        internal bool RetryPendingReward(){if(pending==null)return true;try{Finish();return true;}catch{return false;}}
        private object[] Records(IEnumerable<DropEntry> entries)
        {
            List<object> result=new List<object>();foreach(DropEntry entry in entries)result.Add(new Dictionary<string,object>{{"id",entry.Id},{"bytes",entry.Bytes}});return result.ToArray();
        }
        private void SaveJournal()
        {
            writer.WriteAtomic(System.IO.Path.Combine(root,"drop-transactions",id+".json"),json.Serialize(new Dictionary<string,object>{{"version",1},{"id",id},{"state",state},{"updated_utc",DateTime.UtcNow.ToString("o",CultureInfo.InvariantCulture)},{"receipt_published",receiptPublished},{"candidates",Records(pending)},{"successful",Records(successes.Values)}}));
        }
        private void Finish()
        {
            if(pending==null)return;
            if(successes.Count==0)
            {
                state="completed";try{SaveJournal();}finally{pending=null;successes.Clear();receiptPublished=false;}return;
            }
            if(!receiptPublished){SaveJournal();Publish(id,successes.Values);receiptPublished=true;}
            state="completed";SaveJournal();pending=null;successes.Clear();receiptPublished=false;
        }
        private void Publish(string batch,IEnumerable<DropEntry> entries)
        {
            object[] records=Records(entries);long bytes=0;foreach(DropEntry entry in entries)bytes+=entry.Bytes;
            if(records.Length==0)return;
            string path=System.IO.Path.Combine(ReceiptRoot,batch+".json");
            if(File.Exists(path))
            {
                Dictionary<string,object> existing=Read(path);
                if(Convert.ToString(existing["id"])!=batch||Convert.ToString(existing["kind"])!="recycle_feed"||Integer(existing["completed_bytes"])!=bytes||json.Serialize(existing["items"])!=json.Serialize(records))throw new InvalidDataException("成长记录冲突，停止覆盖");
                return;
            }
            writer.WriteAtomic(path,json.Serialize(new Dictionary<string,object>{{"version",1},{"id",batch},{"kind","recycle_feed"},{"completed_utc",DateTime.UtcNow.ToString("o",CultureInfo.InvariantCulture)},{"items",records},{"completed_bytes",bytes}}));
        }
        internal int RecoverConfirmedRewards()
        {
            if(pending!=null)return 0;
            string directory=System.IO.Path.Combine(root,"drop-transactions");if(!Directory.Exists(directory))return 0;
            int recovered=0;
            foreach(string path in Directory.GetFiles(directory,"*.json"))
            {
                try
                {
                    Dictionary<string,object> data=Read(path);string batch=Convert.ToString(data["id"]),status=Convert.ToString(data["state"]);
                    if(!Hex(batch,32)||System.IO.Path.GetFileName(path)!=batch+".json"||Integer(data["version"])!=1||(status!="prepared"&&status!="operating"))continue;
                    List<DropEntry> candidates=Parse(data["candidates"]),known=Parse(data["successful"]);
                    foreach(DropEntry item in known)if(!candidates.Exists(candidate=>candidate.Id==item.Id&&candidate.Bytes==item.Bytes))throw new InvalidDataException("成功项不属于投喂意图");
                    if(known.Count>0){Publish(batch,known);recovered+=known.Count;}
                    data["state"]="completed";data["unverified_items_not_rewarded"]=true;writer.WriteAtomic(path,json.Serialize(data));
                }
                catch{/* Disappearance without a durable success record never earns growth. */}
            }
            return recovered;
        }
        private Dictionary<string,object> Read(string path)
        {
            if(new FileInfo(path).Length>256*1024)throw new InvalidDataException("成长记录过大");
            Dictionary<string,object> value=json.Deserialize<Dictionary<string,object>>(File.ReadAllText(path));if(value==null)throw new InvalidDataException("成长记录无效");return value;
        }
        private static List<DropEntry> Parse(object raw)
        {
            IEnumerable records=raw as IEnumerable;if(records==null||raw is string)throw new InvalidDataException("成长记录无效");
            List<DropEntry> result=new List<DropEntry>();HashSet<string> seen=new HashSet<string>(StringComparer.Ordinal);long total=0;
            foreach(object value in records)
            {
                Dictionary<string,object> item=value as Dictionary<string,object>;if(item==null)throw new InvalidDataException("成长项目无效");
                string key=Convert.ToString(item["id"]);long bytes=Integer(item["bytes"]);
                if(!Hex(key,64)||!seen.Add(key)||bytes>MaxBatchBytes||total>MaxBatchBytes-bytes||result.Count>=MaxBatchItems)throw new InvalidDataException("成长项目无效");
                total+=bytes;result.Add(new DropEntry{Id=key,Bytes=bytes});
            }
            return result;
        }
        private static long Integer(object value)
        {
            if(!(value is Int32)&&!(value is Int64)&&!(value is Decimal)&&!(value is Double)&&!(value is Single))throw new InvalidDataException("需要整数字节数");
            decimal number=Convert.ToDecimal(value,CultureInfo.InvariantCulture);if(number<0||number>MaxBatchBytes||Decimal.Truncate(number)!=number)throw new InvalidDataException("字节数无效");return Decimal.ToInt64(number);
        }
        private static bool Hex(string value,int length){return value!=null&&Regex.IsMatch(value,"\\A[0-9a-f]{"+length+"}\\z");}
    }
}
