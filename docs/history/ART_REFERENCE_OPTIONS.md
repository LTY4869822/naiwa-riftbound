> 历史设计/交付记录，当前玩法以仓库首页和权威配置为准；历史生成日志和截图不全部纳入Git。

# 先看实图，再选择整体美术方向

更新：用户随后指定全局采用原创动漫感三维赛璐璐，并否定了首轮程序化试制，要求先继续查教学与开源项目。当前以 [ART_RESEARCH_CORRECTION.md](ART_RESEARCH_CORRECTION.md) 为研究结论；以下是此前的参考历史，不代表最新美术验收。

最新选择（2026-10-28）：用户已指定菜单参考 [amiaoapp/inkwave](https://github.com/amiaoapp/inkwave)，场景与战斗 UI 采用下文 B“柔光童话”。奶蛙保持原版形象。后续制作以 [INKWAVE_ORI_PRODUCTION_RESEARCH.md](INKWAVE_ORI_PRODUCTION_RESEARCH.md) 的研究、资产路线与验收标准为准；下文 A/C/D 保留为比较记录。

2026-10-28。用户要求保持奶蛙形象、改进动作/敌人/背景/菜单，并先看参考图。本轮只做研究和方向对照，不继续把临时模型或新画风写入游戏。

## A：手工玩具与微缩世界

参考：《小小大星球 3》。重点观察木材、布料、纸张的质感，前景遮挡、真实道具的尺度，以及柔和角色如何融入环境。

![小小大星球 3 画面参考](https://images.pushsquare.com/screenshots/63622/large.jpg)

来源：[Push Square 游戏页面](https://www.pushsquare.com/games/ps3/littlebigplanet_3)。方向判断：最接近奶蛙当前柔软立体的外观，可用于形成统一的纸张/木材/旧物世界；不改变横版镜头，不复制原作人物、标志或场景。

## B：柔光童话与有层次的背景

参考：《奥日与萤火意志》。重点观察近景轮廓、清晰的可行走区域、逐渐淡去的远景和主光源。不是在每个物件上添加同样的发光。

![奥日场景参考](https://cdn.staticneo.com/ew/9/9b/Ori_And_The_Will_Of_The_Wisps_3_25_2020_9_35_11_PM.png)

来源：[Neoseeker 实机攻略截图](https://www.neoseeker.com/ori-and-the-will-of-the-wisps/Wellspring_Glades)，另见[官方媒体页](https://www.orithegame.com/media/)。方向判断：可以学习明暗与深度组织；整套绘画风格需要专门的场景资产，不能只靠把现有方块背景模糊。

## C：克制的立体场景与清楚的敌人轮廓

参考：《死亡之门》。重点观察大体积、独特轮廓、简洁材质和战斗焦点；敌人不需要都做成站立人偶。

![死亡之门场景与敌人参考](https://images.gamersyde.com/image_death_s_door-43662-4781_0001.jpg)

来源：[Gamersyde 游戏画面](https://www.gamersyde.com/news_death_s_door_new_trailer-22351_en.html)，另见[发行商游戏页](https://www.devolverdigital.com/games/deaths-door)。方向判断：学习材质与角色识别度，当前横版镜头仍保持横版。三组场景图已通过浏览器实际查看，菜单也查看了主界面和物品页；没有把这些参考图下载为游戏资产。

## D：菜单布局单独看《空洞骑士》

本轮通过浏览器查看了主菜单和物品页：主菜单用场景氛围、大标题、短的纵向选项和小型选择装饰；物品页把物品图形、说明和导航分开，避免一屏大按钮。

参考页面：[Game UI Database — Hollow Knight](https://www.gameuidatabase.com/gameData.php?id=113)。该站图片仅供用户查看和布局讨论，不下载到本项目，也不输入图像生成工具。

布局原则可以借鉴，原作边框、Logo、图标和截图不作为本游戏素材。奶蛙菜单应有自身的标题、材质与交互节奏，而不是照抄原作皮肤。

## 保持奶蛙形象的动作路线

保持形象指锁定头身比例、面部、身体轮廓与材质；不等于所有姿态都能从同一张站立 PNG 无损变出。

1. 优先：把原始图分为头、躯干、近远手臂、手掌、大腿、小腿和脚，保留原有像素，补齐原图遮住的关节区域。做真正的分层骨骼绑定，支撑脚锁定地面，肚子只做少量次级运动。
2. 出拳、抬腿等较大动作增加经校型的替换手/脚与过渡关键帧；不靠拉长整张图表达出拳。
3. 若以后取得有许可的原始模型，以同一模型、材质与固定相机输出动作序列，身份一致性更容易控制。本地 Naiwa 包目前只有 PNG/JSON，没有已取得的原模型。

技术依据：[Godot cutout animation](https://docs.godotengine.org/en/stable/tutorials/animation/cutout_animation.html)、[Spine 权重说明](https://en.esotericsoftware.com/spine-weights)、[Spine IK 说明](https://us.esotericsoftware.com/spine-ik-constraints)。Godot 该概念教程提示尚未为 4.7 更新，具体 API 接入仍需按本地版本验证；本轮没有安装或购买 Spine。

## 当前作品为什么显得廉价

- 奶蛙为柔和有体积的原图，敌人为几何人偶，场景是重复方块；三者材质语言、细节尺度和光影不统一。
- 三类敌人主要靠加角或光环区分，缺少能表达行为的外轮廓。
- 背景均匀重复、细节密度相同，缺少主景、远近关系和刻意留白。
- 主菜单、营地和战斗 HUD 缺少独立的目的与信息层级，通用圆角面板过多，字体和图标没有形成游戏自身风格。

下一轮只确定一个整体材质方向，再分别制作战斗构图和菜单样稿。其他参考只借信息层级、构图或动画方法，不把几套画风拼成一套。
