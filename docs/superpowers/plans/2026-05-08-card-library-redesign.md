# 卡牌模型重设计：静态卡库 + 智能上下文过滤

> 状态：计划已锁定，**未执行**。等待用户指令开干。
> 上下文：v0.8 玩测后，用户提出"卡=学过的单词库（静态），抽的是问题"的设计反转。

---

## 设计变更

### 旧模型（v0.8）

```
手牌（5 张）= 从牌组抽来的
出过 → 弃牌堆
留下 = 跨回合保留卡
回合开始抽到 5 张
```

**问题**：手牌只够答 1 题就空了；卡组管理增加认知负担；与"我学过这些词"的教育直觉不符。

### 新模型（A 方案）

```
卡库 = 玩家在备战时启用的所有单词卡（10-15 张）
卡 ≠ 资源：永远在场，不消耗，不抽不弃
题 = 资源：每回合从 challenge_pool 抽 3 题
能力触发：每张卡每回合最多触发 1 次能力（如 draw_card / chain_bonus）
```

**核心改变**：
- 手牌池静态化：`_hand` → `_card_library`
- 取消抽/弃牌循环
- 取消 `_retained_card_ids`（卡不消耗，无需保留）
- 保留 AP 队列、提交批量结算、完美连击、严格语义校验、卡片能力
- 题目侧逻辑不变（hand-aware 抽题、留下、降级填充）

---

## 智能上下文 UI

### 默认行为

- 无题选中 → 手牌区显示全部库（紧凑 GridContainer）
- 点选某题 → 手牌区**自动过滤**为"匹配该题 slot 类型"的卡（约 4-8 张）
- 切换选中题 → 手牌区切换
- 「📚 全部库 / 🎯 候选」 按钮在过滤模式下可切回

### 过滤规则

```
filtered = library.filter(card =>
    for any empty_slot in selected_challenge.slots:
        if CardValidator.can_place(card, empty_slot) by TYPE/POS only:
            return true
    return false
)
```

**故意不暴露答案**：
- 过滤只看 `required_type` + `required_pos`（粗匹配）
- 不看 `accept_card_ids` 或 `required_tags`（精匹配）
- 玩家还是要靠语义选对的那张

### 视觉

- 已使用过本回合（能力已触发）的卡 → 标灰 + 角标 "✓ 已用"
- 仍可放入 AP 槽，但能力不再触发
- 提交结算后所有"已用"恢复正常

---

## 工作量估算

| 模块 | 改动 | 估行 |
|------|------|------|
| BattleController：移除 hand/discard，改 _card_library | 重写 setup / draw / 抽/弃 路径 | ~120 |
| BattleController：能力 once-per-turn 限制 | 加 `_used_card_ids_this_turn` set | ~30 |
| BattleScene UI：手牌区改 GridContainer + 过滤逻辑 | _render_hand → _render_library | ~150 |
| BattleScene UI：题选中触发过滤 | _on_challenge_selected → _filter_library | ~50 |
| BattleScene UI：切换按钮（全部 / 候选） | _on_filter_toggle | ~30 |
| Pre-run setup：备战界面"启用单词库" | 文案 + 卡组上限语义改 | ~50 |
| 数据迁移：旧存档兼容（_hand → _card_library） | save_system 迁移 | ~30 |
| 测试更新：~15 个旧测试要改用 _card_library | tests/* | ~200 |
| **总计** | | **~660 行** |

---

## 影响范围

### 必改文件

| 文件 | 改动 |
|------|------|
| `src/battle/battle_controller.gd` | 大改：hand → card_library 状态机 |
| `src/battle/battle_scene.gd` | 大改：_render_hand → _render_library，加过滤逻辑 |
| `src/battle/battle_scene.tscn` | 加"📚 全部库 / 🎯 候选"切换按钮 |
| `src/city/pre_run_setup_controller.gd` | 文案改"启用单词库"；逻辑保留 |
| `src/run/run_state.gd` | `current_deck` 改名 `enabled_library` 或保留兼容 |
| `src/core/systems/save_system.gd` | 旧档迁移：`current_deck` → `enabled_library` |
| 现有测试约 15 个 | 用 `set_card_library_for_test` 替代 `set_hand_for_test` |

### 不改文件

- 全部 voice 后端 / VoiceClient
- 全部 lore JSON / cutscene 系统
- 全部 ContentPack / 数据文件结构
- AP 队列核心（`add_to_ap_queue` / `submit_all_ap` 不动）
- 严格语义校验 / CardValidator
- 卡片能力 / CardAbilities（但触发条件加 once-per-turn 闸门）
- 题目效果 / ChallengeEffects
- 题板降级 / kept-question-aware 抽题
- FeedbackSystem / 调试模式

### 兼容/移除机制

- ❌ 移除"📌 保留卡"功能（无消耗机制 → 无意义）
- ✅ 保留"📌 留下题目"功能（题仍是资源）
- ✅ 完美连击 +1 AP 次回合保留
- ✅ kept-question-aware 抽题保留（确保留下的题下回合有可用候选）

---

## 实施任务列表（待开干）

```
T1. 重命名 + 数据状态：_hand → _card_library; remove _discard, _deck, _retained_card_ids
    - 更新 BattleController 字段
    - 加 setup_with_library(library: Array[Card])
    - 加 get_card_library() getter
    - 加 _used_ability_card_ids_this_turn: Array[String]
    - 删除 draw_to_full_hand / shuffle_deck 等
    - 测试：保留 BattleController 基础测试，改用 _card_library

T2. 卡片能力 once-per-turn
    - CardAbilities.apply_pre_submit 检查 _used_ability_card_ids
    - submit_all_ap 末尾标记每条 connection 的卡为"本回合能力已用"
    - 回合结束（end_player_turn）清空 _used_ability_card_ids
    - 测试：能力第二次触发在同一回合返回 0 modifier

T3. AP 队列回收
    - submit_all_ap 后：所有 ap_queue 中的 card 不进 discard，回到 library 可见列表
    - remove_from_ap_queue 已经回到"hand"，改为"library"，逻辑保留

T4. BattleScene UI 重构 - 静态库渲染
    - _render_hand → _render_library
    - 改用 GridContainer (5 列)
    - 卡的 used_this_turn 视觉态（modulate=0.6 + 角标 "✓"）

T5. 智能上下文过滤
    - 题选中信号 → _on_challenge_selected
    - 调 _filter_library_for_challenge(challenge)
    - 过滤后传给 _render_library 渲染
    - 加 _filter_mode: "all" | "candidate"
    - 加切换按钮 + 信号

T6. 备战界面文案 + 数据
    - tower_gate / pre_run_setup：文案改"启用单词库"
    - permanent_upgrades.deck_slot_max → enabled_library_slot_max（语义同）
    - 保留向后兼容字段（旧 deck_slot_max 也读）

T7. 旧档迁移
    - save_system 加迁移：旧 deck_card_ids → enabled_library_card_ids
    - 加版本号字段防止重复迁移

T8. 测试套件更新
    - set_hand_for_test → set_card_library_for_test
    - 删除 hand-retention 测试（功能取消）
    - 删除 kept-aware draw 测试（卡不消耗 → 无 draw）
    - 保留 kept-aware question 测试（题仍抽）
    - 加新测试：能力 once-per-turn / library 不消耗 / 上下文过滤

T9. 集成 + 玩测准备
    - 全套测试通过
    - 重建 dmg
    - 清存档目录
    - 更新 docs/CREDITS.md（如有）
```

---

## 验收标准

- [ ] 战斗中手牌区显示全部启用单词库（默认状态）
- [ ] 点选题目 → 手牌区过滤为该题候选卡（只按 type/pos 粗过滤）
- [ ] 切换按钮 在 全部 / 候选 间切换
- [ ] 卡片放入 AP 槽 → 卡仍在库中可见（标记本回合"已用能力"为灰）
- [ ] 提交结算 → 卡的能力一回合内只触发 1 次（验证测试）
- [ ] 回合结束 → 卡的"已用"标记清除
- [ ] 题留下 + 题刷新逻辑保留
- [ ] 完美连击 +1 AP 次回合生效
- [ ] 旧存档（v0.8 卡组结构）能加载并迁移
- [ ] 全套 GUT 测试通过 ≥ 430（基线 430 - 删除约 10 旧测试 + 加约 15 新测试）
- [ ] dmg 包体保持在 ~150MB

---

## 已决定但未执行

待用户说"开干"后：
1. 用 subagent-driven-development 模式按 T1-T9 顺序执行
2. 每任务自动 spec compliance 验证
3. 完成后重建 dmg 给用户试玩

---

## 已知不解决的（留给后续）

- 「学过 vs 启用」的差异：当前简化为"启用 = 备战时勾选的，存档里持久"。理论上应该有"已学习的卡（永久仓库）" + "启用的子集（每次进战可调）"两层。当前两层混在 `unlocked_card_ids`，可在后续重构。
- 卡的 mastery_level 衰减：原本"已掌握的卡伤害衰减 ×0.7"机制依然在 DamageCalculator 里。新模型下熟练卡仍可用，但伤害低 → 鼓励玩家用新卡。这条机制保留不动。
- "上限自适应"：备战时启用库 12 张，但玩家当前只学过 8 张？需要加保护：库 = `min(可启用上限, 已学卡数)`。
