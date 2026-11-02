# 开发、构建与检查

## 环境

- Godot 4.7.2 Standard，Compatibility渲染。
- Windows桌宠使用C#、WinForms、.NET Framework及固定Roslyn工具包。
- Python 3.12用于素材、字体、下载和打包。
- Node.js 20+用于独立加载器校验；游戏网页没有npm依赖或前端打包前置要求。
- 素材/字体工具依赖安装：python -m pip install -r requirements-dev.txt。

## 运行源码

先用Godot导入prototype/project.godot。命令行首次导入：

```powershell
python tools/bootstrap_windows.py
& tools/Godot_v4.7.2-stable_win64.exe --headless --path prototype --editor --import --quit
& tools/Godot_v4.7.2-stable_win64.exe --path prototype
```

默认运行进入正常首页。参数中的--slice-test用于隔离验证，可能自动进入检查流程；不要把它放进普通玩家启动器。

## 桌宠构建

```powershell
python tools/prepare_lin4run_desktop.py --download
powershell -NoProfile -File desktop/lin4run/build.ps1
```

脚本下载官方发行资产和编译器，校验固定哈希。完整维护源码在desktop/lin4run/source；准备脚本使用copy-if-missing，不覆盖维护版本。官方包约187MiB，Git中保留源码、许可和来源记录，不存整份重复下载缓存。

## 网页直接验证

```bash
python tools/check_publication.py
node --check web/dist/app.js
node --check web/dist/cover.js
node tools/verify_web_loader.cjs
python -m http.server 8765 --bind 127.0.0.1 --directory web/dist
```

GitHub Actions执行前四项，并将web/dist部署到Pages。加载器测试覆盖正常流、网络中断、截断、校验不符与永久失败，并比较还原数据，避免重试拼接重复块。

## 从Godot重建Web

已提交web/dist成品；仅修改文档不需要重新导出游戏。修改游戏后使用下列流程：

1. 安装requirements-dev.txt，运行python tools/fetch_web_template.py获取匹配4.7.2模板。
2. python tools/prepare_web_project.py准备production/web-project隔离副本。
3. 使用Godot编辑器导入副本，再在导出界面建立名为Web的预设。也可以运行工具web_export_preset.gd，让编辑器平台工厂生成预设。示例：

```powershell
& tools/Godot_v4.7.2-stable_win64.exe --headless --editor --path production/web-project --script ../../tools/web_export_preset.gd
```

4. python tools/build_web_export.py
5. python tools/package_web_static.py
6. python tools/prepare_web_cover.py
7. python tools/check_publication.py

网页副本替换系统字体为随包Noto字体，独立用户目录、单线程Web模板，大图仅在副本中压缩。不会回写原生工程或用户存档。

## 战斗回归

在资源导入完成后，可以运行隔离检查：

```powershell
& tools/Godot_v4.7.2-stable_win64.exe --headless --path prototype -- --slice-test --punch-review
& tools/Godot_v4.7.2-stable_win64.exe --headless --path prototype -- --slice-test --rift-review
& tools/Godot_v4.7.2-stable_win64.exe --headless --path prototype -- --slice-test --ultimate-review
& tools/Godot_v4.7.2-stable_win64.exe --headless --path prototype -- --slice-test --loop-review
```

头部既有336项记录的来源在docs/validation/punch-delivery.json。部分GPU呈现与音画判断仍需实际有图形设备的运行环境，CI的静态检查不代替视觉检查。历史平衡测试可能编码了旧版数值，修改规则时应核实断言是否仍表达当前设计，而不是简单删除失败项。

## 重录GitHub效果图

当前仓库提供prototype/showcase/github_capture.tscn，调用真实游戏模块重新布置四境、连击、二段跳、觉醒、遗物和商城。使用：

```powershell
& tools/Godot_v4.7.2-stable_win64.exe --path prototype res://showcase/github_capture.tscn --fixed-fps 30 -- --bridge-check
```

要求有可用GPU。使用--bridge-check是为了关闭正式存档且不自动触发基础回归检查。输出到docs/media；该场景不参与正常游戏入口。录制敌人、等级和无敌条件见capture-manifest.json，不将这些展示条件宣传成普通开局。

素材处理脚本有一部分属于历史作者工具，可能需要没有随仓库分发的原画工作文件。运行已有游戏和构建桌宠不依赖重新执行所有历史素材工具。

## 新增内容入口

- 小兵/Boss：combat/enemy_catalog.gd、biomes/content.gd，再接动作/VFX/AI。
- 地图：biomes/content.gd和campaign/levels.gd，同时提供场景、平台与地面锚点。
- 皮肤：wardrobe/catalog.gd，资源齐备再发布。
- 命中反馈：punch/director.gd，使用实际命中事件，避免空挥触发目标爆点。
- 投喂：先通过DropFeedService完成系统回收，再写回执；不要由UI动画直接增加成长量。
