# About

This prototype is not exactly an actual game but a tool to learn game-feel techniques.

![g01-compare](https://github.com/deepnight/gamefeel/assets/1671695/1df44af1-d244-46d6-a2d0-59568b1eff4c)


**It was designed to show the impact of small details on the overall quality and feeling of a game.**

**它（本项目gamefeel）旨在展示小细节对游戏整体质量和感觉的影响。**

You can enable or disable individual game features in this demo by pressing the START button (gamepad) or the ENTER key (keyboard).

# Compiling

The individual examples should be quite self-explanatory and rather straight forward to implement in any game engine. However, if you need any kind of insight on how they work, feel free to open an issue or drop my an email :)

You will need the [Haxe](https://haxe.org) compiler and [Heaps](https://heaps.io)  library.

You should read the instructions on my GameBase project (https://github.com/deepnight/gameBase).

# 本地项目操作步骤

1. 下载项目代码 git clone git@github.com:liupu9/gamefeel.git
2. 安装Haxe语言开发环境，安装完成后执行 haxe --version  当前版本为4.3.4
3. 进入gamefeel目录后，执行命令 haxe setup.hxml ，用于下载项目依赖的版本
4. 执行 haxe build.dev.hxml 或 haxe build.js.hxml 分别生成开发、JS环境在bin目录下 client.hl client.js

## 调试步骤
1. 安装VScode插件 Haxe 和 HashLink Debugger
2. 下载HashLink工具，hl.exe放入Path中
3. 选择 HL debug 后， 下断点， 按F5开始调试代码 hl bin/client.hl

至此完成了本地项目的运行和调试的基本步骤，记录在此。

# Credits

Tileset: Inca by Kronbits (https://kronbits.itch.io/inca-game-assets)
