> 历史设计/交付记录，当前玩法以仓库首页和权威配置为准；历史生成日志和截图不全部纳入Git。

# 奶娃大招 · 开源特效调研

日期：2026-10-28。本轮按“先找开源项目给我看看”执行，只调研并展示上游原始预览，尚未接入大招新效果。当前游戏的U技能已有基础环形冲击，但缺少完整独立的蓄力与爆发表现。

## 优先候选

| 项目 | 上游效果预览 | 用途 | 已核对许可 |
| --- | --- | --- | --- |
| [Effekseer](https://github.com/effekseer/Effekseer) | [tktk vol.2 动态样例](https://effekseer.github.io/zh-cn/contributes/tktk02/index.html) | 蓄力光环、冲击、爆发、速度能量效果 | 程序/Godot插件MIT；所选新样例位于官方CC0区，旧许可样例另列 |
| [Godot Shockwave Shader](https://github.com/shizu0817/godot-shockwave-shader) | README中有两张冲击波动图 | 爆发瞬间的背景折射与冲击扩散 | 代码MIT；演示场景的第三方素材另看来源 |
| [Godot VFX Library](https://github.com/haowg/GODOT-VFX-LIBRARY) | [效果总览](https://github.com/haowg/GODOT-VFX-LIBRARY/blob/main/preview_en.png) | 能量爆发、连锁电光、召唤圈及粒子管理 | MIT |

Effekseer有[Godot 4插件](https://github.com/effekseer/EffekseerForGodot4)，官方也支持把特效导出为2D动画。当前工程是Godot 4.7.2的Compatibility渲染器，优先考虑导出透明序列帧，与现有角色完整帧方案配合；本轮未安装插件或验证其在当前工程中的表现。

所选tktk vol.2包含43个效果，官方展示页列出冲击、爪、暗、火、铳、光、枪、剑等分类。上游提示其图像输出适合UV动画，并提醒原始效果渲染负担和扭曲处理需要注意。因此应选择、重配色和裁定播放规模，不直接把所有效果堆在一招上。

Shockwave项目已读到真实 `canvas_item` 源码，使用 `hint_screen_texture`，参数包括中心、半径、环宽、强度与色差。作者提供三个演示场景，并提示每个冲击波使用BackBufferCopy可能有开销。奶娃必须单独后绘，让背景扭曲只影响背景，不扭曲人物外形。

Godot VFX Library已核对真实的 `energy_burst.tscn`、`lightning_chain.tscn`、`summon_circle.tscn` 与交互演示场景；前两者使用CPUParticles2D。本轮未在本地运行，因此不将其描述为已经完成兼容性或视觉品质验收。

## 建议的第一招

“蓄力贯穿拳”：短暂沉身蓄力，脚边出现收拢光环和向拳头汇聚的粒子；侧身挥拳，金色核心、青绿色边缘的拳风向前贯穿；命中时爆出冲击与地面碎屑，并配合短停顿；随后快速消散。奶娃人物继续使用完整侧身画稿，特效在独立层绘制。

这需要把特效与动作的蓄力、接触和收势时间对齐，而非只增加一个更大的圆环。具体动作稿、技能规则和效果组合在采纳后制作，本轮没有擅自批量生成新人物。

## 次选与素材边界

- [Kenney Particle Pack](https://kenney.nl/assets/particle-pack)：CC0，80张512×512粒子纹理，可补火花、光点和烟尘，属于基础纹理而非完整大招。
- [GDQuest Godot 4 VFX Assets](https://github.com/gdquest-demos/godot-4-VFX-assets)：源码MIT，美术纹理/模型CC-BY-NC-SA 4.0，不能把整库都当作MIT素材。适合学习结构，非本轮首选直接素材来源。

核对的源码与许可文件SHA、预览链接和集成边界保存在 `research/ultimate-vfx-evidence.json`。官方动图仅通过原站浏览，未下载再包装为自制样稿。
