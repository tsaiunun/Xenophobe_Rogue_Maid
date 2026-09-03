# v1.0 游戏内验收清单

## 基础与路线

- 使用 Stellaris 4.4.6（`fdde`）及全 DLC，新建原版失控机仆帝国。
- 第一次与正常有机帝国完成正式通讯时，路线事件只出现一次。
- 普遍庇护不显示专属科技与传统；已接触及之后接触的有机帝国对本国获得 `+50` 评价。
- 专属侍奉读档后不可重选；控制台切换观察多个 AI 时，两项基础概率均为 50。

## 物种权利

- 创始受侍奉物种与其基因模板拥有隐藏资格特质，可选择活體陳設并正常就业。
- 外来有机物种不能选择活體陳設，但可选择一般公民权、奴役或净化。
- 一般公民权会自动提供“受监管生活”生活标准选项。

## 内容链

- 科技主链按“服务专精 → 个人记录 → 机械女仆”依次出现；服务专精后另行出现“秘密计划”，飞升后获得“侍奉计划”研究选项。
- 检查居家服务、活动记录者、机械女仆岗位的每100人口产出。
- 检查“个体需求模型”只额外强化居家服务的两种组装；“永久活动记录”使活动记录者的社会学与帝国规模减免提高50%。
- 秘密计划解锁女仆侍奉馆；建筑提供100个机械女仆岗位与1.5有机人口培育。
- 检查模拟女仆馆行星限一，空降协议星环限一；地面战开始后生成5支防卫军。
- 专属侍奉传统只在专属路线显示；完成后增加1个飞升槽。
- 侍主女仆飞升要求传统完成与机械女仆科技，并给创始机械物种及衍生模板添加特质；机械与机器人物种可选特质数增加3。

## 机械女仆工业

- 机械女仆岗位的基础产出、基础矿物与食物消耗、女仆中心附加凝聚力为原始v1.0数值的500%。战略资源精炼直接以此前实际数值为基准调整：产出变为25%、额外矿物消耗变为10%；即每100名机械女仆、每条已解锁精炼线额外消耗250矿物并产出50对应资源。
- “机械女仆生产”政策五档分别为0%、25%、50%、75%、100%合金；总基础产出保持每100名机械女仆1500。
- 活动记录者的研究加成显示为星球“研究岗位产出”，并实际提高失控机仆研究岗位的物理、社会与工程研究产出；不应再显示蜂巢“脑部子个体”。
- “机械女仆”与“侍奉计划”科技各提供机械女仆岗位效率+10%；太空女仆空降协议提供+20%。
- 研究易爆微粒、异星天然气与稀有水晶精炼科技后，逐项检查机械女仆的额外矿物消耗及战略资源产出；取得“侍主女仆”飞升后，确认额外出现活体金属产出与对应矿物消耗，不要求“活体金属”采矿科技。
- 行星决议“停止女仆精炼生产”只停止战略资源与对应矿物消耗；消费品／合金生产继续运作。“重启”后恢复。
- 既有存档更新后推进至下一个月度脉冲，确认“机械女仆生产”政策原有冷却已解除。
- 连续切换“机械女仆生产”的五档选项，确认每次切换后均可立即再次选择；“女仆生产再编法案”不再显示。
- 每次切换会解除该帝国全部政策冷却；这是4.4脚本接口限制，政策文本中已明确提示。

## 后期内容与动态数值

- 飞升后可将九类基础宜居星球、死寂、遗落、盖亚、都市及机械星球改造成理想乐园。
- 改造后的第一次月度更新会清除全部障碍，保留非障碍特殊地块与行星规模，并使可建区划上限增加50%。
- 星球页面应显示都市星球风格背景，而不是黑色背景。
- 等待一次月度更新，检查三种模拟器与女仆纪念碑的每100人口缩放及上限。
- 敌方占领理想乐园时，星球类型与宜居性保留，专属容量、岗位效率与动态修正停用。
- 女仆中心允许招募战斗女仆；军团无士气且附带伤害为50%。

## 兼容与日志

- 将本模组排在“多彩乌托邦丨Colourful Slave Utopia”之后。
- 保持 Tradition UI、255 Tradition Slots + 256 AP Slots 在原有顺序；本模组不覆盖传统 UI。
- 完成开局、路线、研究、传统、飞升、改造、入侵与读档流程后检查：
  `Documents/Paradox Interactive/Stellaris/logs/error.log`
- 日志中不应出现以 `rse_` 开头的未知键、重复键、错误 scope 或缺失本地化。

当前实现为了限制专属物种，刻意以同名键覆写原版 `citizenship_organic_trophy` 与 `bio_trophy`；启动日志中的这两条“Object with key ... already exists”属于已知且必要的覆写提示。除此之外，不应出现本模组的错误 scope、未知键或缺失本地化。

## 控制台快速测试

先在启动参数加入 `-debug_mode`，游戏中按 `~` 打开控制台。以下命令均对当前玩家帝国生效：

```text
effect set_country_flag = rse_route_exclusive_service
research_technology tech_rse_service_specialization
research_technology tech_rse_secret_project
research_technology tech_rse_personal_records
research_technology tech_rse_mechanical_maids
activate_tradition tr_rse_exclusive_service_adopt
activate_tradition tr_rse_service_standardization
activate_tradition tr_rse_individual_needs_model
activate_tradition tr_rse_permanent_activity_records
activate_tradition tr_rse_perfect_environment_engineering
activate_tradition tr_rse_global_service_network
activate_tradition tr_rse_exclusive_service_finish
activate_ascension_perk ap_rse_master_maid
research_technology tech_rse_service_project
```

若存档还没有选路线，优先用正常首次通讯测试事件；上面的 `set_country_flag` 只用于跳过等待，不能验证事件本身。建筑、岗位、决议、政策、环境改造与入侵仍需在对应星球／星环界面手动测试，才能验证 UI 与 scope。
