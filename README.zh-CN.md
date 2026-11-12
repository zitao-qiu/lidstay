# LidGuard

**让 MacBook 合盖后继续工作——但只在你指定的那一次。**

一个极小的 macOS 菜单栏 app。点一下，合盖，装包带走，任务继续跑。到了地方开盖，正常睡眠立刻恢复。

```
合盖 → 睡眠        （默认，安全）
合盖 → 继续运行    （仅在你主动武装期间）
```

[English](README.md) · MIT · macOS 13+

---

## 它解决什么问题

你起了一个长任务——coding agent、编译、下载、渲染——然后你必须合盖走人。

macOS 合盖就睡。这**不是** idle sleep，而是盖子传感器发给 `IOPMrootDomain` 的硬件事件。所以 **`caffeinate` 帮不上忙**，任何基于 IOKit power assertion 的 app（`KeepingYouAwake`、普通 Amphetamine session 等）同样帮不上——它们只能挡住 idle 计时器，根本看不到盖子。

唯一能压过它的是内核的 `SleepDisabled` 标志：

```sh
sudo pmset -a disablesleep 1   # 合盖不再睡
sudo pmset -a disablesleep 0   # 恢复正常
```

`disablesleep` 是未文档化参数（`man pmset` 里没有），但在 Apple Silicon 上一直到 macOS 27 都有效。

## 为什么不干脆一直开着

因为一台从不睡眠的 MacBook 塞在包里没有风道、也没有刹车。它会热，也会把电耗光。这正是所有"直接关掉睡眠"教程里警告的那个失败场景——也是为什么这里做的是**带过期时间的菜单栏开关**，而不是一个系统设置。

LidGuard 的立场：**睡眠是正确的默认值。保持运行是一个主动的、临时的例外，而且它自己会结束。**

## 工作方式

```
         点「合盖后继续运行」
idle ──────────────────────────────────────► armedOpen
  ▲                                              │
  │                                              │ 检测到合盖（每 2 秒轮询）
  │                                              ▼
  │                                         armedClosed
  │                                              │
  └──────────────────────────────────────────────┘
     开盖 / 电量下限 / 手动取消 / 退出
```

- **武装** → `sudo -n pmset -a disablesleep 1`，并写状态文件
- **解除** → `sudo -n pmset -a disablesleep 0`，删除状态文件
- 盖子状态每 2 秒从 `IOPMrootDomain` 的 `AppleClamshellState` 读取
- 电量来自 `IOPSGetPowerSourcesInfo`

状态文件记录的是 `armed-open` 还是 `armed-closed`，这样外部看门狗就能区分**"用户刚按下按钮"**和**"app 在盖子合上之后挂了"**。没有这个区分，看门狗会在你刚武装、盖子还没关的时候就把它解除掉。

## 安装

```sh
git clone https://github.com/<you>/lidguard.git
cd lidguard

make            # 构建 LidGuard.app 到 ./build
make install    # 复制到 ~/Applications

# 一次性：安装最小权限的免密 sudo 规则
./scripts/install.sh
```

`install.sh` 只会往 `/etc/sudoers.d/lidguard` 写这一行：

```
<你> ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 1, /usr/bin/pmset -a disablesleep 0
```

sudoers 按字面匹配参数、没有通配符，所以这个授权无法被扩权。它只能切换合盖睡眠，别的什么都做不了。脚本在安装前会跑 `visudo -cf` 校验，坏规则不可能弄坏你的 sudo。

需要 Swift 工具链（`xcode-select --install`）。没有 Xcode 工程、没有第三方依赖、不需要公证——本地 ad-hoc 签名即可。

## 使用

1. 启动 `~/Applications/LidGuard.app`，菜单栏出现一个笔记本图标。
2. 有任务在跑、马上要合盖 → 点图标 → **⚡ Keep running when lid closes**。图标变成闪电。
3. 合盖，装包走人。
4. 到了地方开盖——睡眠自动恢复。

也可以用命令行：

```sh
LidGuard.app/Contents/MacOS/LidGuard --status
LidGuard.app/Contents/MacOS/LidGuard --arm
LidGuard.app/Contents/MacOS/LidGuard --disarm
```

## 安全设计

| 保护 | 作用 |
|---|---|
| **开盖自动关** | `AppleClamshellState` Yes→No 立即解除 |
| **电量下限** | 电池供电时低于 15%（可调 10–30%）自动解除 |
| **退出即解除** | 武装状态下退出 app 会恢复睡眠 |
| **重启兜底** | `disablesleep` 是运行时属性，不持久化 |
| **崩溃看门狗** | `armed-open`/`armed-closed` 标记让外部守护能替 app 收尾 |

两条规则任何 app 都管不了，得你自己守：

- **绝不要把武装状态的合盖 MacBook 在电池下塞包里放几个小时。** 电量下限是缓冲，不是保险。
- **能插电就插电。** 很多 MacBook 在 AC 下合盖本来就不睡——先确认你到底需不需要这个。

## 你可能根本不需要它

值得先测一下。某些 MacBook 在 AC 下设了 `sleep 0` 之后，合盖本来就不睡。查一下：

```sh
pmset -g log | grep -i "Clamshell Sleep"
```

如果每条 `Clamshell Sleep` 都是 `Using Batt`、没有一条 `Using AC`，那你在 AC 下已经没事了，LidGuard 只在电池场景有用。

## 对比

| | LidGuard | Sleepless | Amphetamine | `caffeinate` |
|---|:---:|:---:|:---:|:---:|
| 合盖有效 | ✅ | ✅ | ⚠️ | ❌ |
| 自己结束 | ✅ 开盖即止 | ✅ 定时器 | 手动 | ✅ 进程退出 |
| 电量下限 | ✅ | ✅ | ✅ | ❌ |
| 开源 | ✅ MIT | ✅ MIT | ❌ | Apple |
| 处理"刚武装、盖子还开着"的竞态 | ✅ | n/a | n/a | n/a |

底层机制和这个领域所有项目一样——`pmset disablesleep`。LidGuard 加的是**"带走一次"的会话模型**：按需武装、开盖过期，外加一个看门狗能读懂的状态文件。

值得一读的同类项目：[Sleepless](https://github.com/Aboudjem/Sleepless)、[awake](https://github.com/pistachionet/awake)、[Awayke](https://github.com/daemonphantom/Awayke)、[lid-awake](https://github.com/austinginder/lid-awake)、[Amphetamine](https://github.com/x74353/Amphetamine)。

## 卸载

```sh
make uninstall
sudo rm /etc/sudoers.d/lidguard
rm -rf ~/.config/lidguard
```

如果卸载时正武装着，先 `--disarm`，或者执行 `sudo pmset -a disablesleep 0`。

## 目录

```
Sources/LidGuardApp.swift    整个 app，单文件（约 330 行）
scripts/install.sh           最小权限 sudoers 规则
Makefile                     build / install / run / clean / lint
```

## 许可证

MIT
