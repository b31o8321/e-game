# 知识神塔 — 资源致谢 / Credits

本游戏全部美术与音频资源采用免费可商用许可。本文档罗列每项资源
的来源与许可，以便最终发布时引用。

> 命名约定：每个章节按 **类别 → 子目录** 组织，每条记录格式为
> `路径: 标题 / 作者（许可）— 来源 URL`。
>
> 自制（程序合成）资源同样列出，并标记 CC0（Public Domain）。

---

## 音频资产 / Audio Assets

所有音频均为本项目代码生成（`scripts/audio_gen/gen_bgm.py` 和
`scripts/audio_gen/gen_sfx.py`，使用 Python + numpy 程序化合成；
不含任何第三方采样）。因此全部以 **CC0 / Public Domain** 发布，
可免费用于商业用途，无需署名。

生成方法可重现：

```bash
# 生成 WAV 至 /tmp/{bgm,sfx}_wav，再用 ffmpeg 转 OGG 至 assets/audio/{bgm,sfx}/
BGM_OUT=/tmp/bgm_wav python3 scripts/audio_gen/gen_bgm.py
SFX_OUT=/tmp/sfx_wav python3 scripts/audio_gen/gen_sfx.py
for f in /tmp/bgm_wav/*.wav /tmp/sfx_wav/*.wav; do
  out=assets/audio/$(basename $(dirname $f) _wav)/$(basename "$f" .wav).ogg
  ffmpeg -y -i "$f" -ac 2 -c:a vorbis -strict -2 -b:a 96k "$out" -loglevel error
done
```

风格目标：anime / JRPG 二次元温暖向，调性以 C 大调（探索 / 知识城）、
A 小调（标准战斗）、D 小调（Boss）为主，曲式采用 Pachelbel I-V-vi-IV
进行变体。所有乐器均为加法 / FM 合成，无版权风险。

### BGM（`assets/audio/bgm/`）

| 文件 | 用途 | 时长 | 风格说明 | 许可 |
|------|------|------|----------|------|
| `main_menu.ogg` | 主菜单 | 70 s | 梦幻钢琴 + 弦乐 pad，hopeful，希望感 | CC0 (project-generated) |
| `city.ogg` | 知识城 | 80 s | 暖色 RPG 小镇，pluck arpeggio + soft piano | CC0 (project-generated) |
| `battle.ogg` | 标准战斗 | 75 s | 中速 124 BPM A 小调，鼓 + 锯齿 bass，鼓励向 | CC0 (project-generated) |
| `boss.ogg` | Boss 战斗 | 75 s | 138 BPM D 小调，drama hit，anime JRPG boss vibe | CC0 (project-generated) |
| `victory.ogg` | 胜利 fanfare | 6 s | C-E-G-C 上升音阶 + 钟声 | CC0 (project-generated) |
| `retreat.ogg` | 撤退 / 失败 | 8 s | A 小调下行钢琴 motif，温柔忧伤 | CC0 (project-generated) |

### SFX（`assets/audio/sfx/`）

| 文件 | 触发 | 时长 | 描述 | 许可 |
|------|------|------|------|------|
| `card_pickup.ogg` | 选中手牌 | 80 ms | 木质轻 tap | CC0 |
| `card_drop_success.ogg` | 卡片正确放入 | 400 ms | 厚 thump + 大三度 chime | CC0 |
| `card_drop_fail.ogg` | 卡片放错 | 240 ms | 小二度下行柔和音（不惩罚向） | CC0 |
| `damage_hit.ogg` | 玩家命中敌人 | 180 ms | Punchy kick-style 冲击 | CC0 |
| `heal.ogg` | 回血 | 660 ms | A-C#-E-A 大三和弦上升钟声 | CC0 |
| `shield.ogg` | 护盾生效 | 550 ms | 上升 whoosh + 高频 shimmer | CC0 |
| `combo_3.ogg` | 连击 ≥3 | 350 ms | 200→1200 Hz 上升 whoosh | CC0 |
| `combo_perfect.ogg` | 连击 ≥5 / Perfect | 800 ms | 五音阶钟声 cascade | CC0 |
| `enemy_defeated.ogg` | 敌人击败 | 500 ms | C-E-G 大三和弦 + sparkle | CC0 |
| `victory.ogg` | 胜利 | 920 ms | C-E-G-C 上升 fanfare（短版） | CC0 |
| `button_click.ogg` | UI 点击 | 50 ms | 1100 Hz tick + click | CC0 |
| `button_hover.ogg` | UI 悬停 | 60 ms | 2000 Hz 弱 tick | CC0 |
| `submit_swoosh.ogg` | AP 提交开始 | 420 ms | 上升 whoosh + 高频 chime tail | CC0 |

---

## 字体 / Fonts

| 文件 | 字体 | 许可 | 来源 |
|------|------|------|------|
| `assets/fonts/NotoSansSC-Regular.otf` | Noto Sans SC | SIL Open Font License 1.1 | https://fonts.google.com/noto/specimen/Noto+Sans+SC |

---

## 美术资产 / Visual Assets

> 由独立的视觉资产工作流维护。占位符与已添加资源会被记录在本节。

<!-- VISUAL_ASSETS_BEGIN -->

### 来源与许可总览

当前批次（2026-05-07）所有视觉资产均由本项目使用 Python + PIL（Pillow 11）
程序化生成，作者 **知识神塔 项目组（自有原创）**，许可
**CC0 / Public Domain** — 可随项目用于商用、二次创作、再发布，无需署名。

风格目标：二次元 / anime — 柔和粉彩渐变、轮廓塔形、星点 / 云朵 / 爱心粒子；
角色为 椭圆面 + 标志性发型剪影 + 大眼 + 光斑高光。
**这是"风格暗示足够"的占位资产**；后续若引入真画师作品，请直接覆盖对应路径
并在本节追加作者 + 许可信息（CC-BY 必须保留署名）。

生成脚本：`scripts/generate_visual_assets.py`
重生成命令：`python3 scripts/generate_visual_assets.py`

### 背景图（`assets/visual/backgrounds/`，1280×720 PNG）

| 文件 | 用途 | 风格描述 | 许可 |
|------|------|----------|------|
| `main_menu.png` | 主菜单 | 夕阳云海中的魔法塔，紫粉渐变 | CC0 |
| `city.png` | 知识城广场 | 暖色暮光 + 远景塔剪影 | CC0 |
| `floor_0F.png` | 0F 字母厅 | 琥珀色，飘浮字母粒子 | CC0 |
| `floor_1F.png` | 1F 图书馆 | 紫色星空 + 漂浮书本 | CC0 |
| `floor_2F.png` | 2F 家庭厅 | 粉色暖意 + 飘浮爱心 | CC0 |
| `boss_battle.png` | Boss 战 | 深红紫，戏剧性 vignette | CC0 |
| `settlement.png` | 战斗 / 楼层结算 | 浅青金粒子，空灵 | CC0 |

### 角色立绘（`assets/visual/portraits/`，256×384 PNG）

| 文件 | 角色 | 设计要点 | 许可 |
|------|------|----------|------|
| `player.png` | 守护者（玩家） | 蓝紫披风、刘海、明亮眼神，腮红 | CC0 |
| `mentor_word.png` | 词语之师（导师） | 长发、眼镜、暖金长袍 | CC0 |
| `elder.png` | 长老 | 银白长发、紫袍 | CC0 |
| `boss_letter_chaos.png` | 字母混乱者（0F-A） | 蓬乱橙发、ghost 半透明 | CC0 |
| `boss_phonics_spirit.png` | 发音之灵（0F-B） | 长冷蓝发、ghost 半透明 | CC0 |
| `boss_letter_warden.png` | 字母守关者（0F-Final） | 棕短发 + 眼镜、土黄铠甲 | CC0 |
| `boss_fog_whisperer.png` | 迷雾低吟者（1F-A） | 雾气发型、灰青色、ghost | CC0 |
| `boss_silent_sigher.png` | 静默叹息者（1F-B） | 深紫长发、忧伤、ghost | CC0 |
| `boss_librarian.png` | 图书管理员（1F-Final） | 紫长发 + 眼镜，知性 | CC0 |
| `boss_family_scatter.png` | 家族散乱者（2F-A） | 蓬乱粉发、ghost 半透明 | CC0 |
| `boss_body_lost.png` | 形体迷失者（2F-B） | 雾气浅褐发、ghost | CC0 |
| `boss_family_guardian.png` | 家庭守护者（2F-Final） | 黑长发、深红铠甲 | CC0 |
| `letter_wisp.png` | 字母游魂 | 普通敌人 ghost 棕系 | CC0 |
| `phonics_phantom.png` | 音节幻影 | 普通敌人 ghost 蓝系 | CC0 |
| `library_dust.png` | 书页尘灵 | 普通敌人 ghost 紫系 | CC0 |
| `wandering_word.png` | 游荡词魂 | 普通敌人 messy 蓝灰 | CC0 |
| `bookworm.png` | 书虫 | 棕发 + 眼镜 | CC0 |
| `home_haunter.png` | 家屋萦绕者 | 普通敌人 ghost 粉系 | CC0 |
| `body_blur.png` | 形影模糊 | 普通敌人 ghost 米黄 | CC0 |
| `pronoun_pest.png` | 代词捣蛋鬼 | 紫粉 messy | CC0 |

### UI 元素（`assets/visual/ui/`，PNG）

| 文件 | 用途 | 许可 |
|------|------|------|
| `card_frame_common.png` | 普通卡边框（200×280） | CC0 |
| `card_frame_rare.png`   | 稀有卡边框（蓝紫） | CC0 |
| `card_frame_legendary.png` | 传说卡边框（金） | CC0 |
| `button_normal.png` | 默认按钮底（240×64 圆角） | CC0 |
| `button_accent.png` | 强调按钮底（暖色） | CC0 |
| `hp_fill_player.png` | 玩家血条填充（绿） | CC0 |
| `hp_fill_enemy.png`  | 敌人血条填充（红） | CC0 |

### 粒子（`assets/visual/particles/`，64×64 PNG）

| 文件 | 用途 | 许可 |
|------|------|------|
| `sparkle.png` | 通用闪光（暖白） | CC0 |
| `sparkle_blue.png` | 冷蓝闪光（魔法系） | CC0 |
| `sparkle_pink.png` | 粉色闪光（治疗 / 喜悦） | CC0 |

<!-- VISUAL_ASSETS_END -->

---

## 备注 / Notes

- 任何后续替换为外部素材时（如来自 Pixabay / OpenGameArt / Freesound），
  请在对应表格行追加新条目，并保留旧的 CC0 自制版作为备份兜底。
- 若使用 CC-BY 许可的素材，**必须** 在 README 与 in-game About 页面同时
  保留作者署名。
- 推荐外部音频源（如需替换）：
  - Pixabay Music — https://pixabay.com/music/  （royalty-free，无署名）
  - OpenGameArt.org — https://opengameart.org/  （CC0 / CC-BY）
  - Freesound.org — https://freesound.org/      （CC0 / CC-BY）
