> 历史设计/交付记录，当前玩法以仓库首页和权威配置为准；历史生成日志和截图不全部纳入Git。

# 回收站喂食：共享成长与记账

2026-10-28。真实回收站的处理由原生桌宠完成；Godot 仅导入已成功完成的本地结果记录。游戏不打开、扫描或删除真实垃圾文件，也不让桌宠直接改写游戏正在使用的角色存档。

## 结果记录协议

桌宠在 `%LOCALAPPDATA%\NaiwaDesktopPet\recycle-feed\receipts\` 写入 UTF-8 JSON。建议先写临时文件，再原子改名为 `小写32位GUID.json`，游戏只枚举 `.json`。

```json
{
  "version": 1,
  "id": "0123456789abcdef0123456789abcdef",
  "kind": "recycle_feed",
  "completed_utc": "2026-10-28T06:12:00.1234567Z",
  "items": [
    {
      "id": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
      "bytes": 8388608
    }
  ],
  "completed_bytes": 8388608
}
```

条目ID是原生端核实成功处理项目的稳定 SHA-256 摘要，小写64位十六进制；不把原文件名、原始路径或文件内容写入成长记录。失败、取消、身份变化或不能核实完成的项目不能进入记录。结果记录属于本地游戏的可靠交接协议，并不是联网防作弊或任意不可信软件之间的授权协议。

游戏验证文件名与ID一致、固定版本/种类、UTC时间、整数和总和、无重复项目ID。每批最多1000条，最多32GiB，JSON最大256KiB；这些字节量均在JSON双精度数字可精确表示的范围内。支持无BOM及带BOM的UTF-8，不支持通过记录引用其他文件、脚本或网络地址。

## 经验规则

- 成功处理的累计真实字节，每8MiB奖励1XP。
- 不足8MiB保留余数，之后与新处理量合计。
- 不按每个文件设最低经验；零字节项目可以计入清理数量，但不产经验。
- 实际奖励使用原有 `needed()` 曲线并提升相同的 `level/xp`，不会另造第二个角色等级。
- 原有虚拟碎片背包、虚拟喂食次数和战斗奖励保留。真实回收站有独立统计与去重账本。
- 保持原存档支持的最高等级1000；到达上限后等级/当前XP不再溢出，累计真实处理量仍可记录。

## 持久化与崩溃恢复

存档版本升级为2，旧字段和旧版存档继续兼容。新增：

| 字段 | 含义 |
|---|---|
| `recycle_bytes_total` | 已确认且未重复计入的真实字节 |
| `recycle_xp_total` | 由真实字节产生的累计XP |
| `recycle_items_total` | 已确认且未重复计入的项目数 |
| `recycle_remainder_bytes` | 不足下一点XP的字节余数 |
| `recycle_receipts` | 已提交的32位结果记录ID |
| `recycle_consumed` | 已提交的64位项目摘要 |

导入时先在内存构造新状态，再把XP、累计量和两个去重账本同一次写入临时存档、刷新并关闭文件、备份旧主档，最后原子替换主档。写入或备份失败时恢复导入前内存状态，不发送成功事件；原结果文件不变，下次继续重试。成功事件只在持久化成功后发出。若提交成功后程序中断，重启从存档去重，不会再加一次经验。

结果记录保留原位，`recycle_receipts` 是持久化确认，不依赖“先删除结果文件再保存”的易丢账流程。同一个项目出现在新结果ID里也会按项目摘要去重。原生端若读整个存档作展示，应提高默认JSON长度上限以适应长期账本，不要把解析失败视为角色回到Lv.1。

## 自动同步与接口

正式Windows运行的Profile autoload在启动后及每1秒尝试读取新记录。每次最多尝试32条；游标轮转，坏记录不会一直挡住后面的有效记录。没有结果目录时不创建目录、不扫描其他位置。

- `poll_recycle_receipts()`：批量导入，返回本轮 `items/bytes/xp/levels/receipts`。
- `import_recycle_receipt(path)`：导入配置目录内一个记录，返回 `ok/duplicate/items/bytes/xp/levels`。
- `recycle_imported(items, bytes, earned_xp, levels)`：仅持久化成功后发出。
- 原 `changed` 事件同步更新游戏菜单、成长档案和HUD。

桌宠可在游戏未运行时先持久化结果，下一次启动游戏再导入。游戏运行时自动导入；原生端和Godot不同时写 `profile.json`。

## 隔离检查

`--profile-test`、`--recycle-test`、`--slice-test`、`--slice-visual`、`--bridge-check` 等既有测试模式禁用保存，且不会解析或枚举当前用户的真实结果目录。独立测试实例仅显式使用工作区新建的结果目录和存档。

运行：

```text
Godot_v4.7.2-stable_win64.exe --headless --path prototype --script res://tests/recycle_profile_test.gd -- --profile-test --recycle-test
```

结果与日志：`prototype/artifacts/recycle-profile-checks.txt`、`recycle-profile-check.log`。测试覆盖旧档迁移、字节余数、两层去重、正常升级、零字节、重启、写失败和备份失败回滚、失败后重试、金额/日期/ID/JSON边界、BOM、越界路径、禁保存隔离、坏记录轮转以及等级上限。原有8项存档检查保留并回归。
