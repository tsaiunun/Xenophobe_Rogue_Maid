# Rogue Servitor Enhanced / 失控机仆强化

版本：1.0  
目标游戏版本：Stellaris 4.4.x（以 4.4.6 `fdde` 开发）

## v1.0 内容

- 首次正式接触有机帝国后的永久路线选择。
- 专属侍奉物种权利、创始有机物种资格继承与活體陳設扩展。
- 五项社会学科技：服务专精、秘密计划、个人记录、机械女仆与飞升后的侍奉计划。
- 居家服务、活动记录者和机械女仆岗位。
- 女仆侍奉馆、模拟女仆馆、星环空降协议、女仆中心与女仆纪念碑。
- 独立的专属侍奉传统树与侍主女仆飞升。
- 创始有机物种资格特质、侍主女仆特质及三项可选模拟器机械特质。
- 可随时调整的机械女仆生产政策（0%至100%合金）与战略资源精炼开关；侍主女仆飞升解锁活体金属精炼，生产再编法案暂时隐藏。
- 理想乐园环境改造：清除障碍、保留特殊地块并增加50%可建区划，以及战斗女仆陆军。
- AI 路线、研究、传统、飞升、建造与征募权重。

所有岗位及动态缩放的基础数值集中在 `common/scripted_variables/rse_variables.txt`，方便后续调整。

## 兼容性

模组不使用 `replace_path`，也不修改传统 UI。为了实现专属物种限制，v1.0 会以相同键值最小覆写原版 `bio_trophy` 岗位与 `citizenship_organic_trophy` 公民权；修改这两个定义的模组可能发生冲突。

对所附启用清单的本机 Workshop 文件检查显示，“多彩乌托邦丨Colourful Slave Utopia”也定义了 `citizenship_organic_trophy`。请将本模组放在它之后，确保专属物种限制最后生效。Tradition UI 与 255/256 槽位模组可以保持原顺序，因为本模组不覆盖任何传统 UI 文件。不要同时启用其他完整重制失控机仆的模组。

## 安装

将 `rogue_servitor_enhanced` 文件夹复制到：

`Documents/Paradox Interactive/Stellaris/mod/rogue_servitor_enhanced`

将 `launcher/rogue_servitor_enhanced.mod` 复制到 `Documents/Paradox Interactive/Stellaris/mod/`，再由 Paradox Launcher 启用。

## 验证

在 PowerShell 中运行：

`powershell -ExecutionPolicy Bypass -File .\tools\validate_mod.ps1`

游戏内测试步骤见 `docs/TEST_CHECKLIST.md`。本项目不会自动执行 GitHub push。

工作区与游戏目录是两个独立副本；修改工作区不会自动覆盖当前游戏正在使用的版本。
