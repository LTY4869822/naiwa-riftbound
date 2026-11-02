> 历史设计/交付记录，当前玩法以仓库首页和权威配置为准；历史生成日志和截图不全部纳入Git。

# 侧身逐帧动作接入 · 2026-10-28

默认入口已从 `prototype/v5/slice.tscn` 切换为 `prototype/v6/slice.tscn`。使用现有“进入奶蛙游戏.cmd”或桌宠菜单即可进入。V5场景保留作历史实现。

## 本轮行为

- 角色始终侧身朝向敌人。前手和后手使用两组独立人物图，都向同一方向命中；左右朝向切换整体人物图，不用翻转来伪造换拳。
- 18张完整图：8张备战/双拳、8张侧向移动、受击和腾空各1张。移动速度驱动步态播放速度；停步有短收势，攻击会立即打断视觉收势。
- 支撑脚按透明轮廓测得的原图脚底设置整体锚点，对齐平台。始终使用统一缩放0.175，没有分肢网格、非等比拉伸、裁切人物或光流变形。
- 拳头位置、碰撞判定和挥击/命中特效在同一物理帧更新。轻击有短停顿，重击有更强的弧光、碎片和震动；设置中可减少动态。
- 游戏补给页使用分页虚拟碎片卡片，选中后喂食获得经验，Lv.2解锁U技能。保留现有菜单墨水风格、正面菜单奶蛙、完整大笑、战斗HUD与成长档案。
- 保留当前LIN4RUN桌宠桥接：进入游戏、最小化返回、恢复同一局、子进程异常恢复。桌宠本身的素材、原动作、程序与文件处理功能未由本轮重写。

## 检查结果

- `prototype/artifacts/v6-checks.txt`：**38项通过，0失败**。覆盖双向双拳、前摇、一次命中、后方不误伤、连击缓存、闪避、受击、脚底锚点、同宽高比、8帧侧向步态、停步中断、虚拟卡片点击后重建、喂食按钮启用、升级、技能与禁用正式存档写入。
- `prototype/artifacts/v6-native-bridge/bridge-test.txt`：**8项通过**，含工作区隔离、隔离补给请求、进入/返回、真实游戏窗口最小化/恢复、同进程继续与异常恢复。
- `prototype/artifacts/v6-balance.txt`：不操作16.6秒失败；策略控制器27.8秒通关，剩63生命，完成2节、击破5个目标。这是自动控制器的结果，不代表人工手感验收。
- `prototype/artifacts/v6-side-visual.log`：实际OpenGL渲染完成，无脚本/绘图错误。已核对左右移动、双拳、跳跃、受击、首领与虚拟补给截图。
- 本轮自动测试均使用隔离标志，禁用正式存档写入。测试前后正式存档哈希一致；用户在本轮制作期间已有自己的存档更新，未用旧哈希覆盖其进度。

## 画稿与处理记录

角色造型基准是用户提供三视图，以及其后确认的侧身备战稿。由内置imagegen逐张制作，每张检查后继续。来源和完整提示词保存在：

- `art-source/character-standard/side-guard-01/generation-record.json`
- `art-source/character-standard/side-attack-01/generation-record.json`
- `art-source/character-standard/side-step-01/generation-record.json`
- `art-source/character-standard/side-reaction-01/generation-record.json`

按用户明确授权，使用 `tools/extract_approved_frames.py --set side` 程序抠图。只改透明度，18张输出的RGB字节与各自输入原图一致，画布尺寸保持1086×1448。报告位于 `prototype/assets/v6/side/extraction-report.json`。这保证抠图没有改人物像素，不表示不同生成姿势之间的绘制细节完全相同。

动作表由 `tools/build_side_runtime.py` 生成，浏览器检查页由 `tools/build_side_motion_review.py` 打包。可打开 `art-source/character-standard/side-motion-01/index.html` 离线查看，或使用本机 `http://127.0.0.1:8846/side-motion-01/`。

## 操作与当前限制

A/D移动，空格跳跃，J按节奏连拳，K重击，L/Shift闪避，U释放技能。Tab回补给，Esc暂停，P返回桌宠。按住J不会自动无限连击。

当前步态为8帧循环，受击和腾空各只有一张主要姿势，重击与大招复用基础拳势并使用不同的时序/特效。它已接入可玩流程，仍需要根据人工试玩继续加过渡帧和打磨手感。

当前为用户打开的“隔离试玩（不保存）”窗口仅供检查；正式游玩使用正常启动入口。原生桌宠自身仍保留既有拖放能力，游戏补给页的卡片是虚拟数据。
