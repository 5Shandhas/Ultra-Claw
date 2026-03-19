# Ultra-Claw Windows 新手使用说明

一般用法：

右键->运行 即可

1. 先使用`setup.ps1`安装
2. 后使用`windows-start.ps1`初始化并启动服务
3. 日常用`ultra-claw-console.ps1`管理以及配置，启动
4. 如果想要装到电脑里，用 `Windows-Install.bat`，安装路径为`~/.openclaw` 和`~/.uclaw`
5. 因为直接没有环境变量，使用 `envset.ps1`进行环境变量安装

## 1. `setup.ps1`

怎么用：

- 先运行 `setup.ps1`

为什么这样用：

- 它负责下载和安装运行环境
- 没有这一步，后面的启动脚本可能找不到 Node.js 或 OpenClaw

## 2. `windows-start.ps1`

怎么用：

- 安装完成后运行 `windows-start.ps1`

为什么这样用：

- 它负责启动 Ultra-Claw 服务
- 这个窗口不要关，关掉服务就停了

补充：

- 如果已经配好模型，它会打开 Dashboard
- 如果还没配好模型，它会提示你去用 `ultra-claw-console.ps1`

## 3. `ultra-claw-console.ps1`

怎么用：

- 用它来配置模型、通信工具和其他选项

为什么这样用：

- 现在初始化和配置都主要放在这里做
- 比直接改配置文件更适合新手

## 4. `Windows-Install.bat`

怎么用：

- 如果你不想一直从当前目录运行，而是想安装到电脑里，就运行它

为什么这样用：

- 它负责把当前这套 Ultra-Claw 安装成电脑里的本地版本

## 5. `envset.ps1`

怎么用：

- 如果安装版位置变了，或者系统里的 OpenClaw 路径不对，再运行它

为什么这样用：

- 它负责调整系统环境变量，让系统知道 OpenClaw 在哪里

## 最短版

新手只记这一句：

先跑 `setup.ps1`，再跑 `windows-start.ps1`，然后用 `ultra-claw-console.ps1` 配模型和渠道。


本项目参考来源于U-Claw，项目地址：https://github.com/dongsheng123132/u-claw.git

Contact
邮箱: uppixer@qq.com
Website: www.uppixer.com
