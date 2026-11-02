> 历史设计/交付记录，当前玩法以仓库首页和权威配置为准；历史生成日志和截图不全部纳入Git。

# 美术与动画纠偏：教程和开源实现核查

核查日期：2026-10-28。研究时用户要求停止不可靠的视觉修改，先寻找教程与开源项目。后续用户已授权按建议制作角色验证场，并允许先采用二维；当前新增 `animation-lab/` 独立二维动作样片。v4 仍不作为默认入口。新样片的实现范围与素材记录见 `animation-lab/README.md`，视觉满意度尚未获得用户确认。

## 先说明失败原因

1. 用程序近似形体替代了角色校型。奶蛙的头、身体曲线、腿部站姿和眼睛比例一起偏移，单独加三档光照无法恢复辨识度。
2. 图片拆片与分段阈值处理造成断层和碎色。原始图片中的阴影已经烘焙，不能当成干净的三维固有色材质。
3. 敌人、环境、UI 同时改造，没有先通过一个真实游戏镜头的小样。程序几何和配色规则提供了统一性，却没有完成造型设计。
4. 上一轮自动检查测到了玩法和部分接触坐标，却不能证明骨骼体积、轮廓、步态或整体美感合格。

工程核查：当前正式入口仍为 `res://v3/slice.tscn`；原版 `assets/naiwa/idle.png` SHA256 为 `2E73E47325E7596CFF8B59A5B690A40A559E4FE5810C2CD545AFFE5772C116E8`。v4 留作未通过试制，不继续扩建。

## 奶蛙素材的现实边界

[Naiwa 作者 README](https://github.com/yugh6/Naiwa/blob/main/README.md) 明确说明待机来自静态原图，大笑来自原视频的 422 帧，眼睛动作也来自原始素材。此前本地检查 `素材.nwp` 得到 449 个 PNG 和 1 个 JSON；没有现成的原作者三维网格、骨架或跑步攻击动作。

因此，“原样保留奶蛙”与“完整三维动作”之间缺的是经过校型的三维资产。换 Shader、装 IK 插件或套一个人类动作库，都不能补齐这一步。本次没有找到可确认是原版奶蛙、可直接绑定使用的三维源模型。优先寻找原始源模型；否则需要基于原始参考的正规建模与逐姿态校对。不得继续把几何拼装当成还原完成。

## 推荐优先采用的资料

### 1. Blender Studio：Stylized Character Workflow + Rigify

- [课程介绍](https://studio.blender.org/training/stylized-character-workflow/chapter/intro-stylized-character-workflow/)
- [Snow 制作过程](https://studio.blender.org/training/stylized-character-workflow/chapter/snow-character-development/)
- [Rigify 官方手册](https://docs.blender.org/manual/en/latest/addons/rigify/index.html)
- [Godot 官方 glTF 导入规范](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html)

作用：建立参考图→形体雕刻→表情/姿态测试→拓扑→绑定的制作顺序。Snow 页面列出概念、头身雕刻、表情测试、Pose test、面部/身体拓扑和转台检查。Rigify 帮助建立控制骨架；它不能替代建模、蒙皮权重和姿态修正。

对我们：先把奶蛙的静态轮廓和脸做对，再制作待机、起步、跑步、刹停及出拳。模型和动画导出 GLB；Godot 官方推荐 glTF 2.0。不要直接使用 Blender 专用材质节点当游戏 Shader。

核查边界：官方检索结果可确认目录与免费介绍/过程条目；本次部分 Blender 正文打开失败，没有声称看完课程或整套课程全部免费。Rigify 为 Blender 随附的 GPL 工具；角色资产许可单独判断。

### 2. GDQuest：当前 Godot 4.7 的动作教学与战斗工程

- [免费教学：Character Movement in 3D](https://www.gdquest.com/library/character_movement_3d_platformer/)
- [教学工程](https://github.com/gdquest-demos/godot-4-3d-character-controller-tutorial)
- [RoboBlast 战斗示例](https://github.com/gdquest-demos/godot-4-3d-third-person-controller)

已读实际文件：教学工程 `project.godot` 为 4.7 / Mobile；`player/sophia_skin/sophia_skin.gd` 通过 AnimationTree 切换 Idle、Move、Fall、Jump。RoboBlast 的 `project.godot` 为 4.7 / Forward Plus；`player/gdbot/gdbot_skin.gd` 包含走跑混合、步频缩放、AttackOneShot；仓库也有 `melee_attack_area.gd`、敌人、爆炸、轨迹和场景资源。

对我们：借用“角色外观与移动逻辑分开、动画片段混合、攻击一次性动画、动画事件同步”的结构，接入我们自己的奶蛙模型。保留横版镜头，不把项目改成第三人称射击。

许可已查：两仓库代码 MIT，图像与三维模型 CC-BY-NC-SA 4.0。不能把整个仓库当作全部 MIT，也不能未经核查将演示角色当作我们的正式敌人。

### 3. Complete Cel Shader：有完整场景和作者讲解

- [仓库](https://github.com/eldskald/godot4-cel-shader)
- [效果、源码入口与视频](https://godotshaders.com/shader/complete-cel-shader-for-godot-4/)
- [作者讲解视频](https://youtu.be/F0LZ_hAci4k)

已核对：自定义 diffuse curve、光照与高光控制、描边；`src/outline.gdshader` 用裁剪空间偏移与 VIEWPORT_SIZE 控制边宽；源码需要完整 includes 与 Shader Globals，不能仅复制页面中的一个文件。代码 MIT。

适配判断：演示工程配置为 Godot 4.5 / Forward Plus，我们当前为 4.7.2 / GL Compatibility，因此列为优先独立对比测试的候选，**不是已经确认即插即用**。当前未将该 Shader 接入正式游戏。演示场景的艺术资源许可与代码许可需要分别核查。

### 4. Godot VRM / MToon：更偏动漫角色的材质候选

- [V-Sekai/godot-vrm](https://github.com/V-Sekai/godot-vrm)

README 明确包含可独立使用的 MToon Shader，支持 Godot 4.0+，实现 VRMC_materials_mtoon。适合检查阴影色、阴影边界和角色轮廓的实现。无需把奶蛙换成 VRM 人形角色；重点是材质系统。

代码 MIT；示例 VRM 有各自许可。README 也列出约束重定向等已知问题，不能因“Godot 4.0+”便宣称我们当前整个流程已兼容。需在当前渲染器中检查蒙皮、描边接缝、远近宽度后再选定它或 Complete Cel Shader。

### 5. Bramwell：Godot 4 风格化植被完整教学

- [Godot-4-3D-Stylized-Grass](https://github.com/bramreth/Godot-4-3D-Stylized-Grass)
- 作者视频入口在仓库 README。

仓库包含 Blender/Godot 制作草的教学源工程、真实草模型和 shader 示意。许可证 MIT。原工程为 Godot 4.0 / Forward Plus，最近代码提交仍是 2023 年，需要迁移核查。

对我们：学习植被法线、顶点摆动和块面色的制作方法，避免把一排三角形当完成的森林。它只解决植被的一部分，不是完整森林关卡或现成动漫场景包。环境构图仍需真实横版镜头校验。

### 6. Effekseer：把斩击和大招做成可调的资产

- [编辑器、范例与教程](https://effekseer.github.io/en/)
- [Godot 4 插件](https://github.com/effekseer/EffekseerForGodot4)
- [1.80.5.1 插件版本](https://github.com/effekseer/EffekseerForGodot4/releases/tag/1.80.5.1)

官方工具可制作和导出 2D/3D 效果，有示例效果及文档。核对插件最新 release 为 1.80.5.1，说明中特别列出修复 Godot 4.7 脚本错误；编辑器与插件版本号不同。

对我们：在编辑器里制作出手轨迹、命中核心、碎片、收尾消散，再按真实攻击时间播放；轻击、破势重击和大招使用不同节奏。插件之前已列为候选，本轮再次核实，尚未安装到正式项目。运行时代码 MIT；具体范例素材仍按其来源许可使用。

## 次级候选与排除项

- [FlexibleToonShaderGD-4.0](https://github.com/atzuk4451/FlexibleToonShaderGD-4.0)：MIT，有色阶、色带、最强灯光限制。README 对 ATTENUATION 移植准确性有作者保留说明，代码更新较旧，作为小型对照，优先级低于上面两种材质候选。
- [Johnz86/locomotion-godot](https://github.com/Johnz86/locomotion-godot)：4.7.1 教学，包含 root motion、gait profiles、foot placement 和击打。README 坦诚模型依赖和脚滑限制，实用性值得研究；本次完整目录未见 LICENSE，动画来自外部角色包，暂不列为可直接复制的开源依赖。
- [旧 GDQuest 3D Mannequin](https://github.com/gdquest-demos/godot-3d-mannequin)：有绑定思路，但主线为 Godot 3.2，不能当成 4.7 的即用模板。
- 网上展示视频、Shader 截图与现成角色都不能证明接到奶蛙模型后一定好看。没有当前平台实际试验的条目明确保持“待验证”。

## 菜单仍采用已指定的研究来源

[INKWAVE](https://github.com/amiaoapp/inkwave) 是用户明确指定的菜单参考，MIT，Three.js 项目。此前已经读过主菜单、焦点与弹性动画实现。保留其清楚的主次层级与响应节奏，转换为 Godot 原生 UI；不重新塞入另一种不相干的卡片仪表盘风格。具体颜色和图形仍需与经过验收的角色/场景共同决定。

## 建议的下一次制作范围

先做**一个角色校型与动画验证场**：原版奶蛙参考、候选三维模型、相同正交镜头、纯净背景。验证正侧面、完整双脚、眼睛、腹部、三种关键姿态；再比较待机→跑步→刹停与一次完整攻击。材质在同一模型上对比两种成熟 Shader。

这一关没有通过，不扩建整关、重画 UI 或批量生成敌人。通过后再用一个敌人、一段场景和一套斩击确认整体效果。这里是对当前失败的范围纠正，不是声称资产已经制作完成。

本轮核查的是官方文档、README、工程配置、许可证与具体动画/Shader 源码；没有宣称完整观看视频、试玩远程工程或通过本地渲染兼容性测试。版本记录见 `research/cel-correction-evidence.json`。
