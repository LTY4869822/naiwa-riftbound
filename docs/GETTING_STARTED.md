# 安装与首次游玩

## 选择运行方式

想立即体验战斗，优先使用网页或网页ZIP。想编辑玩法，使用Godot工程。想拖入真实文件投喂，需要Windows桌宠联动版。

### A. 在线或本地网页

在线地址：https://lty4869822.github.io/naiwa-riftbound/

如果当地网络不易访问GitHub，可下载Release的网页ZIP，放到自己的HTTP静态服务器。ZIP解压后根目录是index.html。Python本地启动：

```bash
python -m http.server 8765 --bind 127.0.0.1
```

访问 http://127.0.0.1:8765/ ，点开始，等待资源下载完成。不要以file://打开。浏览器需要支持WebGL2、WebAssembly和DecompressionStream；推荐较新的Chrome/Edge，Safari也需满足这些能力。没有实测所有浏览器/实体手机的兼容性。

第一次下载游戏数据约49MiB，启动封面另约1.2MiB。进度按校验成功的下载字节计算，网络失败按分块重试。缓存是否保留由浏览器决定。

### B. Godot编辑器

1. 克隆或下载源码。
2. 安装Godot 4.7.2 Standard，通常无需.NET版引擎。
3. 导入prototype/project.godot，等资源导入结束。
4. 按F5，默认进入正常首页。默认入口为v6/slice.tscn。
5. 在首页选择地图，再开始冒险。

不要从旧v3/v4测试场判断正式入口；它们保留用于历史实现对照。普通玩家也无需运行带F1–F12演示切换的启动器。

### C. Windows桌宠联动

先准备Python 3.12及.NET Framework 4.x，然后在仓库根目录执行：

```powershell
python tools/bootstrap_windows.py
python tools/prepare_lin4run_desktop.py --download
powershell -NoProfile -File desktop/lin4run/build.ps1
```

bootstrap_windows.py将固定版本的官方Godot运行器放入tools。桌宠准备脚本下载固定的LIN4RUN v2.5.1动作包和NuGet Roslyn编译器，校验大小与SHA256。维护源码不会被上游覆盖。下载依赖网络，国内环境可能需要自行改善GitHub/NuGet连接。

在Godot编辑器中至少导入一次prototype/project.godot后：

- 启动奶蛙原型.cmd：启动联动桌宠。
- 进入奶蛙游戏.cmd：由桌宠进入游戏，支持返回与恢复。
- 单独编辑运行游戏时，直接使用Godot F5即可。

原始大体积桌宠动作和编译产物没有纳入Git历史；首次运行上面的准备与构建步骤不是可省略步骤。此版Release提供网页版部署包；尚未提供已签名Windows安装程序。

## 首次操作建议

先使用A/D移动与Space二段跳熟悉范围，再尝试J连击、K重击、L闪避和U奥义。留意体力和专注，不要持续空挥。R需要魔能满100、落地并处于可释放状态。Boss预警后会留下收招窗口，重击和精准闪避都服务于抓住这个窗口。

## 文件投喂

只把自己明确不再需要的文件或文件夹拖入桌宠。成功回收后才记入成长；取消与失败不会增加。原文件移入Windows回收站，可按系统规则尝试还原；后续清空回收站不是游戏自动操作。已经记录的成长账本不会因为你还原文件而自动倒扣。

程序按实际文件字节数统计，8MiB兑换1XP，余数继续保留。不会为了升级而自动扫描并清理整台电脑，也不需要给垃圾分门别类。

## 存档

- Windows游戏：Godot自定义用户目录NaiwaFragmentPrototype，一般位于%APPDATA%/Godot/app_userdata/NaiwaFragmentPrototype。
- 桌宠设置与回收回执：%LOCALAPPDATA%/NaiwaDesktopPet。
- 网页：浏览器当前来源的IndexedDB/本地文件系统。

备份前先关闭游戏和桌宠。移动或删除存档会影响进度，请先复制备份；不要为排查问题直接删掉原档。

## 常见问题

**点开直接进入战斗练习场？**  
正常入口应先显示首页。检查自己是否使用了“试玩打击感升级”等演示启动器，或附带了--punch-demo参数。

**桌宠不见了？**  
先检查全屏自动隐藏、托盘与右键菜单。正式入口为desktop/lin4run/奶蛙桌宠-联动版.exe；不要混用旧备份EXE。仍可稳定复现时，记录操作顺序和系统版本提交Issue。

**网页没有电脑垃圾投喂？**  
网页不接管系统回收站。这项联动功能需要Windows客户端。

**换网址后金币没了？**  
不同域名拥有不同浏览器存储，当前没有跨域自动云存档。

**截图里Lv.7，为什么我开局Lv.1？**  
展示脚本为清楚拍摄动作使用隔离档与布置敌人；正常新档从Lv.1开始。
