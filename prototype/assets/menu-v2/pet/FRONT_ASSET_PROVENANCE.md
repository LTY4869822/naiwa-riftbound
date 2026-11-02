# 菜单正面角色资产

2026-10-28，使用内置 `image_gen`，根据用户本轮提供的正侧背三视图生成；没有使用 CLI/API fallback，没有用 Python 做去背或修改像素。

## 交付

- `front-idle.png`：1024×1536 RGBA，面向镜头的全身中性站姿。
- `front-laugh.png`：1024×1536 RGBA，面向镜头、双手捧腹、开口笑的单张反应姿势。它不是原版桌宠完整动画，不能当成序列帧报告。

参考输入：`C:/Users/Sherlock Holmes/Documents/xwechat_files/wxid_7c9cc4tn7uvf22_e63d/temp/RWTemp/2026-10/9e20f478899dc29eb19741386f9343c8/16834146ef5adfb7dcbe7198d39f5b5d.jpg`。

## 生成提示

第一张：只使用参考中左侧正面角色，锁定双绿眼、细笑嘴、黄肤、奶白大肚、深色指尖和脚趾，以及宽躯干/细腿的比例；正面全身，垂手，透明背景，无文字、其他视角、配饰和底座。

第二张：以上一张正面角色为身份参考，仅把双手移到上腹两侧、肩部稍抬、双眼快乐地微眯、嘴巴张开成适度圆弧笑口；保持正面机位、身体比例、腹部大小、腿和脚的落地位置，透明背景，无牙齿或配饰。

随后分别作一次精准 alpha 修正提示：保持角色所有不透明部分不变，去掉轮廓外的光晕、雾气、发光、地面与阴影，背景必须 alpha=0，角色主体不透明，轮廓仅保留自然抗锯齿。

原始生成文件均保留于：

- Idle 初稿：`C:/Users/Sherlock Holmes/.codex/generated_images/01a180fb-ee46-7331-978e-33bf612bac35/exec-9079c7bc-df93-4b49-a646-0ea6870433ea.png`
- Laugh 初稿：`C:/Users/Sherlock Holmes/.codex/generated_images/01a180fb-ee46-7331-978e-33bf612bac35/exec-a4251cd1-19c3-4b31-8efe-5b42a5b63069.png`
- Idle 最终：`C:/Users/Sherlock Holmes/.codex/generated_images/01a180fb-ee46-7331-978e-33bf612bac35/exec-9e867c47-1015-4e66-9ae2-f371b0cd0583.png`
- Laugh 最终：`C:/Users/Sherlock Holmes/.codex/generated_images/01a180fb-ee46-7331-978e-33bf612bac35/exec-001344ef-73db-4403-89b7-7c7b61cb919a.png`

## 检查与限制

Pillow/Numpy 仅用来读取和统计；两个文件均确有 alpha，角落、头顶外围与腿间背景为 alpha=0，主体约253–254。工具预览可能显示 alpha=0 像素里保留的金色 RGB，因此预览看起来有宽金色光晕；实际有色外围抽样像素如 idle `(250,400)=(186,159,46,0)`，在遵守 alpha 的渲染器中完全不可见。alpha 边缘约2–8像素（画布宽1024），应以 Godot 深色底实机合成为准。

两张是根据参考生成的重绘资产，不是逐像素原图抠图；眼睛大小、表面细节和姿势会有细微差异。角色轮廓和正面朝向已人工查看。正式制作若需精确模型与无漂移动画，仍应使用经过确认的模型或逐帧资产。
