using System;
using System.Collections.Generic;
using System.IO;
using System.Security.Cryptography;
using System.Text;
using System.Web.Script.Serialization;

namespace NaiwaDesktop
{
    // The production service references this default only in UI code. The fixture
    // intentionally makes that default inaccessible and always supplies its own root.
    internal static class Settings
    {
        internal static string Folder { get { throw new InvalidOperationException("A protocol fixture must not resolve the real user folder"); } }
    }

    internal static class RecycleProtocolFixture
    {
        private const long Unit = 8L * 1024 * 1024;
        private static readonly JavaScriptSerializer Json = new JavaScriptSerializer { MaxJsonLength = 16 * 1024 * 1024 };

        private sealed class FakeStore : IRecycleBinStore
        {
            internal readonly List<RecycleEntry> Entries = new List<RecycleEntry>();
            internal readonly Dictionary<string, string> Outcomes = new Dictionary<string, string>();
            internal int DeleteCalls, Successful;
            public IntPtr OwnerWindow { get; set; }
            public List<RecycleEntry> Scan() { return new List<RecycleEntry>(Entries); }
            public List<RecycleDeleteResult> DeleteSelected(IList<RecycleEntry> selected, Action<RecycleDeleteResult> completed)
            {
                DeleteCalls++;
                List<RecycleDeleteResult> results = new List<RecycleDeleteResult>();
                foreach (RecycleEntry entry in selected)
                {
                    string outcome;
                    if (!Outcomes.TryGetValue(entry.Id, out outcome)) outcome = "success";
                    bool success = outcome == "success";
                    RecycleDeleteResult result = new RecycleDeleteResult
                    {
                        Entry = entry, Deleted = success, Cancelled = outcome == "cancel",
                        HResult = success ? 0 : outcome == "cancel" ? unchecked((int)0x80004004) : unchecked((int)0x80070005),
                        ErrorMessage = success ? "" : "Injected fixture result"
                    };
                    if (success) { Entries.RemoveAll(delegate(RecycleEntry item) { return item.Id == entry.Id; }); Successful++; }
                    results.Add(result);
                    if (completed != null) completed(result);
                }
                return results;
            }
        }

        [STAThread]
        private static int Main(string[] args)
        {
            try
            {
                if (args.Length != 2 || (args[0] != "--produce" && args[0] != "--verify")) throw new ArgumentException("Use --produce|--verify <fixture-root>");
                string root = Path.GetFullPath(args[1]).TrimEnd(Path.DirectorySeparatorChar);
                string executableRoot = Path.GetFullPath(AppDomain.CurrentDomain.BaseDirectory).TrimEnd(Path.DirectorySeparatorChar);
                if (!String.Equals(root, executableRoot, StringComparison.OrdinalIgnoreCase)) throw new InvalidOperationException("Fixture root must be the executable's unique workspace directory");
                if (args[0] == "--produce") Produce(root); else Verify(root);
                return 0;
            }
            catch (Exception error) { Console.Error.WriteLine("FAIL " + error); return 1; }
        }

        private static RecycleEntry Entry(string name, long bytes)
        {
            string id;
            using (SHA256 hash = SHA256.Create()) id = BitConverter.ToString(hash.ComputeHash(Encoding.UTF8.GetBytes("isolated-protocol-fixture:" + name))).Replace("-", "").ToLowerInvariant();
            return new RecycleEntry
            {
                Id = id, DisplayName = name + ".fixture", OriginalLocation = "fixture-only-no-real-path",
                ShellParsingName = "fixture-item:" + id, DeletedAtUtc = new DateTime(2026, 10, 28, 6, 0, 0, DateTimeKind.Utc),
                SizeBytes = bytes, IsDirectory = false, IsSupported = true, UnavailableReason = ""
            };
        }

        private static void Assert(bool condition, string title)
        {
            if (!condition) throw new InvalidOperationException(title);
            Console.WriteLine("PASS " + title);
        }

        private static void Produce(string root)
        {
            FakeStore store = new FakeStore();
            RecycleFeedService service = new RecycleFeedService(store, Path.Combine(root, "native"));
            List<object> phases = new List<object>();
            long[] amounts = { Unit, Unit / 2, Unit / 2, Unit * 58, Unit };
            string[] names = { "one_xp", "half_unit", "carried_unit", "reach_level_two", "partial_success" };
            for (int index = 0; index < amounts.Length; index++)
            {
                store.Entries.Clear(); store.Outcomes.Clear();
                store.Entries.Add(Entry(names[index], amounts[index]));
                if (index == 4)
                {
                    RecycleEntry cancelled = Entry("cancelled_not_rewarded", Unit);
                    RecycleEntry failed = Entry("failed_not_rewarded", Unit * 2);
                    store.Entries.Add(cancelled); store.Entries.Add(failed);
                    store.Outcomes[cancelled.Id] = "cancel"; store.Outcomes[failed.Id] = "fail";
                }
                PreparedRecycleFeed preview = service.Prepare(store.Scan());
                RecycleFeedOutcome outcome = service.Commit(preview, true, IntPtr.Zero);
                Assert(outcome.ReceiptSaved && outcome.Items == 1 && outcome.Bytes == amounts[index], "production service publishes only verified fixture successes: " + names[index]);
                string receiptFile = outcome.Id + ".json";
                string contents = File.ReadAllText(Path.Combine(service.ReceiptRoot, receiptFile));
                Assert(!contents.Contains("fixture-only-no-real-path") && !contents.Contains(".fixture"), "receipt excludes fixture file names and original paths: " + names[index]);
                phases.Add(new Dictionary<string, object> { { "name", names[index] }, { "receipt_file", receiptFile }, { "bytes", amounts[index] } });
            }
            Assert(store.DeleteCalls == 5 && store.Successful == 5, "all native deletion calls were fake list mutations");
            RecycleGrowth pending = service.ReadGrowth(Path.Combine(root, "game-profile.json"));
            Assert(pending.PendingXp == 61 && pending.ProjectedLevel == 2 && pending.ProjectedXp == 1, "native pending forecast agrees with the existing level curve");
            Dictionary<string, object> manifest = new Dictionary<string, object>
            {
                { "version", 1 }, { "kind", "isolated_recycle_protocol_fixture" }, { "phases", phases.ToArray() },
                { "expected_bytes", Unit * 61 }, { "expected_xp", 61 }, { "expected_items", 5 },
                { "native_delete_calls", store.DeleteCalls }, { "native_successful_fake_items", store.Successful },
                { "real_windows_store_created", false }
            };
            File.WriteAllText(Path.Combine(root, "manifest.json"), Json.Serialize(manifest), new UTF8Encoding(false));
        }

        private static void Verify(string root)
        {
            RecycleFeedService service = new RecycleFeedService(new FakeStore(), Path.Combine(root, "native"));
            RecycleGrowth growth = service.ReadGrowth(Path.Combine(root, "game-profile.json"));
            Assert(growth.Error.Length == 0 && growth.Level == 2 && growth.Xp == 1, "native reader reloads the Godot-written version-two profile");
            Assert(growth.TotalBytes == Unit * 61 && growth.TotalXp == 61 && growth.TotalItems == 5 && growth.RemainderBytes == 0, "native reader agrees with imported cumulative statistics");
            Assert(growth.PendingItems == 0 && growth.PendingBytes == 0 && growth.PendingXp == 0, "Godot receipt and item ledgers acknowledge every native receipt");
            Assert(growth.ProjectedLevel == growth.Level && growth.ProjectedXp == growth.Xp, "reopening native growth does not preview duplicate XP");
        }
    }
}
