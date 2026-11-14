# 布一分镜-资产提示词流水线 · Shot & Asset Prompt Pipeline

把一段故事文本，编译成两包可以直接丢给视频 / 图像大模型的提示词：**逐段 10 秒的分镜提示词包** 和 **资产提示词包**。

它回答一个问题：系列短片做到第 10 集，角色怎么还是第 1 集那个角色。

## 为什么需要它



* 文生视频最大的漂移来源不是剧情，是外观描述每次写得不一样。

* 手工写 "不能有鼻子、不能有头发、嘴型不能变" 这类约束，写三段就懒得抄了。

* 场景图里混进人、道具画成两件、某段漏了道具 —— 这些错误不会自己消失。

本流水线把它们做成**逐字复用的锁 + 可核对的编号表**，让每一段出门时都带着同一份约束。

## 目录



```
buyi-shot-asset-pipeline/
├── SKILL.md                      # 主规范：四步流水线 + 三条自检
├── references/
│   ├── seedance-package.md       # 分镜包格式：单段结构、四段锁模板、台词密度
│   └── asset-package.md          # 资产包格式：CH/SC/PR 编号、比例、清洁尾缀
├── check-leaks.ps1               # 公开版自检：核对是否混入需剥离的内容
├── CHANGES.md                    # 与内部版本相比做了哪些中性化处理
├── LICENSE
└── README.md
```

## 安装

不需要 `pip`、`npm`，就是让一个文件夹落进对的目录。下面三条路任选一条。

### 最省事：交给 AI 装

前提是那个 AI 能读写你电脑上的文件——桌面端 / Agent 模式可以，**网页版聊天不行**（它碰不到你的硬盘，只能给你讲步骤）。

1. 下载 ZIP 并解压。
2. 把解压出来的**文件夹路径**（或文件夹本身）交给它。
3. 照这句说，别只说"帮我安装"，它不知道你要装到哪：

> 把 `D:\Downloads\buyi-shot-asset-pipeline-main` 装成技能：重命名为 `buyi-shot-asset-pipeline`，放进技能目录，并确认 `SKILL.md` 与 `references/` 在同一层。

装完新开一个会话——多数工具的技能列表是启动时扫描的，老会话里刷不出来。

### 一条命令（Windows）

打开 PowerShell，粘这一条回车：



```
$d="$env:USERPROFILE\.claude\skills\buyi-shot-asset-pipeline"; New-Item -ItemType Directory -Force $d|Out-Null; iwr "https://github.com/buyi1288/buyi-shot-asset-pipeline/archive/refs/heads/main.zip" -OutFile "$env:TEMP\spp.zip"; Expand-Archive "$env:TEMP\spp.zip" "$env:TEMP\spp" -Force; Copy-Item "$env:TEMP\spp\buyi-shot-asset-pipeline-main\*" $d -Recurse -Force; "装好了：$d"
```

默认装到 Claude Code 的个人技能目录。用豆包或别的工具，把 `$d=` 后面那个路径换成你的技能目录即可。

### 一条命令（macOS / Linux）



```
mkdir -p ~/.claude/skills/buyi-shot-asset-pipeline && curl -L https://github.com/buyi1288/buyi-shot-asset-pipeline/archive/refs/heads/main.zip -o /tmp/spp.zip && unzip -oq /tmp/spp.zip -d /tmp/spp && cp -r /tmp/spp/buyi-shot-asset-pipeline-main/* ~/.claude/skills/buyi-shot-asset-pipeline/
```

### 不想碰命令行：三步



1. 仓库页 `Code → Download ZIP`

2. 解压，把里面那层 `buyi-shot-asset-pipeline-main` 改名为 `buyi-shot-asset-pipeline`

3. 整个文件夹拖进技能目录

### 放进哪个目录



| 工具                    | 放哪里                                                                                |
| --------------------- | ---------------------------------------------------------------------------------- |
| Claude Code（个人全局）     | `~/.claude/skills/buyi-shot-asset-pipeline/`，Windows 下是 `C:\Users\<你>\.claude\skills\` |
| Claude Code（只在某个项目内用） | `<项目>/.claude/skills/buyi-shot-asset-pipeline/`                                        |
| 豆包办公 / 桌面端            | 用户技能目录 `.user_skills/` 下                                                           |
| 其他支持 `SKILL.md` 的工具   | 该工具放 skills 的那个目录，结构同上                                                             |

目录名不必和 `name` 严格一致，但保持一致能省掉排查成本。各工具的具体目录以官方文档为准，认准一条：`SKILL.md`**&#x20;直接躺在这个目录里**。

### 验证装好没有

`SKILL.md` 与 `references/` 同级同时存在；输一段小故事试跑，能出「分镜包 + 资产包」，就算成功。

**别只复制&#x20;**`SKILL.md`：它靠 `references/` 的相对路径取规范，单文件进去等于断链，症状是 "装上了，但答得像没装"。

## 怎么用



1. 给它一段新故事。它会先在内部做剧本化（不输出文件），再产出两个包。

2. 打开 `references/seedance-package.md` 的第五节，把你的角色字段填进四段锁模板 ——**这是本模板唯一必须你亲自做的事**。字段清单见 `SKILL.md` 的 "怎么填四段锁"。

填完一次，之后每集都能复用同一份锁，不用重写。

## 边界（先说清不做什么）



* 只产出提示词包：不出成片、不出封面、不出短视频文案。

* 不含任何具体角色设定。角色外观、声线、嘴型由使用者定义，模板只提供字段与校验规则。

* 不绑任何画风品牌。默认写的是中性的 "日式手绘水彩二维动画"；若你要具名某位作者或某家工作室，请先确认商标与授权，再决定是否写进你自己的副本。

## 三条自检（产出前必过）



1. **素材缺漏**：每段出现的角色 / 场景 / 道具，是否都在该段 "素材" 行，且资产包有对应编号。

2. **分镜衔接**：上一段 "段末状态" 能否自然接到下一段 "视频第一帧"。

3. **台词密度**：逐段数字数，超过 6 字 / 秒（10 秒 60 字）就压缩。

## 许可

文本（`SKILL.md`、`references/`、`README.md`、`CHANGES.md`）采用 **CC BY 4.0**：可复制、可改编、可商用，需保留署名。完整说明见 `LICENSE`。

角色形象、成片素材、第三方品牌内容不在本许可范围内。