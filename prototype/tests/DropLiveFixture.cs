using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Text;
using System.Web.Script.Serialization;

namespace NaiwaDesktop
{
    // Deliberately separate from automated/fake tests. Running this executable is
    // an explicit live test: only its newly created, marked workspace payload is
    // moved to the Recycle Bin. It accepts no source path or output path argument.
    internal static class DropLiveFixture
    {
        private const long PayloadBytes=8L*1024*1024;
        [STAThread]
        private static int Main(string[] args)
        {
            string reportPath=null;
            Dictionary<string,object> report=new Dictionary<string,object>();
            try
            {
                bool folder=args.Length==1&&args[0]=="--folder";
                if(args.Length!=0&&!folder)throw new ArgumentException("No arbitrary file paths are accepted. Run with no arguments, or --folder.");
                string workspace=DiscoverWorkspace();AssertNoReparseAncestors(workspace);
                string nonce=Guid.NewGuid().ToString("N");
                string fixtureBase=System.IO.Path.Combine(workspace,".drop-integration-fixtures");
                Directory.CreateDirectory(fixtureBase);AssertNoReparseAncestors(fixtureBase);
                string fixture=System.IO.Path.Combine(fixtureBase,nonce);
                if(Directory.Exists(fixture)||File.Exists(fixture))throw new IOException("The live fixture must be a new directory");
                Directory.CreateDirectory(fixture);
                string marker=System.IO.Path.Combine(fixture,"fixture-owned-by-this-test.txt");
                using(FileStream file=new FileStream(marker,FileMode.CreateNew,FileAccess.Write,FileShare.None))
                {byte[] text=new UTF8Encoding(false).GetBytes("Naiwa live recycle fixture only\n"+nonce+"\n");file.Write(text,0,text.Length);file.Flush(true);}
                string name="NaiwaDropFixture_"+nonce+(folder?"":".bin");
                string source=System.IO.Path.Combine(fixture,name);
                if(folder)
                {
                    Directory.CreateDirectory(source);Directory.CreateDirectory(System.IO.Path.Combine(source,"empty-child"));
                    CreateNewPayload(System.IO.Path.Combine(source,"part-a.bin"),PayloadBytes/2);
                    CreateNewPayload(System.IO.Path.Combine(source,"part-b.bin"),PayloadBytes/2);
                }
                else CreateNewPayload(source,PayloadBytes);
                // Source is never obtained from user input or a directory listing.
                if(System.IO.Path.GetDirectoryName(source)!=fixture||!File.Exists(marker)||!File.ReadAllText(marker).Contains(nonce))throw new IOException("Fixture ownership check failed");
                AssertNoReparseAncestors(source);
                string output=System.IO.Path.Combine(workspace,"file-feeder","prototype","artifacts","drop-live",nonce);
                Directory.CreateDirectory(output);reportPath=System.IO.Path.Combine(output,"result.json");
                report["fixture_name"]=name;report["fixture_directory"]=fixture;report["is_directory"]=folder;report["expected_bytes"]=PayloadBytes;
                report["receipt_root"]=System.IO.Path.Combine(output,"native","receipts");
                report["scope"]="Only the newly created marked fixture payload; no arbitrary paths accepted";
                WindowsFileDropStore store=new WindowsFileDropStore(System.IO.Path.Combine(workspace,"file-feeder"));
                DropPreview preview=store.Preview(new[]{source});
                if(preview.Entries.Count!=1||preview.Entries[0].Path!=source||preview.Entries[0].Bytes!=PayloadBytes)throw new IOException("Fixture preview was not exact: "+String.Join(";",preview.Messages.ToArray()));
                report["preview_exact"]=true;
                DropFeedService service=new DropFeedService(store,System.IO.Path.Combine(output,"native"));
                // This is the only operation that moves a file. A private, fresh,
                // explicitly marked payload is the sole source in the gesture.
                DropFeedOutcome result=service.Feed(new[]{source},IntPtr.Zero);
                report["completed_items"]=result.Items;report["completed_bytes"]=result.Bytes;
                report["receipt_saved"]=result.ReceiptSaved;report["pending_reward"]=result.HasPendingReward;report["error"]=result.ErrorMessage;
                report["source_absent"]=!File.Exists(source)&&!Directory.Exists(source);
                List<object> statuses=new List<object>();
                foreach(DropResult item in result.Results)statuses.Add(new Dictionary<string,object>{{"hresult",item.HResult.ToString("X8",CultureInfo.InvariantCulture)},{"pre_flags",item.PreDeleteFlags.ToString("X8",CultureInfo.InvariantCulture)},{"post_flags",item.PostDeleteFlags.ToString("X8",CultureInfo.InvariantCulture)},{"created_present",item.CreatedItemPresent},{"recycle_path_verified",item.RecyclePathVerified},{"source_absent",item.SourceAbsent},{"bytes_match",item.BytesMatch},{"metadata_signature_match",item.MetadataMatch},{"type_match",item.TypeMatch},{"recycled",item.Recycled},{"cancelled",item.Cancelled},{"error",item.ErrorMessage}});
                report["native_results"]=statuses.ToArray();
                Dictionary<string,object> bin=FindOwnRecycledFixture(name,fixture,folder,PayloadBytes);
                report["read_only_recycle_bin_check"]=bin;
                bool present=Convert.ToBoolean(bin["found"]);
                bool passed=result.Items==1&&result.Bytes==PayloadBytes&&result.ReceiptSaved&&!result.HasPendingReward&&present&&Convert.ToBoolean(report["source_absent"]);
                report["status"]=passed?"PASS":"FAIL";
                report["fixture_left_in_recycle_bin_for_manual_restore"]=present;
                report["real_user_files_touched"]=false;
                WriteReport(reportPath,report);
                Console.WriteLine((passed?"PASS":"FAIL")+" Live owned fixture recycle: "+name);
                Console.WriteLine("Report: "+reportPath);
                return passed?0:1;
            }
            catch(Exception error)
            {
                report["status"]="FAIL";report["error"]=error.ToString();
                if(reportPath!=null)try{WriteReport(reportPath,report);}catch{}
                Console.Error.WriteLine(error);return 1;
            }
        }
        private static void CreateNewPayload(string path,long bytes)
        {
            using(FileStream stream=new FileStream(path,FileMode.CreateNew,FileAccess.Write,FileShare.None)){stream.SetLength(bytes);stream.Flush(true);}
        }
        private static string DiscoverWorkspace()
        {
            string directory=System.IO.Path.GetFullPath(AppDomain.CurrentDomain.BaseDirectory).TrimEnd('\\','/');
            while(!String.IsNullOrEmpty(directory))
            {
                if(File.Exists(System.IO.Path.Combine(directory,"file-feeder","prototype","project.godot"))&&Directory.Exists(System.IO.Path.Combine(directory,".git")))return directory;
                directory=System.IO.Path.GetDirectoryName(directory);
            }
            throw new IOException("Run the fixture executable from this task's workspace");
        }
        private static void AssertNoReparseAncestors(string path)
        {
            string cursor=System.IO.Path.GetFullPath(path);
            while(!String.IsNullOrEmpty(cursor))
            {
                if((File.GetAttributes(cursor)&FileAttributes.ReparsePoint)!=0)throw new IOException("Fixture paths must not traverse reparse points");
                cursor=System.IO.Path.GetDirectoryName(cursor);
            }
        }
        private static Dictionary<string,object> FindOwnRecycledFixture(string name,string original,bool folder,long bytes)
        {
            Dictionary<string,object> result=new Dictionary<string,object>{{"found",false},{"matches",0},{"original_location_matches",false},{"ordinary_file_size_matches",folder}};
            object shell=null,bin=null,items=null;
            try
            {
                shell=Activator.CreateInstance(Type.GetTypeFromProgID("Shell.Application",true));
                bin=Call(shell,"NameSpace",new object[]{10});items=Call(bin,"Items",new object[0]);
                int count=Convert.ToInt32(Get(items,"Count"),CultureInfo.InvariantCulture),matches=0;
                for(int index=0;index<count;index++)
                {
                    object item=null;
                    try
                    {
                        item=Call(items,"Item",new object[]{index});
                        string from=Convert.ToString(Call(item,"ExtendedProperty",new object[]{"System.Recycle.DeletedFrom"}),CultureInfo.InvariantCulture);
                        if(!String.Equals(from.TrimEnd('\\','/'),original.TrimEnd('\\','/'),StringComparison.OrdinalIgnoreCase))continue;
                        string actual=Convert.ToString(Call(item,"ExtendedProperty",new object[]{"System.FileName"}),CultureInfo.InvariantCulture);
                        string display=Convert.ToString(Get(item,"Name"),CultureInfo.InvariantCulture);
                        bool nameMatches=String.Equals(actual,name,StringComparison.OrdinalIgnoreCase)||String.Equals(display,name,StringComparison.OrdinalIgnoreCase)||(!folder&&String.Equals(display,System.IO.Path.GetFileNameWithoutExtension(name),StringComparison.OrdinalIgnoreCase));
                        if(!nameMatches)continue;
                        matches++;result["original_location_matches"]=true;
                        if(!folder)
                        {
                            object size=Call(item,"ExtendedProperty",new object[]{"System.Size"});
                            result["ordinary_file_size_matches"]=size!=null&&Convert.ToInt64(size,CultureInfo.InvariantCulture)==bytes;
                        }
                    }
                    finally{Release(item);}
                }
                result["matches"]=matches;result["found"]=matches==1&&Convert.ToBoolean(result["ordinary_file_size_matches"]);return result;
            }
            finally{Release(items);Release(bin);Release(shell);}
        }
        private static object Call(object value,string member,object[] args){return value.GetType().InvokeMember(member,BindingFlags.InvokeMethod,null,value,args,CultureInfo.InvariantCulture);}
        private static object Get(object value,string member){return value.GetType().InvokeMember(member,BindingFlags.GetProperty,null,value,null,CultureInfo.InvariantCulture);}
        private static void Release(object value){if(value!=null&&Marshal.IsComObject(value))Marshal.ReleaseComObject(value);}
        private static void WriteReport(string path,object report){File.WriteAllText(path,new JavaScriptSerializer().Serialize(report),new UTF8Encoding(false));}
    }
}
