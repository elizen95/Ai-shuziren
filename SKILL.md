---
name: minimax-h3-avatar
description: 在 Windows 上恢复 MiniMax H3 环境，或用定稿图生成固定比例的中文数字人。适用于原声驱动的分段绿幕素材、15 秒测试片和重装恢复。
---

# MiniMax H3 数字人

用户指定角色图时，把该图作为唯一人像参考和首尾帧。沿用图中的人物比例、五官、眼镜、发型与衣着。未指定时才用随包定稿，默认半身。全程单人、固定机位与焦距，禁止渐变放大和镜头推拉。保留自然眨眼、克制表情、较小口型和低位小手势。测试视频用于参考构图与节奏。

角色画面和口型仅由 MiniMax H3 生成，禁止引入其他口型或换脸模型。沿用 SageAttention 2、FL2VA Pruned Rank 8 INT8、Q2_K 文本编码器、INT8 视频 VAE 和 Lightx2v 四步配置。H3 按原生帧率生成，FFmpeg 导出 1024×576、恒定 30 fps。已有 H3 素材保留，新任务单独落盘。

## 分段制片

1. 从执行单、交接 JSON、对应原声 WAV 提取段号、可见帧数、主片起始帧和原声音频偏移。用户本轮要求优先。交接资料提供素材和时码。
2. 复制 `assets/fixed-shot.json` 为 WanGP 任务，设置 `image_prompt_type: "SE"`，首尾指向同一张用户定稿图。有原声时设置 `audio_prompt_type: "A"`、`audio_guide` 指向对应 WAV。提示词要求人物自然同步说话，避免加入逐字台词标签，以免 H3 另生人声。帧数覆盖原声和把手，按已验证的 24 fps、`5 + 17 × k` 帧网格向上取整。使用 `wgp.py --process` 运行单项或 JSON 队列。
3. 用交接时码去掉把手，按主片可见帧数导出。绿底不均匀时可做色键和纯绿合成。每个段号目录默认只交付一份 `avatar-green.mp4`，背景为纯绿 `#00FF00`、画面为 30 fps、文件静音。透明版、预览和技术清单按用户明确要求再交付。生成中间件和日志保存在工作目录。
4. 逐段解码验证分辨率、帧率、准确帧数和静音状态，抽查人物比例、口型、手部和绿幕边缘。原声继续在主片播放，绿幕文件第 0 帧对齐主片起始帧。汇报实际检查范围。

## 重装后恢复

1. 重装前把 Skill 压缩包和「MiniMax-H3模型」备份复制到非系统盘或外接盘。重装后将本 Skill 文件夹放入 Codex 的个人 Skills 目录，将独立的「MiniMax-H3模型」备份放在可访问的磁盘。准备 Windows x64、PowerShell 7、Git 和可用的 NVIDIA 驱动。脚本从网络安装锁定版本的软件和依赖，模型从备份读取。测试硬件为 RTX 4060 Ti 8 GB。
2. 在 Skill 根目录运行。按需修改安装路径和模型备份路径。网络需要显式代理时，设置本次会话的 HTTPS_PROXY 和 HTTP_PROXY。
   
   ~~~powershell
   pwsh -NoProfile -File ./scripts/Restore-H3.ps1 -Root D:/Tset -ModelBackup 'E:/备份文件/MiniMax-H3模型'
   ~~~

   只检查模型备份时在同一命令末尾加 -VerifyOnly。脚本锁定 WanGP 提交和依赖，校验模型文件的 SHA-256，并验证 CUDA 和 SageAttention。
3. 运行下面的生成命令。重装后的首次核验可先追加 -DryRun，再运行正式测试。

## 生成 15 秒测试片

~~~powershell
pwsh -NoProfile -File ./scripts/Run-H3.ps1 -Root D:/Tset -Shot half
~~~

用 -Shot full 选择全身，用 -Dialogue '要说的中文台词' 替换默认台词。半身为实测通过的配置。全身使用原包的全身定稿首尾图，生成后检查全身构图和手脚完整性。结果和运行日志写入安装目录的 results，逐秒抽看人物比例、背景与手势，核对时长、分辨率和声轨。若出现渐变放大或人物漂移，先调整首尾参考与提示，再重试。

assets 中的 half-original.png 和 full-original.png 是原始定稿透明图。两个 1024×576 PNG 用于首尾条件。model-manifest.json 清单记录独立备份所需的文件名、版本校验和来源。

