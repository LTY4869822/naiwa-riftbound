# 素材、代码与第三方声明

本项目包含维护代码、角色衍生、生成式图像与多种上游资源。不同部分按各自许可处理，不能因为仓库公开或某个依赖使用MIT，就把完整游戏视为MIT/CC0。

| 来源 | 使用范围 | 许可/说明 |
| --- | --- | --- |
| [yugh6/Naiwa](https://github.com/yugh6/Naiwa) | 原奶蛙形象、动作与笑声来源 | PolyForm Noncommercial 1.0.0及作者声明 |
| [LIN4RUN/naiwa-desktop-pet](https://github.com/LIN4RUN/naiwa-desktop-pet) | 目前Windows桌宠底座与动作资产包 | 随附MIT许可；原角色权利仍需结合其来源说明 |
| [patch-gg/pixelfx](https://github.com/patch-gg/pixelfx) | 命中、破甲、重击等效果配方与导出 | MIT，原版权文本随目录保留 |
| [yuewen-huang/combat-vfx-demo](https://github.com/yuewen-huang/combat-vfx-demo) | 部分攻击VFX资源与实现参考 | 见prototype/third_party/combat_vfx随附许可 |
| [Kenney](https://kenney.nl/) | 粒子与金币音源 | 随附CC0声明 |
| [Godot Engine](https://godotengine.org/) | 游戏引擎与网页运行时 | MIT |
| [Noto Sans SC](https://github.com/google/fonts/tree/main/ofl/notosanssc) | 网页中文字体及子集 | SIL Open Font License |
| [amiaoapp/inkwave](https://github.com/amiaoapp/inkwave) | 菜单组织、墨水贴纸视觉语言参考 | 当前Godot控件和网页布局为本项目实现；未提取商业游戏美术 |

## 保留的原文

- [原奶蛙许可证](prototype/assets/notices/NAIWA-LICENCE.txt)
- [原奶蛙README与作者转载说明](prototype/assets/notices/NAIWA-README.md)
- [LIN4RUN MIT许可](desktop/lin4run/LICENSE)
- [LIN4RUN原README](desktop/lin4run/UPSTREAM_README.md)
- [PixelFX许可](prototype/assets/pixelfx/LICENSE.txt)
- [Godot许可](tools/GODOT-LICENSE.txt)
- [网页字体许可](web/dist/licenses/NOTO-OFL.txt)
- [完整历史素材来源记录](prototype/CREDITS.md)

原奶蛙作者为yugh6（握石竹），分享应注明原作者及项目地址，不得冒充原创。作者README还包含针对短视频/自媒体公开传播的许可要求。上游声明原样保留；本项目的GitHub发布不构成额外的商业或媒体传播授权。

## 自制与生成式资源

十二场景、若干敌人/首领图集、遗物、觉醒动作、招式动画与拾取物使用生成式图像工具参与制作，再通过元数据、锚点和Godot状态编排接入。部分角色形象依据既有角色/用户参考，衍生图像不自动获得原角色的额外权利。

程序合成的命中和治疗声音与既有音源分开记录；来源文件保存在各音频资源目录。未从火影忍者、王者荣耀或喷射战士提取商业角色、场景或技能美术。它们只曾作为表现方向参考。

## 使用建议

使用单个文件前核对其来源和随附许可。计划商业发行、再分发角色包或公开媒体传播时，先处理对应权利；不要只引用本仓库标题或“致谢”作为授权依据。发现来源信息错误，请提交Issue指出具体文件和证据。
