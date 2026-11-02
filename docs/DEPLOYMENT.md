# 网页部署与分发

## 成品目录

web/dist是完全静态的构建结果，包含HTML、CSS、JavaScript、字体、美术、引擎脚本和十个压缩游戏块。部署时根目录必须包含index.html。没有服务端API、数据库或付费登录系统。

原始wasm与pck文件由浏览器根据game-manifest.json重建，源站不存在naiwa.wasm/naiwa.pck裸文件是正常情况；不应把它们404判断为打包丢失。

## GitHub Pages

.github/workflows/pages.yml校验后上传web/dist。Pages source应设为GitHub Actions。源码推送触发检查；网页通过Actions中的Deploy browser game手动发布。首次仓库创建与Pages开启完成后，地址为：

https://lty4869822.github.io/naiwa-riftbound/

Pages部署状态以Actions成功结果为准，不以README中出现链接为成功依据。所有图片、脚本和加载器使用相对路径，支持项目子目录。

## 腾讯云/其他静态托管

Release中的naiwa-riftbound-web-v0.1.0-preview.1.zip根目录已经是index.html，可以直接上传到支持静态站点的平台。无需npm install或框架构建。每个文件小于25MiB。

面向国内长期访问，推荐腾讯云EdgeOne配自有域名：

- 大陆或含大陆加速区要求已备案域名。
- 不含大陆加速区无需按该区域要求备案，但仍需实测各地连接。
- 默认项目域名在大陆网络有3小时预览链接限制，不适合长期作为正式分享地址。
- 当前没有接入维护者的腾讯云账号/域名，不能把GitHub Pages发布称为完成国内线路迁移。

官方说明：

- https://pages.edgeone.ai/document/domain-overview
- https://pages.edgeone.ai/document/direct-upload
- https://pages.edgeone.ai/document/custom-domain

GitHub本身及原chatgpt.site试玩地址都不保证国内各网络稳定直连。

## 自有服务器

把web/dist内容放在独立站点根目录，配置HTTPS。deployment/nginx-naiwa.conf提供location示例，合入现有HTTPS server，不要覆盖整机nginx.conf。

assets下的.gz是游戏数据容器。请原样传输，不添加Content-Encoding:gzip，不让代理自动解压后改写内容。加载器会检查压缩长度与哈希，并自行解压。HTML和加载器宜使用no-cache；带内容摘要的游戏块可长期缓存。

使用HTTPS是必要条件，除了localhost开发例外。加载器的浏览器加密校验等能力需要安全上下文。

## 缓存与存档

首次总下载约50MiB，后续速度取决于浏览器及CDN缓存。新版页面使用版本查询参数，游戏块使用内容摘要文件名。更换游戏数据后应同时更新manifest，不要只覆盖某个旧文件名。

更换域名会创建新的浏览器存储空间。当前没有云存档、跨域同步或浏览器与Windows共享档案。迁移时应提前告知玩家，不宣称旧等级会自动跟过去。
