> 历史设计/交付记录，当前玩法以仓库首页和权威配置为准；历史生成日志和截图不全部纳入Git。

# 战斗与视觉第二版

2026-10-28，Windows / Godot 4.7.2。继续使用虚拟文件，保留现有角色存档。

## 已落实的修改

- 奶蛙新增 4 帧跑步、4 帧攻击、4 帧受击图像，由 AnimatedSprite2D 播放；腿、手臂和躯干姿势实际改变。保留原形象，待机和桌宠仍用原项目素材。
- 三段攻击分别配置动作时长、有效帧、位移与反馈；伤害不会在起手帧提前发生。J 可按住连续出招。受击会中断攻击并播放后仰，瞬步保留无敌与连续残影。
- 攻击弧改为多层尖端渐细的掌风，第三段附加强斩线与更长的命中停顿；命中有短闪白、辐射火花、数字阴影、击退/击飞、连击显示与撞边反馈。特效层位于角色上方。
- 两套原创敌人图像：损坏档案猎犬、档案守卫。分别有移动、蓄力、攻击与溶解死亡表现，保留原有战斗和奖励结构。Boss 使用独立顶部血条。
- 新的档案温室场景图像，替换几何楼房；地面与碰撞高度对齐。背景和粒子保持较低亮度，奶蛙与攻击效果优先可读。
- 营地重排为左侧角色档案、右侧可滚动碎片列表；使用纸色、墨绿与金色。战斗去掉网页式导航栏，生命放左下、动作提示放右下，中央留给战斗。
- 新合成音效使用噪声、扫频和低频冲击叠层；8 路复用，命中不会立即切断挥击声。

## 桌宠黑框

旧版虽然导出的 PNG 有 alpha，但真实 Windows 窗口仍有黑底，说明原验收未覆盖系统合成。现在在 project.godot 启动时同时启用 window/size/transparent、per_pixel_transparency/allowed 与 viewport/transparent_background；切换普通模式时保留原生透明能力，普通游戏场景自行绘制不透明背景。

桌宠缩为 240×320，常态不绘制信息栏、提示文字或工具条；右键菜单可进入战斗、营地、返回与退出。使用原素材各姿势 alpha 的凸包生成窗口区域，使外围点击能穿过。左键拖动和双击短开心动作保留。

真实 Windows 窗口已查看：奶蛙外围能看到后方桌面内容，没有旧版黑框。PNG alpha 检查也确认外围为 0。二者是不同的验证，不能以 PNG 透明替代桌面验证。

## 参考及采用方式

- [《Hades》官方页面](https://www.supergiantgames.com/games/hades/)：研究动作游戏的画面主次与克制 HUD，不复制其美术。
- [Saltmire Juice](https://github.com/saltmire/saltmire-juice)：参考命中停顿、短闪光、震动和数字反馈的分层思路。未引入第三方代码依赖。
- [GDQuest Open RPG](https://github.com/gdquest-demos/godot-open-rpg)：参考角色成长、背包与菜单职责分离。它是回合制教学项目，不当作横版战斗模板。
- 前面取得的《断帧》代码：参考起手/出手/收招节奏、短输入缓冲、残影、重击和撞击反馈，未复制其美术或游戏脚本。
- [Godot 透明窗口官方设置](https://docs.godotengine.org/en/stable/classes/class_projectsettings.html#class-projectsettings-property-display-window-size-transparent)：核对窗口透明与根视口透明均需启用。

## 素材与生成记录

使用内置 image_gen，以奶蛙原图为参考生成新的动作图；敌人与场景为新生成的原创游戏资产。生成的格子并不严格均匀，因此使用 alpha 连通域分离角色、移除离散噪点，再统一源比例与脚底基线。没有把带背景或未对齐的大图直接拿来播放。

- 运行素材：`prototype/assets/v2/hero/`、`enemies/`、`audio/`、`archive-background.png`。
- 原始生成图、裁切坐标和接触表：`art-source/v2/`。
- 完整提示词记录：`art-source/v2/generation-prompts.md`。
- 归一化脚本：`tools/prepare_v2_assets.py`；音效脚本：`tools/synthesize_v2_sounds.py`。
- 奶蛙原作者与非商业许可仍保留在 `prototype/CREDITS.md` 和 `assets/notices/`。动作衍生图不改变原角色的授权边界。

## 验证与局限

无窗口集成检查通过 22 项，包括跑步帧推进、起手不提前伤害、动画与实际伤害同步、受击切换、无常驻桌宠 UI、菜单回营地以及三波胜败。独立存档检查通过 8 项。场景引用检查无错误或警告。实际 GPU 窗口截图没有脚本或着色器错误。

截图在 `prototype/artifacts/`：`camp-v2.png`、`run-v2.png`、`battle-v2.png`、`hurt-v2.png`、`pet-v2.png`。其中战斗截图是隔离视觉检查场景，临时布置了敌人与 Boss，用于检验比例、有效帧和特效；它不会写入玩家存档。

仍需继续打磨：四帧循环的平滑度、敌人动作过渡、更多攻击分支与战斗平衡。新动作是基于参考生成的图像，存在轻微体型变化；不是已完成的高帧数专业动画资产。多屏/DPI 和长时间性能未做完整矩阵测试。
