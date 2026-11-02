> 历史设计/交付记录，当前玩法以仓库首页和权威配置为准；历史生成日志和截图不全部纳入Git。

# 回收站喂食：安全审计与隔离测试计划

2026-10-28。此文是实现约束与验收计划，不表示真实回收站删除已经测试通过。所有自动化测试使用 fake store、fake receipt writer 或本测试自行创建的文件，禁止删除、恢复或向用户真实回收站放入文件。

## 事务边界

界面只扫描当前用户的 Windows 回收站元数据，列出名称、原位置、删除时间、文件类型和可计费大小。预览默认不勾选；应用强制用户主动选择、勾选永久删除并点击确认。程序请求 Windows 显示永久删除警告，实际提示以系统为准，尚未以真实删除验证所有系统/provider的提示行为。没有后台删除、定时清空或自动选择系统目录的路径。

选中并不等于完成。只有 Windows 返回该条目的实际删除成功，且操作后该身份确实不再存在，才进入成功列表；取消、跳过、失败、身份变化或无法验证的条目均不奖励。

Native 只写成功收据，不直接编辑 Godot 的 `profile.json`。游戏把收据 ID、成功条目 ID、累计字节、累计经验和新等级放进同一次原子存档；失败保留收据并恢复导入前内存状态，成功后才标记/归档。这样能避免已成功导入收据在重启时重复奖励。

Windows 删除与本地收据不属于同一个事务，不能保证二者之间绝对无崩溃窗口。删除前应验证收据目录可写并写入操作意图；删除后逐项保存确认信息。若崩溃时只有意图、缺乏成功证据，不得把“文件已不在回收站”推断为本程序删除：文件也可能已被用户恢复或别的程序处理。应保守标记为无法确认，不自动补奖，并如实说明该边界。

## Windows API 依据

- [`IFileOperation::PerformOperations`](https://learn.microsoft.com/en-us/windows/win32/api/shobjidl_core/nf-shobjidl_core-ifileoperation-performoperations)：调用完成或返回成功码，仍可能包含用户取消。
- [`GetAnyOperationsAborted`](https://learn.microsoft.com/en-us/windows/win32/api/shobjidl_core/nf-shobjidl_core-ifileoperation-getanyoperationsaborted)：应在操作返回后检查，无论整体 HRESULT 是成功还是失败。
- [`IFileOperationProgressSink::PostDeleteItem`](https://learn.microsoft.com/en-us/windows/win32/api/shobjidl_core/nf-shobjidl_core-ifileoperationprogresssink-postdeleteitem)：`hrDelete` 才是实际删除结果；排队 `DeleteItem` 的返回值不是完成证明。
- [`SetOperationFlags`](https://learn.microsoft.com/en-us/windows/win32/api/shobjidl_core/nf-shobjidl_core-ifileoperation-setoperationflags)：请求永久销毁警告，实际系统/provider提示仍需实机验证；不能启用自动回答所有确认的标志，不打开遍历命名空间连接或提权标志。
- [`FolderItem.InvokeVerb`](https://learn.microsoft.com/en-us/windows/win32/shell/folderitem-invokeverb)：不返回操作结果，因此不能单凭调用后无异常就给予经验。

以上为官方文档核对后的设计结论。具体 API 选择及真实系统边界以 Windows store 实现审计和运行结果为准。

## 可注入测试边界

建议 service 接受 `IRecycleBinStore` 与可替换收据写入器。测试仅使用固定清单和计数器，任何测试误调用真实 store 构造器都应立即失败。测试输出目录应是工作区或当前测试创建的独立目录，清理时只删自己命名的 fixture。

| 情形 | 期待结果 |
|---|---|
| 扫描但未确认 | 不调用删除，也不写成功收据。 |
| 空选择、空列表、全不可选 | 删除次数为零，奖励为零。 |
| 取消本程序确认 | 与扫描相同，无文件变更。 |
| 用户取消 Windows 确认，整体返回 S_OK | 不把 S_OK 误当成功；对应条目不奖励。 |
| 一批成功/取消/失败混合 | 仅成功且确认不存在的条目写入收据。 |
| 预览后尺寸、身份或删除时间变化 | 拒绝该条目，要求刷新选择；不删除替代物。 |
| 预览后条目被恢复或外部删除 | 不尝试原始路径，不奖励。 |
| 外部伪造任意普通文件路径 | 不属于当前回收站身份，拒绝操作。 |
| 文件夹、重解析点、Shell 大小未知 | 首版可拒绝并显示原因，绝不递归猜测大小或目标。 |
| 空文件 | 可清理，字节为零，不按文件数量凭空奖励。 |
| 重复选中同一身份 | 最多处理一次，计量一次。 |
| 收据目录不可写或意图写入失败 | 在首次真实删除之前终止。 |
| 删除成功后收据写入失败 | 不重删；结果明确提示记录失败/待重试，不能声称已记入经验。 |
| 导入重复 receipt / 重复 item ID | 成功字节和 XP 只记一次。 |
| 累计不足 8 MiB | 保留余数；跨多批累计到阈值才奖励。 |
| 恰好/超过 8 MiB 边界 | 整数商与余数正确，不能用浮点四舍五入奖励。 |
| 负数、NaN、小数 bytes、超出约定上限、非法 id | 收据拒绝，现有进度不变。 |
| 导入后 profile 保存失败 | 经验与账本在内存中回滚，收据保留，重试不重复增加。 |
| 保存成功、归档失败或进程在归档前退出 | 下次读取由账本去重，不能重复奖励。 |
| 游戏已运行 / 暂停 / 桌宠模式 / 游戏未启动 | 同一存档最终接收一次收据，Native 与 Godot 无并发覆盖。 |
| 原版 v1 存档迁移 | 虚拟碎片、战斗经验、等级、胜负和喂食计数保留。 |
| `--slice-test` 等既有隔离参数 | 不读取正式收据目录，不写真实存档或用户设置。 |

## 展示与隐私核对

不在日志、收据或聊天输出真实文件名/原路径；这些信息仅在本机预览窗口供用户选择。收据保留非可读条目 ID 和成功字节即可。

“文件逻辑大小”不等于精确释放的物理磁盘空间：压缩、稀疏文件或硬链接可能导致差异。界面可写“已处理大小”，除非另有真实磁盘空间测量，不能把逻辑字节直接宣传为“释放磁盘空间”。

这是 Windows 功能；没有实现和验证的其他操作系统应显示不可用，不能把 Windows Shell 支持描述为跨平台清理器。

## 当前状态与结果

已完成只读源码审计、官方 API 核对、Native service 加固与独立旧版 CSC 编译。

`desktop/source/RecycleFeedTests.cs` 的25项 fake-store 检查全部通过，结果在 `prototype/artifacts/recycle-native-tests/recycle-feed-tests.txt`。测试覆盖确认与取消、部分失败、元数据变化、无效/重复/超限选择、收据延迟发布、预写失败零删除、记录重试不重删、重启恢复、缺失不推断成功，以及隐私字段。

根据审计增加了额外防线：只接受服务实际签发的最后一次预览对象；提交核对私有深拷贝（包括PIDL字节），拒绝修改ID、确认名单或字节数的预览；调用方重置 `Used` 不能重放。实际删除回调仅接受 `S_OK`。恢复仅接受候选列表内、整数字节的已确认成功记录。零成功时的完成标记写失败不会卡住后续预览；已发布收据后的重试只补记账，不再执行删除或重新发布已消费文件。

所有服务测试只改变 fake store 的内存列表。Windows adapter 另行完成真实系统的只读枚举与 COM 绑定检查，真实永久删除未执行，不能将编译或 fake 测试描述为已在用户回收站完成清理。Godot 收据迁移与原子持久化由独立子任务验证。
