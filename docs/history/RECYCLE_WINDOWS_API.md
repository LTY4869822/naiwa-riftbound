> 历史设计/交付记录，当前玩法以仓库首页和权威配置为准；历史生成日志和截图不全部纳入Git。

# Windows 回收站接入 API

2026-10-28。核心文件：`desktop/source/RecycleBinStore.cs`。本文只说明 Windows 文件操作层；桌宠选择界面、吞噬记录和 Godot 经验消费由上层实现。

## 接口

`IRecycleBinStore`：

- `IntPtr OwnerWindow { get; set; }`：Windows 确认/进度对话框的拥有者。
- `List<RecycleEntry> Scan()`：只读枚举当前用户回收站。
- `List<RecycleDeleteResult> DeleteSelected(IList<RecycleEntry> confirmedItems, Action<RecycleDeleteResult> onItemCompleted)`：处理已由应用确认过的精确选择。回调仅在某项实际永久删除并验证消失时调用，完成结果逐项返回。

`RecycleEntry` 包含 `Id`、`DisplayName`、`OriginalLocation`、`ShellParsingName`、`DeletedAtUtc`、`SizeBytes`、`IsDirectory`、`IsSupported`、`UnavailableReason`；`AbsolutePidl` 只是内部 Shell 身份的副本，不是提供给用户的任意路径入口。

`RecycleDeleteResult` 包含 `Entry`、`Deleted`、`Cancelled`、`ErrorMessage`、`HResult`。只有 `Deleted=true` 的确认结果才有资格进入上层成功记录。

所有方法应在 STA 线程中调用。每次调用都局部创建/释放 Shell COM 对象；不会把对象缓存在实例里跨线程使用。上层可在独立 STA 工作线程调用，保持主桌宠消息泵与游戏心跳运行。上层不得并发扫描和删除同一批数据。

## 只读枚举与身份

1. 使用 Windows `Shell.Application.NameSpace(10)` 枚举当前用户的虚拟回收站。没有遍历所有卷的 `$Recycle.Bin`，没有读取原始文件内容或原始目录树。
2. `SHGetIDListFromObject` 取得回收站项目的绝对 PIDL，再由 `SHCreateItemFromIDList` 取得保留虚拟回收站语境的 `IShellItem`。删除时不使用调用者传入的原始路径创建目标。
3. 使用 Shell 属性系统取得原始字节大小、Windows 文件属性、原位置和删除时间；`System.Size` 必须是数字类型，不解析带单位/本地化的显示文本。优先读取原生 `PROPVARIANT/FILETIME`，必要时回退到 `FolderItem2.ExtendedProperty`。
4. ID 是回收站 PIDL、字节数和删除时间的 SHA-256（64位小写十六进制）。选择后、排队前与 `PreDeleteItem` 都重新枚举核对身份、大小、时间、名称和原位置；过期选择会停止处理。

本版只启用能够确认属性的普通文件。真实目录、重解析点、Shell链接、缺少准确大小/删除时间的项目会显示但不可吞噬。零字节普通文件可以处理，但是否奖励由上层规则决定。压缩文件如果仍是普通文件属性，不会仅因可在 Shell 中浏览就被当作目录。

## 永久删除的边界

删除使用 Windows `IFileOperation.DeleteItem` 排队与 `PerformOperations`，只处理新枚举、重新验证后得到的项目。

- 标志为 `FOF_WANTNUKEWARNING | FOF_NO_CONNECTED_ELEMENTS | FOF_NORECURSION`。
- 没有 `FOF_NOCONFIRMATION`、`FOF_SILENT`、`FOF_ALLOWUNDO`、`FOFX_RECYCLEONDELETE` 或提权标志。
- 没有调用 `SHEmptyRecycleBin`，没有调用 `File.Delete`/`Directory.Delete`，没有整桶清理入口。
- 未关闭 Windows 确认机制，并请求永久删除警告；是否显示及具体界面以系统为准，实际弹窗尚待隔离删除验收。应用自身始终要求逐项选择、勾选核对并点击永久吞噬。
- `PerformOperations` 返回成功也不代表用户没有取消；会读取 `GetAnyOperationsAborted`。
- `PostDeleteItem` 必须返回 **精确 `S_OK`**、`newlyCreated` 为 null，且新一轮 Shell 枚举中原身份已消失，才产生 `Deleted=true`。跳过/取消使用的非负 `COPYENGINE_*` 代码不是成功删除。
- 成功项回调同步执行，允许上层立即落持久化记录。若回调保存失败，进度 sink 返回 `E_ABORT` 取消余下项目，最终抛出 `IOException`。已经发生的永久删除不能撤销，因此上层必须先落盘意图并保留待核对记录。

## 本轮验证

以系统已有 .NET Framework 4 C# 编译器编译通过；没有额外包依赖。

只读实机检查结果：成功枚举20项，其中19个普通文件可用、1个文件夹禁用；所有项取得大小和删除时间，两次扫描20个身份均稳定。未将任何文件名、路径或内容写入日志。另验证了 COM 进度接口的 `QueryInterface` 为 `S_OK`，避免私有接口导致进度回调无法接入。

使用实际 `AssemblyInfo.cs` 的COM可见性设置编译后，还验证了未排队任何项目的操作对象初始化：`SetOwnerWindow(0)`、`SetOperationFlags(0x7000)`、`Advise`和`Unadvise`均为`S_OK`。没有调用未实现的可选`SetProgressMessage`。日志在 `prototype/artifacts/recycle-windows-readonly.txt`。

检查器在 `prototype/artifacts/RecycleBinReadOnlyProbe.cs`。它只做只读枚举与 COM 接口查询，没有调用永久删除。**本轮没有在用户真实回收站执行删除，不能声称真实删除端到端已经实测。** 上层失败、取消、部分成功与重复奖励应通过 fake store 隔离验证。

## 官方来源

- [SHGetIDListFromObject](https://learn.microsoft.com/en-us/windows/win32/api/shobjidl_core/nf-shobjidl_core-shgetidlistfromobject)
- [SHGetPropertyStoreFromIDList](https://learn.microsoft.com/en-us/windows/win32/api/shobjidl_core/nf-shobjidl_core-shgetpropertystorefromidlist)
- [FolderItem2.ExtendedProperty](https://learn.microsoft.com/en-us/windows/win32/shell/folderitem2-extendedproperty)
- [IFileOperation.SetOperationFlags](https://learn.microsoft.com/en-us/windows/win32/api/shobjidl_core/nf-shobjidl_core-ifileoperation-setoperationflags)
- [IFileOperation.PerformOperations](https://learn.microsoft.com/en-us/windows/win32/api/shobjidl_core/nf-shobjidl_core-ifileoperation-performoperations)
- [IFileOperation.GetAnyOperationsAborted](https://learn.microsoft.com/en-us/windows/win32/api/shobjidl_core/nf-shobjidl_core-ifileoperation-getanyoperationsaborted)
- [IFileOperationProgressSink.PostDeleteItem](https://learn.microsoft.com/en-us/windows/win32/api/shobjidl_core/nf-shobjidl_core-ifileoperationprogresssink-postdeleteitem)
- [Windows SDK property keys](https://github.com/microsoft/win32metadata/blob/main/generation/WinSDK/RecompiledIdlHeaders/um/propkey.h)
