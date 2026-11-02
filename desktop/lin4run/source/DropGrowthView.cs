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
    internal sealed class DropGrowthSnapshot
    {
        internal int Level = 1;
        internal long TotalBytes, CurrentBytes, PendingBytes;
        internal long LevelBytes = 60L * 8 * 1024 * 1024;
        internal long BytesToNextLevel = 60L * 8 * 1024 * 1024;
        internal string Error = "";
    }

    // A read-only projection of the game's one shared level. Successful receipts
    // count immediately here, while Godot remains the sole profile writer.
    internal sealed class DropGrowthView
    {
        private const long Unit = 8L * 1024 * 1024;
        private const long MaxBatch = 32L * 1024 * 1024 * 1024;
        private const long MaxJsonInteger = 9007199254740991L;
        private const int MaxProfileJson = 16 * 1024 * 1024;
        private const int MaxReceiptJson = 256 * 1024;
        private readonly string receipts, profile;
        private readonly JavaScriptSerializer json = new JavaScriptSerializer { MaxJsonLength = MaxProfileJson, RecursionLimit = 32 };
        private static readonly Regex UtcPattern = new Regex("\\A[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\\.[0-9]{1,7})?(Z|\\+00:00)\\z");

        internal static string DefaultProfilePath
        {
            get { return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "NaiwaFragmentPrototype", "profile.json"); }
        }

        internal DropGrowthView(string dataRoot, string profilePath)
        {
            if (String.IsNullOrWhiteSpace(dataRoot) || String.IsNullOrWhiteSpace(profilePath)) throw new ArgumentException("缺少成长记录位置");
            receipts = Path.Combine(Path.GetFullPath(dataRoot), "receipts");
            profile = Path.GetFullPath(profilePath);
        }

        internal DropGrowthSnapshot Read()
        {
            DropGrowthSnapshot result = new DropGrowthSnapshot();
            HashSet<string> acknowledged = new HashSet<string>(StringComparer.Ordinal);
            HashSet<string> credited = new HashSet<string>(StringComparer.Ordinal);
            int level = 1;
            long xp = 0, total = 0, remainder = 0;
            // A missing initial profile is a fresh install. A file that exists but
            // cannot be validated is an error, never an apparent reset to Lv.1.
            Dictionary<string, object> profileData = null;
            bool missingProfile = false;
            try { profileData = ReadJson(profile, MaxProfileJson); }
            catch (FileNotFoundException) { missingProfile = true; }
            catch (DirectoryNotFoundException) { missingProfile = true; }
            catch
            {
                result.Error = "成长存档暂不可读，已保存的吞噬记录仍会保留；请进入游戏恢复同步。";
                return result;
            }
            if (missingProfile && File.Exists(profile + ".bak"))
            {
                result.Error = "成长主存档暂不可用，请进入游戏从已有备份恢复同步。";
                return result;
            }
            if (profileData != null)
            {
                try
                {
                    Dictionary<string, object> data = profileData;
                    if (data.ContainsKey("version")) Integer(data["version"], 1, 2);
                    level = (int)Integer(Value(data, "level"), 1, 1000);
                    xp = Integer(Value(data, "xp"), 0, MaxJsonInteger);
                    total = Number(data, "recycle_bytes_total");
                    remainder = Number(data, "recycle_remainder_bytes");
                    long earned = Number(data, "recycle_xp_total");
                    long count = Number(data, "recycle_items_total");
                    ReadIds(data, "recycle_receipts", 32, acknowledged);
                    ReadIds(data, "recycle_consumed", 64, credited);
                    if (remainder != total % Unit || earned != total / Unit || count != credited.Count)
                        throw new InvalidDataException("成长统计与账本不一致");
                }
                catch
                {
                    result.Error = "成长存档暂不可读，已保存的吞噬记录仍会保留；请进入游戏恢复同步。";
                    return result;
                }
            }

            List<string> files = new List<string>();
            try
            {
                files.AddRange(Directory.GetFiles(receipts, "*.json"));
                files.Sort(StringComparer.Ordinal);
            }
            catch (DirectoryNotFoundException) { }
            catch
            {
                result.Error = "吞噬记录暂不可读，请检查应用数据目录；不会清空已有成长。";
                return result;
            }
            foreach (string path in files)
            {
                string filename = Path.GetFileName(path);
                string id = Path.GetFileNameWithoutExtension(filename);
                // Acknowledged files remain durable source evidence. Do not read
                // their contents repeatedly as the lifetime ledger grows.
                if (Path.GetExtension(filename) != ".json" || !Hex(id, 32) || acknowledged.Contains(id)) continue;
                try
                {
                    Dictionary<string, object> receipt = ReadJson(path, MaxReceiptJson);
                    if (Integer(Value(receipt, "version"), 1, 1) != 1 || Value(receipt, "id") as string != id
                        || Value(receipt, "kind") as string != "recycle_feed" || !ValidUtc(Value(receipt, "completed_utc")))
                        throw new InvalidDataException("吞噬记录格式无效");
                    IList raw = Value(receipt, "items") as IList;
                    if (raw == null || raw.Count < 1 || raw.Count > 1000) throw new InvalidDataException("吞噬记录项目无效");
                    HashSet<string> batch = new HashSet<string>(StringComparer.Ordinal);
                    List<KeyValuePair<string, long>> fresh = new List<KeyValuePair<string, long>>();
                    long sum = 0, uniqueBytes = 0;
                    foreach (object value in raw)
                    {
                        Dictionary<string, object> entry = value as Dictionary<string, object>;
                        if (entry == null) throw new InvalidDataException("吞噬记录项目无效");
                        string key = Value(entry, "id") as string;
                        long bytes = Integer(Value(entry, "bytes"), 0, MaxBatch);
                        if (!Hex(key, 64) || !batch.Add(key) || sum > MaxBatch - bytes) throw new InvalidDataException("吞噬记录大小或身份无效");
                        sum += bytes;
                        if (!credited.Contains(key)) { fresh.Add(new KeyValuePair<string, long>(key, bytes)); uniqueBytes += bytes; }
                    }
                    if (sum != Integer(Value(receipt, "completed_bytes"), 0, MaxBatch)
                        || total > MaxJsonInteger - result.PendingBytes - uniqueBytes) throw new InvalidDataException("吞噬记录总量无效");
                    // Only a fully valid receipt can advance the in-memory view.
                    foreach (KeyValuePair<string, long> entry in fresh) credited.Add(entry.Key);
                    result.PendingBytes += uniqueBytes;
                }
                catch { /* Bad/partial records never grant growth, and do not block later records. */ }
            }

            long pendingXp = (remainder + result.PendingBytes) / Unit;
            xp += pendingXp;
            while (level < 1000 && xp >= Needed(level)) { xp -= Needed(level); level++; }
            if (level == 1000) xp = Math.Min(xp, Needed(level) - 1);
            long carry = (remainder + result.PendingBytes) % Unit;
            result.Level = level;
            result.TotalBytes = total + result.PendingBytes;
            result.LevelBytes = Needed(level) * Unit;
            result.CurrentBytes = level == 1000 ? result.LevelBytes : xp * Unit + carry;
            result.BytesToNextLevel = level == 1000 ? 0 : Math.Max(0, result.LevelBytes - result.CurrentBytes);
            return result;
        }

        private Dictionary<string, object> ReadJson(string path, int maxBytes)
        {
            string text;
            // Bound bytes actually read, even if a foreign writer changes length
            // between opening and reading. Share deletion permits atomic rename.
            using (FileStream stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete))
            {
                if (stream.Length > maxBytes) throw new InvalidDataException("成长记录过大");
                using (MemoryStream buffer = new MemoryStream())
                {
                    byte[] chunk = new byte[8192];
                    int count;
                    while ((count = stream.Read(chunk, 0, (int)Math.Min(chunk.Length, maxBytes + 1L - buffer.Length))) > 0)
                    {
                        buffer.Write(chunk, 0, count);
                        if (buffer.Length > maxBytes) throw new InvalidDataException("成长记录过大");
                    }
                    text = new UTF8Encoding(false, true).GetString(buffer.ToArray());
                }
            }
            if (text.Length > 0 && text[0] == '\ufeff') text = text.Substring(1);
            Dictionary<string, object> data = json.Deserialize<Dictionary<string, object>>(text);
            if (data == null) throw new InvalidDataException("成长记录无效");
            return data;
        }

        private static object Value(Dictionary<string, object> data, string key)
        {
            object value;
            if (!data.TryGetValue(key, out value)) throw new InvalidDataException("成长记录缺少字段");
            return value;
        }

        private static long Number(Dictionary<string, object> data, string key)
        {
            return data.ContainsKey(key) ? Integer(data[key], 0, MaxJsonInteger) : 0;
        }

        private static long Integer(object raw, long minimum, long maximum)
        {
            if (!(raw is Int32) && !(raw is Int64) && !(raw is Decimal) && !(raw is Double) && !(raw is Single))
                throw new InvalidDataException("成长数值必须是整数");
            decimal number;
            try { number = Convert.ToDecimal(raw, CultureInfo.InvariantCulture); }
            catch { throw new InvalidDataException("成长数值必须是有限整数"); }
            if (Decimal.Truncate(number) != number || number < minimum || number > maximum) throw new InvalidDataException("成长数值超出范围");
            return Decimal.ToInt64(number);
        }

        private static void ReadIds(Dictionary<string, object> data, string field, int length, HashSet<string> output)
        {
            if (!data.ContainsKey(field)) return;
            IList records = data[field] as IList;
            if (records == null) throw new InvalidDataException("成长账本无效");
            foreach (object raw in records)
            {
                string id = raw as string;
                if (!Hex(id, length) || !output.Add(id)) throw new InvalidDataException("成长账本身份无效或重复");
            }
        }

        private static bool Hex(string value, int length)
        {
            if (value == null || value.Length != length) return false;
            foreach (char c in value) if (!((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f'))) return false;
            return true;
        }

        private static bool ValidUtc(object raw)
        {
            string value = raw as string;
            DateTime date;
            return value != null && value.Length >= 20 && value.Length <= 40 && UtcPattern.IsMatch(value)
                && DateTime.TryParse(value, CultureInfo.InvariantCulture, DateTimeStyles.RoundtripKind, out date) && date.Year >= 1970;
        }

        private static long Needed(int level) { return 60L + (level - 1) * 30L; }

        internal static string FormatBytes(long bytes)
        {
            string[] units = { "B", "KiB", "MiB", "GiB", "TiB", "PiB" };
            double size = Math.Max(0, bytes); int index = 0;
            while (size >= 1024 && index < units.Length - 1) { size /= 1024; index++; }
            return size.ToString(index == 0 ? "0" : "0.##", CultureInfo.InvariantCulture) + " " + units[index];
        }

        internal static void RunViewTests(string output)
        {
            string root = Path.Combine(Path.GetFullPath(output), "view-fixture-" + Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(root);
            List<string> log = new List<string>(); int failures = 0;
            Action<bool, string> check = delegate(bool ok, string title) { log.Add((ok ? "PASS " : "FAIL ") + title); if (!ok) failures++; };
            JavaScriptSerializer serializer = new JavaScriptSerializer();
            Func<string, DropGrowthView> view = delegate(string name) { return new DropGrowthView(Path.Combine(root, name, "data"), Path.Combine(root, name, "profile.json")); };
            Action<string, string, object> put = delegate(string name, string relative, object data) {
                string path = Path.Combine(root, name, relative); Directory.CreateDirectory(Path.GetDirectoryName(path));
                File.WriteAllText(path, serializer.Serialize(data), new UTF8Encoding(false));
            };
            Func<int, long, Dictionary<string, object>> profileData = delegate(int level, long xp) { return new Dictionary<string, object> { { "version", 1 }, { "level", level }, { "xp", xp } }; };
            Func<string, string, long, Dictionary<string, object>> receiptData = delegate(string id, string item, long bytes) {
                return new Dictionary<string, object> { { "version", 1 }, { "id", id }, { "kind", "recycle_feed" }, { "completed_utc", "2026-10-28T06:12:00.1234567Z" }, { "items", new object[] { new Dictionary<string, object> { { "id", item }, { "bytes", bytes } } } }, { "completed_bytes", bytes } };
            };
            string a = new String('a', 32), b = new String('b', 32), c = new String('c', 32);
            string itemA = new String('a', 64), itemB = new String('b', 64);
            Func<string, string> receiptPath = delegate(string id) { return Path.Combine("data", "receipts", id + ".json"); };
            try
            {
                DropGrowthSnapshot value = view("fresh").Read();
                check(value.Error == "" && value.Level == 1 && value.BytesToNextLevel == 60 * Unit, "fresh install projects the first byte threshold without creating profile data");
                check(!Directory.Exists(Path.Combine(root, "fresh")), "read-only fresh view creates no directories");
                put("legacy", "profile.json", profileData(3, 7)); value = view("legacy").Read();
                check(value.Error == "" && value.Level == 3 && value.CurrentBytes == 7 * Unit && value.LevelBytes == 120 * Unit, "version-one profile works without recycle fields");
                put("carry", receiptPath(a), receiptData(a, itemA, 5 * 1024 * 1024)); value = view("carry").Read();
                check(value.PendingBytes == 5 * 1024 * 1024 && value.CurrentBytes == value.PendingBytes, "sub-unit byte growth is visible before game import");
                put("carry", receiptPath(b), receiptData(b, itemB, 3 * 1024 * 1024)); value = view("carry").Read();
                check(value.PendingBytes == Unit && value.CurrentBytes == Unit && value.BytesToNextLevel == 59 * Unit, "successive receipts accumulate fractional growth exactly");
                put("level", receiptPath(a), receiptData(a, itemA, 60 * Unit)); value = view("level").Read();
                check(value.Level == 2 && value.TotalBytes == 60 * Unit && value.CurrentBytes == 0 && value.BytesToNextLevel == 90 * Unit, "480 MiB immediately projects level two and its next byte threshold");
                Dictionary<string, object> committed = profileData(2, 1);
                committed["version"] = 2; committed["recycle_bytes_total"] = 61 * Unit; committed["recycle_xp_total"] = 61;
                committed["recycle_remainder_bytes"] = 0; committed["recycle_items_total"] = 1;
                committed["recycle_receipts"] = new string[] { a }; committed["recycle_consumed"] = new string[] { itemA };
                put("ack", "profile.json", committed); put("ack", receiptPath(a), receiptData(a, itemA, 61 * Unit)); value = view("ack").Read();
                check(value.Error == "" && value.TotalBytes == 61 * Unit && value.PendingBytes == 0 && value.CurrentBytes == Unit, "acknowledged receipts do not double-count byte growth");
                put("ack", receiptPath(b), receiptData(b, itemA, 61 * Unit)); value = view("ack").Read();
                check(value.PendingBytes == 0 && value.TotalBytes == 61 * Unit, "item ledger prevents replay under a different receipt id");
                put("dedup", receiptPath(a), receiptData(a, itemA, Unit)); put("dedup", receiptPath(b), receiptData(b, itemA, Unit));
                check(view("dedup").Read().PendingBytes == Unit, "unimported duplicate item receipts count once");
                Dictionary<string, object> malformed = receiptData(a, itemA, Unit); malformed["completed_bytes"] = Unit + 1;
                put("bad-sum", receiptPath(a), malformed); put("bad-sum", receiptPath(b), receiptData(b, itemB, Unit));
                check(view("bad-sum").Read().PendingBytes == Unit, "bad receipt cannot starve a later valid receipt");
                malformed = receiptData(a, itemA, Unit); malformed["items"] = new object[] { new Dictionary<string, object> { { "id", itemA }, { "bytes", 1.5 } } }; malformed["completed_bytes"] = 1.5;
                put("fraction", receiptPath(a), malformed);
                check(view("fraction").Read().PendingBytes == 0, "fractional byte counts are rejected rather than rounded");
                malformed = receiptData(a, itemA, Unit); malformed["completed_utc"] = "2026-10-28T06:12:00+08:00"; put("date", receiptPath(a), malformed);
                check(view("date").Read().PendingBytes == 0, "non-UTC receipt timestamps are rejected");
                put("identity", receiptPath(a), receiptData(b, itemA, Unit));
                check(view("identity").Read().PendingBytes == 0, "receipt filename and id must match");
                put("too-large", receiptPath(a), receiptData(a, itemA, MaxBatch + 1));
                check(view("too-large").Read().PendingBytes == 0, "receipts exceeding 32 GiB are rejected");
                malformed = receiptData(a, itemA, Unit); malformed["padding"] = new String('x', MaxReceiptJson); put("json-limit", receiptPath(a), malformed);
                check(view("json-limit").Read().PendingBytes == 0, "oversized JSON is rejected before parsing");
                put("corrupt", "profile.json", "not a profile"); value = view("corrupt").Read();
                check(value.Error.Length > 0, "unreadable profile reports an error instead of a displayed reset");
                Dictionary<string, object> broken = new Dictionary<string, object>(committed); broken["recycle_remainder_bytes"] = 1; put("ledger", "profile.json", broken);
                check(view("ledger").Read().Error.Length > 0, "inconsistent cumulative remainder is rejected");
                broken = new Dictionary<string, object>(committed); broken["recycle_receipts"] = new string[] { a, a }; put("ledger-ids", "profile.json", broken);
                check(view("ledger-ids").Read().Error.Length > 0, "duplicate saved receipt identities are rejected");
                put("max", "profile.json", profileData(1000, 0)); value = view("max").Read();
                check(value.Error == "" && value.Level == 1000 && value.BytesToNextLevel == 0 && value.CurrentBytes == value.LevelBytes, "maximum level has a full progress display and no next threshold");
                check(FormatBytes(480 * 1024 * 1024) == "480 MiB" && FormatBytes(Unit * 128) == "1 GiB", "size formatting uses consistent binary units");
                put("zero", receiptPath(a), receiptData(a, itemA, 0)); value = view("zero").Read();
                check(value.TotalBytes == 0 && value.Level == 1 && value.CurrentBytes == 0, "empty files cannot grant size growth");
                put("readonly", "profile.json", committed); byte[] before = File.ReadAllBytes(Path.Combine(root, "readonly", "profile.json"));
                view("readonly").Read(); view("readonly").Read(); byte[] after = File.ReadAllBytes(Path.Combine(root, "readonly", "profile.json"));
                check(Convert.ToBase64String(before) == Convert.ToBase64String(after), "repeated growth views never rewrite the game profile");
            }
            catch (Exception error) { failures++; log.Add("FAIL unexpected view test error: " + error); }
            log.Add("Failures=" + failures);
            log.Add("Only explicit workspace fixtures were read. No real user profile, recycle bin or file movement was used.");
            File.WriteAllLines(Path.Combine(Path.GetFullPath(output), "growth-view-tests.txt"), log.ToArray(), new UTF8Encoding(false));
            if (failures > 0) Environment.ExitCode = 1;
        }
    }
}
