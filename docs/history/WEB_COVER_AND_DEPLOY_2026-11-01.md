> 历史设计/交付记录，当前玩法以仓库首页和权威配置为准；历史生成日志和截图不全部纳入Git。

# 网页封面与国内部署

本轮范围是网页启动封面与可迁移部署包，原 Godot 游戏、Windows 桌宠和正式档案没有改动。

## 设计依据

用户不喜欢深色背景上单张米色卡片，希望更像正式游戏。沿用游戏实际的正面奶蛙、四境场景、奶蛙/碎片巡游名称与现有喷墨菜单语言。封面以真实场景和角色为主，左侧标题与唯一主操作，底部四境预览；预览不修改 Godot 关卡。进入游戏仍从正常首页开始。

墨绿 #0d201b 承载结构，暖白 #fffde9 用于标题，黄绿 #d6fa68 用于开始与焦点，紫色 #ac79f7 用于品牌贴纸。场景预览有文字和 aria-pressed；不是单靠颜色表达。中文标题使用随包 Noto Sans SC 900 WOFF2，不请求海外字体 CDN。全部封面图片从本项目美术缩放与编码，来源记录在 cover/manifest.json。

鼠标、Tab/Enter、触屏复用真实按钮；指南是原生 dialog，Esc关闭并返回触发按钮。奶蛙点击有短回弹/招呼，不冒充完整笑动画。呼吸幅度小于8px；系统减少动态时关闭循环、位移和转场。加载进度来自真实校验成功的压缩资源字节，失败最多重试3次，彻底失败显示重新加载，避免引擎 Promise 挂起时只留静止进度。

## 推荐路线

用户目前没有云账号和域名。推荐先注册腾讯云，再用 EdgeOne Pages/Makers 静态托管配自有域名。无需先租一台服务器。本游戏是约50MiB的纯静态站点。

- 长期面向大陆玩家：大陆/含大陆加速区域 + 已备案自定义域名 + HTTPS。
- 暂时不备案：不含大陆加速区域 + 自定义域名，仍需实际测试玩家所在地网络；不能承诺所有地区免VPN、低延迟。
- EdgeOne默认项目域名在大陆网络存在3小时预览链接限制，不能作为长期分享地址。
- CloudBase默认域名有测试用途、中间提示页与限频，因此不将它当作正式成品。

官方文档核对于2026-11-01：

- https://pages.edgeone.ai/document/domain-overview
- https://pages.edgeone.ai/document/custom-domain
- https://pages.edgeone.ai/document/direct-upload
- https://docs.cloudbase.net/service/alias

## 上传

运行 python tools/package_web_portable.py，生成 production/naiwa-web-upload.zip。压缩包根目录就是 index.html，只有运行需要的公开文件，不含 Git、Sites身份、源码、日志、凭证、用户存档或Windows桌宠。

在 EdgeOne 控制台创建静态项目，选择直接上传，上传此ZIP，无需构建命令。按所选区域绑定自有域名，配置DNS并开启HTTPS。大陆区域需要先完成域名备案。当前未接入用户云账号/域名，不能声称国内链接已开通。

## 服务器备选

已有服务器时，将ZIP解压到独立目录，例如 /srv/naiwa，使用 deployment/nginx-naiwa.conf 的 location 配置放在现有 HTTPS server 中。不要覆盖整台服务器的 nginx.conf。压缩分块 .gz 是游戏数据容器，必须原样传输，不要给它们设置 Content-Encoding:gzip，也不要开启自动解压重写。实际Wasm由客户端还原正确MIME类型。首页和加载器需要重新验证缓存，内容寻址的游戏块可缓存一年。

更换站点域名会产生新的浏览器存储空间；旧域名存档不会自动迁移。未实现云存档或旧域名导入，所以不承诺换链接后等级和金币自动同步。
