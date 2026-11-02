# 模块、数据流与存档

## 两个运行时

Godot 4.7.2/GDScript负责战斗、UI、场景、经济和本机成长档案。Windows桌宠是C# WinForms程序，负责桌面窗口、动作、拖放、回收和启动/恢复Godot进程。网页发布是Godot的真实WebAssembly导出，由一层静态JavaScript加载器还原分块游戏数据。

## 入口

prototype/project.godot的默认主场景是v6/slice.tscn。v6/main.gd装配玩家、敌人、场景、HUD、Boss领域、连战、觉醒、拾取和命中表现模块。v3/v4/v5保留历史与复用组件，不能把任意旧场景直接当作当前正式入口。

## 数据所有权

- Profile：经验、等级、补给、有效回收量、回执和去重标识。
- Wardrobe：金币、皮肤拥有/装备、通关奖励账本、装备等级。
- Ascension：魔能、击杀记录和事件去重。
- Preferences：操作、声音及减少动态设置。
- 桌宠DropGrowthView：只读投影游戏成长状态，不与Godot争写Profile。

桌宠回收成功后写收据；Godot轮询导入并累计经验，桌宠读取游戏档案和待确认收据以显示成长。游戏与桌宠之间还有进程心跳和返回/恢复请求。

## 世界与战斗配置

| 位置 | 职责 |
| --- | --- |
| biomes/content.gd | 四图阵容、十二场景、Boss表、技能等级和波次 |
| campaign/levels.gd | 关卡段落与倍率 |
| combat/enemy_catalog.gd | 敌人基础值、受击范围和显示名称 |
| v6/fighter.gd | 玩家移动、跳跃、动作状态与输入缓冲 |
| rift/tactics.gd、loop/boss_brain.gd | Boss评分选招与阶段行为 |
| rift/director.gd | 入场、精准闪避与遗物 |
| loop/journey.gd | 连战、掉落、拾取和段落切换 |
| ascension/power.gd | 觉醒阶段与伤害触点 |
| punch/director.gd | 已确认命中后的声画反馈 |

## 网页

web/dist是已经构建的静态成品。game-manifest.json记录wasm/pck原文件长度、哈希及gzip数据块列表。每块小于8MiB；app.js在输出某块之前先下载完整压缩块并校验SHA前缀，然后解压为连续流，避免重试造成半块重复。

浏览器文件系统与本机存档隔离。JavaScriptBridge仅提供当前页内存/DOM诊断，不提供修改角色数值的公共控制接口，也不上传游戏遥测。

## 存档兼容

当前公开项目名为Naiwa: Riftbound，但没有为了改仓库名而重命名旧的NaiwaFragmentPrototype用户目录。这样现有本机用户不需要因文档命名更换而迁移档案。不同网页域名的IndexedDB空间仍然独立；尚无跨域云同步。

## 素材

角色与技能使用图集、元数据、锚点和逐帧状态组织。图像来源、生成参与、SHA及区域测量保存在各assets目录。不要将生成来源记录理解为角色IP的额外授权，也不要用重画替换来抹掉上游署名。
