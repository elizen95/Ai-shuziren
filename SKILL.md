---
name: minimax-h3-avatar
description: 恢复 Windows 上已验证的 MiniMax H3 数字人环境，或使用定稿半身与全身原图生成固定比例的中文数字人视频。适用于重装恢复、生成测试片和复用已有 H3 动作素材。
---

# MiniMax H3 数字人

使用同一个定稿角色。默认半身，用户要求时切换全身。保留五官、圆框眼镜、发型、服装、体型和画面中的人物比例。全程单人、固定机位、固定焦距和头顶留白。允许眨眼、轻微表情和胸前的小手势。沿用同一张定稿画面锁定首尾，保持人物大小和构图。

默认导出 15 秒、1024×576、30 fps 的连续镜头。H3 按原生帧率生成，导出阶段由 FFmpeg 转为恒定 30 fps。MiniMax H3 同步生成画面、普通话和口型，沿用 SageAttention 2、FL2VA Pruned Rank 8 INT8、Q2_K 文本编码器、INT8 视频 VAE 和已验证的 Lightx2v 四步配置。已有 H3 动作素材留在原目录，新任务单独落盘。

## 重装后恢复

1. 重装前把 Skill 压缩包和「MiniMax-H3模型」备份复制到非系统盘或外接盘。重装后将本 Skill 文件夹放入 Codex 的个人 Skills 目录，将独立的「MiniMax-H3模型」备份放在可访问的磁盘。准备 Windows x64、PowerShell 7、Git 和可用的 NVIDIA 驱动。脚本从网络安装锁定版本的软件和依赖，模型从备份读取。测试硬件为 RTX 4060 Ti 8 GB。
2. 在 Skill 根目录运行。按需修改安装路径和模型备份路径。网络需要显式代理时，设置本次会话的 HTTPS_PROXY 和 HTTP_PROXY。
   
   ~~~powershell
   pwsh -NoProfile -File ./scripts/Restore-H3.ps1 -Root D:/Tset -ModelBackup 'E:/备份文件/MiniMax-H3模型'
   ~~~

   只检查模型备份时在同一命令末尾加 -VerifyOnly。脚本锁定 WanGP 提交和依赖，校验模型文件的 SHA-256，并验证 CUDA 和 SageAttention。
3. 运行下面的生成命令。重装后的首次核验可先追加 -DryRun，再运行正式测试。

## 生成

~~~powershell
pwsh -NoProfile -File ./scripts/Run-H3.ps1 -Root D:/Tset -Shot half
~~~

用 -Shot full 选择全身，用 -Dialogue '要说的中文台词' 替换默认台词。半身为实测通过的配置。全身使用原包的全身定稿首尾图，生成后检查全身构图和手脚完整性。结果和运行日志写入安装目录的 results，逐秒抽看人物比例、背景与手势，核对时长、分辨率和声轨。若出现渐变放大或人物漂移，先调整首尾参考与提示，再重试。

assets 中的 half-original.png 和 full-original.png 是原始定稿透明图。两个 1024×576 PNG 用于首尾条件。model-manifest.json 清单记录独立备份所需的文件名、版本校验和来源。

