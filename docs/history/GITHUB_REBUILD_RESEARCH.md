> 历史设计/交付记录，当前玩法以仓库首页和权威配置为准；历史生成日志和截图不全部纳入Git。

# 奶蛙原版桌宠与战斗重构：GitHub 调研

日期：2026-10-28。依据用户最新反馈，先调研，不继续给当前版本叠加外观补丁。

## 结论与范围修正

桌宠回到 **yugh6/Naiwa 原项目源码**，保留原素材、原交互、原托盘与设置，只扩展“进入游戏”等必要入口。游戏继续采用 Godot 4.7.2；桌宠与游戏分别运行，通过明确的启动与返回协议衔接。此前“一个 Godot 进程重做两种模式”的选型不再作为后续方向。

战斗需要同时重做动作资产、脚底定位、招式时序和敌人决策。GitHub 上有可用的局部基础，但没有发现一个既带原版奶蛙动作、又带成熟横版战斗和合适 UI 的一键替换项目。

本轮实际阅读了下列仓库的 README、许可证及部分代码/场景。**没有安装或运行候选项目，也没有验证它们在本机的游戏手感。** 文件来源、blob SHA 与读取内容见 [证据记录](../research/github-rebuild-evidence.json)。blob SHA 是文件标识，不等于锁定整个依赖版本。

## 当前问题的具体证据

### 桌宠被重新实现，原有设计丢失

[原版 Naiwa.cs](https://github.com/yugh6/Naiwa/blob/72c763fe1349fb08a06f976e1709f4f5f80e09c7/%E6%BA%90%E7%A0%81/Naiwa.cs#L258) 使用 `UpdateLayeredWindow` 显示带 alpha 的完整位图；`LayeredSurface.Hit()` 读取当前画面 alpha，窗口命中测试据此处理透明部分。原版 `BuildMenu()` 在第 409 行，原有菜单和行为可以直接保留并扩展。

原项目具备转眼、眨眼、戳肚子、完整大笑及笑倒、拖动倾斜与松手回弹、托盘、大小/声音/置顶设置、全屏自动隐藏、多屏位置恢复和单实例唤醒。当前 Godot 版本只重做了其中少量行为，因而即使外形相似，也不是原版桌宠体验。

当前 `prototype/scripts/main.gd:482` 使用 `mouse_passthrough_polygon`。Godot [官方文档](https://docs.godotengine.org/en/stable/classes/class_window.html#class-window-property-mouse-passthrough-polygon) 明确说明：Windows 上多边形外的窗口内容也不会绘制。这使固定遮罩、窗口缩放、DPI 和动画轮廓的匹配成为裁切风险。**这是“少腿”的明确排查方向，尚未通过原版与当前窗口在相同 DPI 下的对照实验确认全部原因。**

后续修复应复用原版逐像素窗口，不再靠扩大固定多边形反复试错。

### 动作并没有真正形成完整动作集

当前 `fighter.gd` 中 `attack0/attack1/attack2` 全部读取同样的 `attack_0..3.png`；跳跃动作直接读取 `run_3.png`。三个连招段落只有速度和判定参数差异，缺少不同出招姿态、收招、落地和转身动作。

`prepare_v2_assets.py` 把各姿态按自己的外轮廓裁切后居中，再统一放到底部留白处。这没有保存骨盆、支撑脚、手掌等稳定参考点。固定缩放和硬切动画无法修复素材本身的不连续。

本轮读取实际 PNG 的 alpha（阈值 24）：画布均为 384×448，可见轮廓底部在 y=435～437；运行时图片中心在 y=-112，缩放为 0.5，图片底部恰好落在物理原点，因此画面轮廓仍有约 **5.5～6.5 个游戏坐标单位**的底部空隙。该值按 alpha 轮廓测得，不等于逐帧标注的脚底位置，但能解释一部分悬浮观感。

当前按住攻击会持续填充输入缓冲，连招重复性很高；敌人数量、生命和伤害的增加也不能代替进攻选择和反制空间。需要设计“敌人暴露破绽—玩家判断—命中反馈—敌人反击”的实际循环。

## 最值得使用的项目

| 项目 | 本轮核实的内容 | 用在我们这里 | 采用边界 |
|---|---|---|---|
| [yugh6/Naiwa](https://github.com/yugh6/Naiwa) | 原版 v1.2.2；WinForms/.NET Framework；原生透明窗口、Renderer、命中测试、BuildMenu | **直接作为桌宠宿主**，菜单增加游戏入口，保留全部原功能 | PolyForm Noncommercial 1.0.0；保留原声明；不把它当成 MIT 素材 |
| [Godot 官方 Skeleton2D Demo](https://github.com/godotengine/godot-demo-projects/tree/master/2d/skeleton) | `project.godot` 声明 4.7；`player.gd` 在物理移动后更新 AnimationTree，按实际水平速度调整步行动画速度，区分跳、落、轻重落地；场景含四肢骨骼和动画轨道 | **动作播放结构的首选参考**：移动速度与步频同步、落地衔接、骨骼连续运动 | MIT，示例 GBot 与初始绑定也明确 MIT；没有奶蛙绑定，也没有完整近战系统或自动脚底锁定 |
| [aminRX/shoto-fighter-godot](https://github.com/aminRX/shoto-fighter-godot) | `fighter/states/attack.gd` 用 startup/active/recovery 分阶段；`core/combat.gd` 检查有效期、攻击/受击框、无敌、格挡，再触发命中停顿 | **战斗逻辑首选参考**：每招数据、有效帧、收招风险、取消窗口、命中去重与反馈事件 | 1 对 1 格斗，不是横版闯关模板；代码 MIT；仓库声明 KFM 素材为非商业许可，素材不上线复用，也未独立确认上游素材授权链 |
| [limbonaut/limboai](https://github.com/limbonaut/limboai) | `07_agent_melee_nuanced.tres` 实际包含绕侧、接近连击、投掷，带不同权重、等待和绕侧冷却；不是只有“追过来攻击” | **敌人决策首选参考**：近战试探、绕位、远程牵制、Boss 招式分支 | 插件为原生 C++；README 兼容表列 1.8.x GDExtension 为 4.6+、module 为 4.7，但顶部支持提示仍写 4.6，须固定版本后实测 4.7.2；代码 MIT，demo 美术另标 CC BY 4.0 |
| [GDQuest Open RPG](https://github.com/gdquest-demos/godot-open-rpg) | README 要求 Godot 4.7.2+；实际读取行动菜单代码，包含焦点循环、鼠标/键盘选择、禁用项、返回和选择反馈 | **菜单与养成 UI 的结构参考**：共享组件、状态明确、手柄/键盘可操作、稳定焦点 | 回合制 RPG；不采用它的回合制战斗；根代码 MIT，素材与插件仍逐项核对；像素风皮肤不直接套给奶蛙 |
| [saltmire/saltmire-juice](https://github.com/saltmire/saltmire-juice) | Godot 4.6+；README 与 MIT 许可已核实；功能包括震动、停顿、闪色、弹性缩放、池化伤害数字；搜索到 `juice.gd` 的全局 time_scale 停顿实现 | **小型打击反馈工具候选**，减少重复写基础效果 | 项目规模小，未实机验证；它不能制作攻击动作或修复判定；全局时间缩放会影响 UI/计时，不能和现有停顿系统直接叠加 |

推荐组合是“原版 Naiwa + Godot 动画结构 + 小型招式数据层 + 一套敌人 AI”。这不是把上表所有项目同时装进去；Shoto 主要读逻辑，Skeleton2D 主要读动画组织，素材仍需按奶蛙身份制作。

### 备选与暂不采用

- [godot-statecharts](https://github.com/derkork/godot-statecharts)：MIT，Godot 4+，支持层次状态、条件与延迟转移；`CHANGES.md` 的 0.22.5 明确记录 Godot 4.7 兼容修正。适合管理地面/空中/攻击/受击，但不生成动画。若原生 AnimationTree 与小型战斗状态机足够，就不再加一套框架。
- [Beehave](https://github.com/bitbrain/beehave)：MIT，纯 GDScript 行为树；当前 README 将 2.10+ 对应到 Godot 4.5+。如果 LimboAI 二进制兼容或分发负担不合适，可作为替代；两套 AI 不并用。
- [Fray](https://github.com/Pyxus/fray)：MIT，Godot 4.2+，有输入缓冲、状态与判定框组织；本轮读取了缓冲推进源码。但作者明确标记 alpha，缺少充分验证和完整示例、API 可能变化，暂不作为主框架。
- [Castagne](https://github.com/panthavma/castagne)：专门的格斗引擎层，适合研究完整格斗工具链；主要 MPL 2.0，素材和外部依赖另有许可。此次只核实 README，未核实具体引擎版本，不作为当前依赖。
- [OpenBOR](https://github.com/DCurrent/openbor)：类型上非常贴近横版清关，官方 README 可作为玩法和成熟作品入口。但它是另一套完整引擎，未核实本次所需文件的具体许可证与移植成本，暂不搬源码或承诺迁移。
- [Godotneers ui-video](https://github.com/godotneers/ui-video)：代码 MIT、README 声明图片公有领域，工程声明 Godot 4.0；适合容器和自适应 UI 基础。它不能直接给出本游戏的美术方向。

## 角色动画必须单独解决

本地检查原版 `素材.nwp`：450 个条目，只有 JSON 和 PNG，未包含可直接拿来绑定跑步、出拳的 3D 模型。原项目的大笑可以完整保留，但不能把“大笑的 422 帧”误当成现成战斗动作库。

优先做一个可反复检查的奶蛙动作样片：待机→起步→跑步→刹停→第一击→第二击→收招→受击→站稳。先完成这条链，再扩地图、敌人和特效。

推荐从**同一角色绑定**输出连续动作：如果能取得有许可的原模型，使用同一模型制作并预渲染；没有模型时，需要制作保持原比例与特征的分层角色/网格绑定，补齐遮挡部分。官方 Skeleton2D 提供技术结构，不提供这部分美术工作。独立生成少量姿态再加插值，很难维持手脚结构、体积和运动轨迹，不能继续作为正式方案。

动作制作与接入约束：

1. 角色物理原点放在地面脚底；visual 子节点负责身体上下起伏，脚步不由整图边界推断。
2. 所有帧使用同一画布、比例、朝向和根参考，禁止每帧自动裁切再居中。标注支撑脚、手掌/攻击接触点。
3. 走跑循环按实际速度推进；落脚阶段减少滑动。骨骼过渡也不能代替支撑脚约束。
4. 攻击准备、有效、收招由同一招式时钟推进；动画、判定、音效、掌风与命中停顿读取同一时间线。命中反馈只由实际命中事件发出。
5. 普通步态可混合；攻击接触帧和判定切换保持明确，不能把所有状态都做模糊淡入淡出。
6. 站地、空中、落地和倒地有各自动作；三段连招使用三个不同动作，不能靠同一组图改速度冒充。

## 难度与打击感怎么落地

本游戏是横版战斗，LimboAI 示例的二维绕侧不能照抄成上下移动；要投影为横向保持距离、换边或跳越。下面是结合参考源码提出的设计，不是候选项目已替我们实现的功能。

| 敌人角色 | 决策与可读提示 | 玩家应对 | 避免的问题 |
|---|---|---|---|
| 近战小兵 | 接近到攻击距离，短前摇，挥空后有可惩罚收招 | 拉开、闪避后反打 | 全程贴脸、无限硬直 |
| 远程单位 | 保持射程，先提示瞄准方向再发射，受压时换位 | 跳越弹道、冲刺切入 | 屏外无提示攻击 |
| 护甲精英 | 正面部分招式抗硬直，蓄力招式有大破绽 | 诱招、绕后、重击破势 | 只堆血量造成拖时间 |
| Boss | 分阶段组合招式，阶段切换有提示，连招后有稳定反击窗口 | 辨认节奏、资源管理 | 随机瞬发、靠数值碾压 |

设置组队进攻预算，限制同时发起近战攻击的数量，并让远程单位参与节奏；难度通过决策频率、组合、预警长度和资源压力逐步提高。追求玩家能看懂的失败原因，不把“更难”做成更高血量。

打击反馈先处理命中位置与方向、受击姿态、击退和碰撞，再分轻/重/破防配置停顿、音效、闪光和镜头冲量。出招时可有掌风；只有打中才有命中爆点。特效挂到手掌或武器轨迹，不从人物中心凭空生成；避免每次轻击全屏强闪和同样幅度的抖动。

## UI 采用什么，而不是只换颜色

UI 代码参考 Open RPG 的组件与焦点管理。图标/基础控件可参考 [Kenney UI Pack](https://kenney.nl/assets/ui-pack)，官方页标明 430 个文件、CC0；不从未经核实的第三方素材镜像整包复制。

本游戏应统一为围绕原版黄色奶蛙的一个视觉体系：稳定的字体层级、面板边缘、图标线条、颜色语义和间距。奶蛙是柔和立体形象，像素素材包只能作结构参考，不能直接和当前大面积写实背景、不同风格按钮混搭。

- 桌面：保持原版干净形象和原生右键菜单，增加入口，不悬挂永久战斗面板。
- 战斗：边缘放生命/资源/技能和 Boss 信息，中央保留战斗视野；攻击预警、掉落和受击效果各有清楚语义。
- 喂食：清楚展示虚拟文件选择、可得经验、等级变化和新增能力；主操作只有一个明确入口。
- 设置/暂停：保持统一组件、清楚焦点、键鼠/手柄返回行为和缩放支持。

应先做“营地喂食”和“真实战斗画面”两张包含实际内容的 UI 样稿，然后接回运行时。容器正确、测试通过，不等于画面已经好看。

## 下一阶段执行顺序与验收

1. **恢复原版桌宠**：从固定 commit 单独建修改版，原仓库保留只读参考；最小改动加入“进入游戏”。验证站立全身、原大笑/笑倒、戳肚子、拖拽、托盘、全屏隐藏、大小、多屏与单实例；重点覆盖 100%/125%/150% DPI。
2. **建立启动/返回协议**：桌宠启动或唤醒唯一游戏进程；进入游戏后仅按约定临时隐藏，退出/异常后恢复。避免恢复逻辑覆盖原版全屏隐藏状态。游戏先保持唯一成长存档写入者，桌宠以后通过命名管道等方式发送命令/读取快照，不能让两端各自写同一 JSON。入口阶段不必先引入复杂 IPC。
3. **完成一个角色与一个敌人的动作战斗样片**：先验证连续动作、脚底接地、招式有效帧、收招和受击，再确定依赖。通过慢速播放、判定框覆盖与实际手动操作共同验收。
4. **接两类敌人与一个 Boss 小关**：有近远配合、可读前摇、反击窗口、失败与重试；验证一味按住攻击不能覆盖全部情形，升级也不能抹去全部操作要求。
5. **统一 UI 与反馈**：使用样片中的真实场景确认读数和遮挡，统一组件、音效和轻重反馈，再扩内容。

本轮只写调研与路线修正，没有替换当前程序，没有读取、移动或删除用户投喂文件，也没有修改已有角色进度。继续使用虚拟文件。原型现有检查能证明部分逻辑与存档路径可用，不能作为动作自然、UI 美观或难度合适的证据。

## 来源与许可备注

Naiwa 的 [LICENCE](https://github.com/yugh6/Naiwa/blob/main/LICENCE) 为 PolyForm Noncommercial 1.0.0。商业计划不能因其他组件为 MIT 而自动取得奶蛙的商业使用许可；继续研究原型不等于取得商用授权。后续若转商业方向，应先解决原角色和源项目的授权范围。本轮没有联系作者或发布任何修改版。

主要源码定位：

- [Naiwa 完整窗口与菜单](https://github.com/yugh6/Naiwa/blob/72c763fe1349fb08a06f976e1709f4f5f80e09c7/%E6%BA%90%E7%A0%81/Naiwa.cs#L258)。
- [官方骨骼角色控制](https://github.com/godotengine/godot-demo-projects/blob/master/2d/skeleton/player/player.gd)、[骨骼场景](https://github.com/godotengine/godot-demo-projects/blob/master/2d/skeleton/player/player.tscn)。
- [Shoto 招式状态](https://github.com/aminRX/shoto-fighter-godot/blob/3d44da0a26db269e3b6d7a4939fb657533548d39/fighter/states/attack.gd)、[命中处理](https://github.com/aminRX/shoto-fighter-godot/blob/3d44da0a26db269e3b6d7a4939fb657533548d39/core/combat.gd)、[素材声明](https://github.com/aminRX/shoto-fighter-godot/blob/main/CREDITS.md)。
- [LimboAI 复杂近战示例](https://github.com/limbonaut/limboai/blob/a2d2ea34732bd6d60de99f5cf60b21b707e6d221/demo/demo/ai/trees/07_agent_melee_nuanced.tres)、[版本与素材说明](https://github.com/limbonaut/limboai/blob/master/README.md)。
- [Open RPG 菜单交互](https://github.com/gdquest-demos/godot-open-rpg/blob/main/src/combat/ui/action_menu/ui_action_menu.gd)、[Saltmire 功能与使用说明](https://github.com/saltmire/saltmire-juice/blob/master/README.md)。
