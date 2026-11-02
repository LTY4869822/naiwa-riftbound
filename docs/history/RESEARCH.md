> 历史设计/交付记录，当前玩法以仓库首页和权威配置为准；历史生成日志和截图不全部纳入Git。

# 相关资料与项目调研

> 更新（2026-10-28）：本文是首轮选型记录。“一个 Godot 进程重做桌宠”的结论已由用户最新要求修正；后续完整保留 Naiwa 原生桌宠并增加游戏入口。见 [新一轮 GitHub 源码调研与重构路线](GITHUB_REBUILD_RESEARCH.md)。

日期：2026-10-28。

证据等级：读到源码的功能与 README 的功能声明分别标明；候选项目没有在本机编译或运行，作者写的测试数量不等于本次实测。许可证结论是仓库文件声明的记录，正式复用时仍应核对具体文件及素材来源。

## 用户实际想做的游戏

2D 打怪格斗升级；游戏中的角色可成为桌宠；用户把废弃文件喂给桌宠，使角色获得经验或材料，成长反馈同步到战斗。删除文件释放磁盘空间，不是释放运行内存。美术风格、名称、连招深度和完整商业范围未定。

早先《断帧》的分析可复用为战斗设计参考：序列帧、判定与动画分离、输入缓冲、命中停顿、击退和技能演出。其公开可下载文件不等于已获源码或美术复用许可，不作为默认素材或代码依赖。

## 优先研究的开源项目

| 项目 | 栈及版本证据 | 对本项目的用途 | 许可证与限制 |
|---|---|---|---|
| [phanstudio/Desktop-Pet](https://github.com/phanstudio/Desktop-Pet) | Godot；project.godot 声明 4.3 | 透明小窗口、窗口跟随人物、同一世界多窗口显示 | LICENCE.md 为 MIT；随附素材单独核验；旧示例需在目标引擎验证 |
| [godotengine/godot-demo-projects / 2d/platformer](https://github.com/godotengine/godot-demo-projects/tree/master/2d/platformer) | GDScript，当前 project.godot 声明 4.7，Compatibility | 横版移动、坡面、敌人、弹体、摄像机、暂停等基础结构 | 根许可证 MIT；音乐等单独致谢需保留，逐项核对资产 |
| [aminRX/shoto-fighter-godot](https://github.com/aminRX/shoto-fighter-godot) | Godot 4，GDScript | 研究出招帧、命中/受击框、硬直、命中停顿、输入和状态机 | 代码 LICENSE 为 MIT；CREDITS 将 KFM 素材标为 CC BY-NC，不作为商业素材；它是 1v1 格斗，非现成刷怪 RPG |
| [spyderweb47/Desktop-Virtual-buddy](https://github.com/spyderweb47/Desktop-Virtual-buddy) | Electron + TypeScript + Canvas | 窗口置顶、穿透、角色包、桌面物理和窗口边缘行为的备选路线 | LICENSE 为 MIT；AI Brain、截图及密钥模块不是本项目的必要功能 |
| [coglabss/deskcat](https://github.com/coglabss/deskcat) | Electron + JavaScript | 饥饿/精力/心情模型、喂食反馈、睡觉、拖拽与动画切换 | LICENSE 为 MIT，仅覆盖代码；猫图和音效另有许可 |

### 已实际阅读的代码

- Desktop-Pet 的 `scripts/Main.gd`：设置 borderless、always_on_top、transparent、transparent_bg、gui_embed_subwindows；窗口缩至人物范围并跟随摄像机；新建窗口共享 world_2d。
- Desktop-Pet 的 `project.godot`：透明与逐像素透明开关、独立系统子窗口设置。
- Virtual Buddy 的 `src/main/window.ts`：创建透明无框置顶窗口，启用鼠标穿透；contextIsolation=true，nodeIntegration=false。
- DeskCat 的 `src/renderer/mood-model.js`：时间驱动饥饿、精力与心情；feed/pet/play 改变状态；dominantMood 决定表现。这里的 feed 是养成数值操作，不是文件清理。
- 官方 Platformer 的 project.godot 和 README：当前为 4.7 配置；自述玩家无敌、敌人可受击，不能直接当作完整动作 RPG。
- 三个候选仓库的 LICENSE 以及 Shoto Fighter 的 CREDITS.md。

这足以支持技术选型，但没有验证所有宣称功能。后续若复用，应固定仓库 commit，而不是持续跟随 main/master。

## 产品参考及对旧讨论的修正

[Desksquattaz 官网](https://www.desksquattaz.com/)展示桌宠、真实文件夹、照料和桌面小游戏，适合研究两种游戏形态如何形成统一生活感。[官方 FAQ](https://www.desksquattaz.com/faq)明确说明不会删除文件或图标。因此它不是“真实清理系统垃圾”的验证案例，也不能直接取得其闭源实现。

早先对话中的 OpenPets 名称存在多个同名仓库。此次搜索出现 OpenPetsHQ、openpetstech、alterhq 等不同组织项目；它们不能混为一个项目。当前不将其加入依赖，优先用上述身份清楚、范围较小的参考。

Hyenate/DesktopPet 描述支持 Godot 桌宠和自定义图集，但本次页面没看到明确许可证信息，未继续验证单独许可文件，因此仅列待核实，不作为可复制代码来源。

## 美术素材起点

[Pixel Frog / Pixel Adventure](https://pixelfrog-assets.itch.io/pixel-adventure-1)官方页面明确标注 CC0，可用于原型的人物、地形、物件与动画；页面说明这是 PNG 图像包，不包含游戏代码。它适合早期移动与交互验证，不代表已经有本项目需要的完整格斗动作。

正式角色要统一桌宠与战斗的外观身份，分别准备 idle/run/jump/attack/hurt/eat/sleep/drag 等动作。桌宠尺寸小不意味着必须采用另一套人物。战斗和桌宠可以共享角色图集配置，各自选取合适动作子集。

## 官方技术文档与关键限制

1. [Godot Window](https://docs.godotengine.org/en/stable/classes/class_window.html)：mouse_passthrough_polygon 指定接受点击的区域；Windows 上区域外内容也会被裁掉，不能直接当成任意特效都可见的全屏穿透方案。首版采用人物范围的小透明窗，避免直接做全屏覆盖层。
2. [Godot OS.move_to_trash](https://docs.godotengine.org/en/stable/classes/class_os.html#class-os-method-move-to-trash)：支持 Windows，返回错误状态；系统禁用回收站时可能永久删除，因此不能把调用成功等同于“始终可恢复”。
3. [Godot 保存游戏](https://docs.godotengine.org/en/stable/tutorials/io/saving_games.html)：FileAccess、JSON 和 user:// 可用于本地状态持久化。跨模式优先共用一个内存中的角色状态，再由单一服务写盘。
4. [Electron BrowserWindow](https://www.electronjs.org/docs/latest/api/browser-window)：可实现桌面窗口定制；这是 Web 游戏路线的备选桌面宿主。
5. [Electron shell.trashItem](https://www.electronjs.org/docs/latest/api/shell#shelltrashitempath)：提供系统废纸篓调用，异步报告失败；不能替代路径校验、用户选择和操作记录。
6. [Godot Windows 下载](https://godotengine.org/download/windows/)：本次页面列出 4.7.2 标准版与 .NET 版。建议先用标准版 GDScript，减少额外工具链。

## 选型结论

首选：Godot 4.7.2 标准版，Windows PC，一个进程、两个模式、一个角色数据中心。它同时覆盖原生桌面窗口与完整 2D 游戏场景，能让两种模式使用同一套数据和角色资源。

备选：Electron + TypeScript + Canvas/Phaser，更贴近《断帧》的网页技术路线，桌宠参考丰富；常驻进程实际内存、打包大小和战斗表现仍应测量，不能凭栈名承诺轻量。两条路线先不混用。

首选的关键验收门槛是：透明窗口、拖拽、后台资源占用、不同 DPI 和任务栏工作区在本机可用。若不满足，再评估 Electron，而不是预先同时维护两个客户端。第一阶段暂不做其他应用窗口攀爬、多屏、AI 聊天或云同步。

## 尚未完成的验证

- 候选项目未下载完整仓库、未运行，也未测试其已有安装包。
- 未实测 Godot 桌宠透明/穿透与当前电脑显卡、DPI、任务栏的兼容性。
- 未确认本机非 PATH 目录是否已有 Godot；没有修改引擎环境。
- 未审核全部候选依赖与素材，尚不能直接打包销售。
- 未验证真实文件移动恢复、异常恢复和清理能力；本轮没有读取或移动用户废弃文件。
