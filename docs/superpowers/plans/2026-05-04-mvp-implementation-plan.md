# MVP 实施计划 — 知识神塔

> 状态：v1（执行中）
> 范围：Phase 1 MVP — 0F 字母拼读 + 1F 形容词 + 2F 名词代词，含完整战斗/Run/知识城/Cutscene/Spice。

## 依赖关系

```
Phase 1 — 基础（并行）
  ├─ Cleanup 旧代码
  ├─ Card 数据模型（新资源类）
  ├─ Cutscene 引擎（含 LoreCodexSystem）
  ├─ ContentPackBase 接口扩展
  └─ SaveSystem per-pack 隔离

Phase 2 — 核心系统（依赖 Phase 1）
  ├─ Battle 卡片对话战重写
  ├─ Run 三幕地图 + 节点
  ├─ KnowledgeCity 6 建筑
  └─ Spice 系统 + 2 实现

Phase 3 — 内容数据（依赖 Phase 1+2）
  ├─ English Pack 数据文件（cards/challenges/enemies/bosses/floors）
  ├─ 0F/1F/2F 完整内容
  └─ Lore JSON（intro + 楼层 + Boss + 通关 + NPC）

Phase 4 — 集成
  ├─ Main Menu 重建
  ├─ Pre-Run Setup（备战界面）
  ├─ Crystal Market + Blueprint Workshop
  ├─ Codex
  ├─ 反舒适区机制接入
  └─ 占位资源（音/图）

Phase 5 — 打磨
  ├─ 集成测试 / 修 Bug
  ├─ UI 微调
  └─ 真实资源生成（AI 图、TTS 音频）
```

## Spec 索引

- 战斗：`docs/superpowers/specs/2026-05-04-battle-system-redesign.md`
- Run：`docs/superpowers/specs/2026-05-04-run-structure-design.md`
- 知识城：`docs/superpowers/specs/2026-05-04-knowledge-city-design.md`
- 内容包接口：`docs/superpowers/specs/2026-05-04-content-pack-interface-design.md`
- Cutscene：`docs/superpowers/specs/2026-05-04-cutscene-system-design.md`
- 英语剧情：`docs/superpowers/specs/2026-05-04-english-pack-narrative.md`
- 英语 MVP 内容：`docs/superpowers/specs/2026-05-04-english-pack-mvp-content.md`

## 任务列表

### Phase 1（可并行）

- [ ] **Task 1.1** Cleanup：删除废弃的 exploration / expedition_setup / expedition_tracker / gate_wave_scene / question_controller 等
- [ ] **Task 1.2** Card 数据模型：`Card / ChallengeTemplate / ChallengeSlot` 资源类 + JSON 加载器
- [ ] **Task 1.3** Cutscene 引擎：`CutscenePanel / CutscenePlayer / CutsceneScene / LoreCodexSystem` autoload
- [ ] **Task 1.4** ContentPackBase 25 方法接口扩展 + ContentLoader 自动扫描 + validate()
- [ ] **Task 1.5** SaveSystem 按学科隔离 + 旧档迁移

### Phase 2

- [ ] **Task 2.1** BattleController 重写为卡片对话战 + DamageCalculator + Mastery + SRS 注入
- [ ] **Task 2.2** Battle UI 重写：手牌区、Challenge 板、敌人立绘、连击、HP/MP
- [ ] **Task 2.3** Run 三幕地图生成器 + RunMapScene UI
- [ ] **Task 2.4** Run 节点解析器（battle / elite / shop / rest / mystery / boss）
- [ ] **Task 2.5** Camp 中场营地（卡 3 选 1 + 营地行动）
- [ ] **Task 2.6** Run 撤退 / 通关结算
- [ ] **Task 2.7** KnowledgeCity 静态布局 + 6 建筑入口
- [ ] **Task 2.8** Spice 系统 + VoiceScrollSpice + DictationSpice

### Phase 3

- [ ] **Task 3.1** English Pack 数据文件结构 + cards.json
- [ ] **Task 3.2** 0F 完整内容（50 卡 + 10 Challenge + 2 敌 + 3 Boss）
- [ ] **Task 3.3** 1F 完整内容（25 卡 + 12 Challenge + 3 敌 + 3 Boss）
- [ ] **Task 3.4** 2F 完整内容（35 卡 + 12 Challenge + 3 敌 + 3 Boss）
- [ ] **Task 3.5** Lore JSON：intro + 3 floor_intros + 9 boss × (pre+post) + 3 floor_completes + NPC

### Phase 4

- [ ] **Task 4.1** Main Menu 重建（标题 / BG / BGM 来自 pack）
- [ ] **Task 4.2** Pre-Run Setup（备战）界面：编辑卡组 + 卡组分析 + 复习
- [ ] **Task 4.3** Crystal Market（词晶集市）UI
- [ ] **Task 4.4** Blueprint Workshop（蓝图工坊）UI
- [ ] **Task 4.5** Codex 图鉴馆（卡 + 敌人 + 剧情碎片）
- [ ] **Task 4.6** Training Ground（训练场）SRS 弱点练习
- [ ] **Task 4.7** Guardian's Quarters（守护者驻地）
- [ ] **Task 4.8** 反舒适区机制接入（熟练度衰减 + 新卡奖励 + Boss 覆盖）

### Phase 5

- [ ] **Task 5.1** 占位美术 + Kenney 资源整合
- [ ] **Task 5.2** TTS 音频生成（卡片发音）
- [ ] **Task 5.3** BGM/SFX 占位
- [ ] **Task 5.4** 集成测试：完整链路通关
- [ ] **Task 5.5** 修 Bug + 微调
