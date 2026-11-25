# Git 双机同步说明

> 仓库：<https://github.com/ZepDream/DigitalClock.git>  
> 默认分支：`main`  
> 适用：两台 Windows 电脑之间同步 Quartus / ModelSim 工程

---

## 1. 先理解三件事

1. **Git 只同步源码和文档**。`db/`、`incremental_db/`、`output_files/`、`sim/work/`、`*.vcd`、`*.wlf`、`*.sof` 等生成物已被 `.gitignore` 排除，换电脑后重新编译、重新仿真即可。
2. **Quartus 工程使用相对路径**。`.qsf`、`.qpf`、`.sdc` 和 `rtl/`、`sim/` 都是相对引用，整个目录可以放在任意盘符，不需要改工程文件。
3. **两台电脑不要同时改同一批文件**。开始改之前先 `git pull --rebase`，改完尽快 `git commit` + `git push`。

---

## 2. 新电脑第一次获取工程

### 2.1 安装并登录 Git

```bat
git --version
git config --global user.name "你的名字"
git config --global user.email "你的邮箱"
git config --global core.autocrlf true
```

第一次 `push` 时 Git Credential Manager 会弹出 GitHub 登录窗口。也可以在 GitHub 的
`Settings -> Developer settings -> Personal access tokens` 生成一个有 `repo` 权限的令牌，
把令牌当作密码使用。**不要把令牌写进仓库里的任何文件。**

### 2.2 克隆

```bat
cd /d D:\Projects
git clone https://github.com/ZepDream/DigitalClock.git
cd DigitalClock
```

克隆完成后检查：

```bat
git remote -v
git status
git log --oneline --graph --all -10
```

`git status` 应显示 `working tree clean`。

---

## 3. 日常同步流程

每次开始工作前：

```bat
cd /d <工程目录>
git pull --rebase
```

修改、编译、仿真之后：

```bat
git status
git diff
git add -A
git commit -m "时钟：修正倒计时复位逻辑"
git push
```

建议的提交粒度：

- 一次提交只做一件事（改 RTL、改文档、改脚本分开提交）；
- 提交信息写“做了什么”，不要只写 `update`；
- 提交前确认 `git status` 里没有 `db/`、`output_files/`、`sim/work/` 这类生成物。

---

## 4. 另一台电脑已有旧工程目录，怎么接入

如果另一台电脑现在是一个**没有 `.git` 的普通目录**（例如从压缩包解压出来的），推荐：

1. **先备份**整个旧目录（压缩一份，确认能打开）。
2. 把仓库克隆到一个新目录，例如 `D:\Projects\DigitalClock-git`。
3. 把旧目录里**自己改过的源码/文档**复制到新目录，覆盖同名文件。只复制这些：
   - `rtl/*.v`
   - `sim/*.v`、`sim/*.do`、`sim/*.bat`
   - `docs/*.md`、`README.md`
   - `constraints/*`
   - `DigitalClock.qsf`、`DigitalClock.qpf`、`DigitalClock.sdc`
4. 在新目录里用 `git status` / `git diff` 检查差异，确认无误后提交并推送。
5. 以后都使用新目录，旧目录只保留作备份。

不推荐直接在旧目录里 `git init` 再强推，因为旧目录里的生成物、临时文件、换行符差异会把真正的修改淹没，容易误覆盖另一台电脑的提交。

---

## 5. 两台电脑之间的推荐节奏

| 场景 | 操作 |
|---|---|
| 早上开始 | `git pull --rebase` |
| 改完一个功能 | `git add -A` → `git commit` → `git push` |
| 换电脑继续 | 在另一台先 `git pull --rebase` |
| 只想看差异 | `git diff`、`git log --oneline -10` |
| 发现改坏了 | `git restore <文件>`；已提交则 `git revert <提交>` |
| 生成物太多 | 确认 `.gitignore` 生效，不要 `git add -f` |

---

## 6. 冲突处理

`git pull --rebase` 遇到冲突时会停在 `REBASE 1/1`：

```bat
git status
```

1. 打开冲突文件，搜索 `<<<<<<<`、`=======`、`>>>>>>>`，保留正确内容并删除标记。
2. 标记为已解决：

```bat
git add <冲突文件>
git rebase --continue
```

3. 如果这次拉取不想要了：

```bat
git rebase --abort
```

4. 解决完再 `git push`。

Verilog 文件冲突时，优先以“功能正确、能通过 `sim\run_sim.bat` 的 82 个 PASS”为准；文档冲突可以两边内容合并。

---

## 7. 本地工具路径

本仓库不写死任何一台电脑的 Quartus / ModelSim 路径：

- Quartus 用 `File -> Open Project` 打开 `DigitalClock.qpf` 即可，工程内部是相对路径；
- `sim\run_sim.bat` 自动查找 `vsim.exe`，顺序见 [仿真操作流程说明书](04_simulation_manual.md) 第 1.3 节；
- 如果自动查找失败，只在当前命令行窗口设置一次：

```bat
set MODELSIM_BIN=G:\APP\Quartus\17.1\modelsim_ase\win32aloem
sim\run_sim.bat
```

Python 辅助脚本（`extract_docx.py`、`list_images.py`、`map_images.py`、`find_fig.py`）
都以脚本所在目录为基准查找 `refs/`，换电脑后不需要改路径。前三个脚本需要
`python-docx`，新电脑上执行一次：

```bat
python -m pip install python-docx
```

`find_fig.py` 只读 `refs/body_map.txt`，不需要额外依赖。

---

## 8. 每次换电脑后的验证清单

```bat
git pull --rebase
git status
sim\run_sim.bat
```

- `git status`：工作区干净，或只剩你正在改的文件；
- `sim\run_sim.bat`：最后输出 `==== ALL TESTS PASSED ====` 和 `82 PASS, 0 ERROR`；
- Quartus：`Processing -> Start Compilation`，确认 `0 errors`，生成 `output_files/DigitalClock.sof`；
- 上板前确认实验箱模式为 **No.9**，再下载 `.sof`。

---

## 9. 常用命令速查

```bat
git status                     :: 看当前状态
git diff                       :: 看未暂存的修改
git add -A                     :: 暂存全部修改
git commit -m "说明"           :: 提交
git push                       :: 推到 GitHub
git pull --rebase              :: 拉取并把自己的提交放到最新提交之后
git log --oneline --graph -10  :: 看最近提交
git remote -v                  :: 看远程地址
git restore <文件>             :: 丢弃未提交修改
```
