# 课程集群使用说明

课程为同学们提供了实验集群来完成作业，并用于进行最终的测试和评分。你 **可以** 不在集群上完成作业，但 **必须** 保证提交的版本能在课程集群上正常地编译和运行，否则可能导致无法得到任何作业分数。所有的正确性和性能测试，都以课程集群的运行结果为准。

## 知识储备

完成该实验需要一定的 Make、SSH、Shell 和 Linux 的使用知识。同时，我们还推荐使用 Git 进行版本控制。如果你是大三或之后选的课程，那么你应该已经在《软件工程》《编译原理》《程序设计训练》等课程中学到了相应的知识。如果你是大一大二选的课程，可以参考以下的教程进行预习：

* Git: [简明指南](https://rogerdudler.github.io/git-guide/index.zh.html)、[Git教程](https://www.liaoxuefeng.com/wiki/896043488029600) [缺失的一课](https://missing-semester-cn.github.io/2020/version-control/)、[助教编写的 Git 速查文档](https://circuitcoder.github.io/Orange-ECC/ecc/git/)、[Git Cheetsheet](https://education.github.com/git-cheat-sheet-education.pdf)
* Make: 见[网原实验相关文档]([/router/doc/howto/make/](https://lab.cs.tsinghua.edu.cn/router/doc/howto/make/))
* Shell: [缺失的一课](https://missing-semester-cn.github.io/2020/command-line/)、[Command Line Cheetsheet](https://threenine.co.uk/download/1846/)
* Linux: [USTC LUG Linux 101 在线讲义](https://101.lug.ustc.edu.cn/)

其中特别推荐 [计算机教育中缺失的一课](https://missing-semester-cn.github.io/)，其中包含了大量有用的内容。

## 集群配置

集群由五台 Dell PowerEdge R730 服务器构成，主机名为 `conv[0-4]`，硬件配置为：

* CPU: 2 $\times$ Intel(R) Xeon(R) CPU E5-2680 v4 @ 2.40GHz (14 Cores, turbo off)
* Memory: 16 $\times$ 16 GB DDR4-2400
* Network: 1000 Mbps Ethernet + 100 Gbps Infiniband EDR
* GPU: 1 $\times$ NVIDIA GeForce GTX 1080 (`conv0`) / 1 $\times$ NVIDIA Tesla P100 (`conv[1-4]`)

所有服务器都安装了 Debian 11 (bullseye) 操作系统，`conv0` 上共有 14TB 的存储，作为提供给同学的共享 home。注意 `conv0` 的 GPU 与实际计算节点不同，因此性能表现可能有较大差异。

## 访问方式

集群的登录节点 `conv0` 可供 SSH 访问，通过下发的用户名（学号）和初始密码登录到 `166.111.68.163` 的 `22222` 端口即可。在校内和校外都可直接访问，无需使用代理或者 VPN。如果使用终端，命令类似 `ssh -p 22222 2019000000@166.111.68.163`。如果使用客户端，注意不要忘记配置端口和用户名。

!!! warning "注意密码安全"

    初始密码是随机生成的，比较难记。你可以使用 `passwd` 命令更改登陆密码。为了保证安全，我们在集群上配置了密码复杂性策略：新密码必须至少 12 位长、不能包含用户名、不能包含连续的重复字符、不能包含连续的序列（如 1234）。

!!! note "IP 封禁"

    为了防止暴力破解，单个 IP 在三次登录失败后，将会被登录节点封禁 10 分钟。封禁期间，登录集群可能会遭遇连接超时问题，请稍后再试。  

为了简化过程和增强安全性，强烈推荐配置公钥进行 SSH 登录，你可以自行搜索相关的教程。如果需要使用集群上的图形化工具，需要保证本地有正在运行的 X server，并在连接时启用 SSH 的 X11 Forwarding 功能，即使用 `ssh -X` 登录集群。

!!! fail "禁止分享账号"

    禁止以任何形式将自己的账号分享给任何其他同学（无论是否选课）使用，包括且不限于提供密码、私钥等。一经发现，涉及的选课同学所有作业成绩无效。

`conv[1-4]` 为计算节点，不允许直接 SSH 连接，只能使用 SLURM 提交作业的形式在上面运行任务。

为了方便同学完成作业，`conv0` 被允许访问校外网络，而 `conv[1-4]` 不能访问集群以外的主机。

## 文件编辑

学生在集群上的 home 目录形如 `/home/course/hpc/users/2020000000`。你应当 **在且仅在** 此目录下放置作业文件。

!!! warning "注意权限"
    
    默认情况下，所有学生账号属于同一个组（`hpc-lab`），但 home 目录仅允许自己访问（默认权限为 `700`）。**严格禁止** 更改自己 home 目录的权限，以防其他人访问你的 home 目录。如果发现故意的此类行为，视同分享账号处理。

集群上安装了 VIM、Emacs、nano 等文本编辑器，你可以自由选取使用。对于不熟悉终端编辑器的同学，推荐使用 VSCode Remote SSH 的方式进行连接和编辑。当然，也可以在本地编写代码并推送到集群上测试，推荐使用 Git 来进行文件的同步和追踪，或者使用 `rsync` 只进行同步。此外，为了防止由于网络原因造成的进度丢失、程序终止等问题，推荐在登录 SSH 后使用 `screen` 或 `tmux` 来进行终端复用。本文档中不会详细介绍这些工具，建议同学们自行查阅学习，亦可询问助教。

为了防止误操作，集群的 home 使用 ZFS 配置了自动的快照备份。每个用户的 home 都是单独的 ZFS dataset，可以通过访问 `~/.zfs/snapshot/` 下各个文件夹的方式获取快照时间点时存在的的文件，文件夹名称即为快照时间。如果需要，也可以请求助教直接将整个 home 回滚到某个当前存在的快照对应的时间点。注意快照是 **只读的** ，并且在一段时间后会自动删除。请 **自行备份** 重要的文件，对于任何误操作导致的后果，包括且不限于作业丢失无法找回等，助教概不负责。

## 工具链与环境加载

集群的系统中预装了 GCC 10.2.1、GNU make、CMake 等常用的编译工具。所需的其他工具叙述如下：

### Spack

集群使用 [Spack](https://spack.io/) 管理软件包，安装在 `/home/spack/spack` 下。用户登录后，在 shell 中输入 `spack` 即可自动加载。如果需要在脚本中加载，可以使用 `source /home/spack/spack/share/spack/setup-env.sh` 语句。

使用 `spack find` 可以列出所有已经安装的软件，集群中预装了下列软件可供加载：

* `cuda@11.1.0`
* `openmpi@4.0.5`

使用 `spack load/unload xxx` 即可从当前环境中加载/移除相应的软件包，如 `spack load cuda` 后即可使用 NVCC 编译器，`spack unload openmpi` 可移除 OpenMPI。注意使用 Spack 中的软件编译得到的文件，在运行时一般也需要加载对应的软件，否则可能会出现找不到库（`.so` 文件）的错误。用户无权安装或移除 Spack 中的软件，如有特殊需要，请与助教联系。

### Intel 工具链

集群中还安装了全套的 Intel OneAPI 2021，包含 Intel MPI、MKL、ICC、vTune、Advisor 等组件。这些组件的安装目录在 `/opt/intel/oneapi` 下，可以通过其附带的脚本来加载环境，如：

```bash
source /opt/intel/oneapi/setvars.sh # 加载全部环境，或
source /opt/intel/oneapi/compiler/latest/env/vars.sh # 仅加载 ICC 编译器
source /opt/intel/oneapi/mpi/latest/env/vars.sh # 仅加载 Intel MPI
source /opt/intel/oneapi/mkl/latest/env/vars.sh # 仅加载 MKL
source /opt/intel/oneapi/vtune/latest/vtune-vars.sh # 仅加载 vTune
source /opt/intel/oneapi/advisor/latest/env/vars.sh # 仅加载 advisor
```

关于这些工具的使用方法，可以参见 [工具概述](tools.md) 部分。

## SLURM 使用

集群使用 [SLURM](https://slurm.schedmd.com/) 来管理作业提交。

!!! success "必须使用 SLURM"

    任何任务都应该使用 SLURM 进行提交，**登录节点（`conv0`）仅可进行编译和调试，禁止运行任务。**
    集群包含自动的监控脚本，如果检测到某用户在登录节点上有较长时间高负载，将会 **强制杀死** 其所有进程。

常用的 SLURM 命令包括 `sinfo`, `squeue`, `srun`, `sbatch` 和 `sacct`。

`sinfo`、`squeue` 和 `sacct` 用于状态查询。其中 `sinfo` 查询整个集群当前的状态，`squeue` 查询当前队列中正在运行和等待运行的任务（以及它们的所有者、任务名等）、`sacct` 可以查看属于自己的所有历史任务统计。这些命令的用法可以查询相应的文档，也可以查看 [此教程](https://hpc.llnl.gov/banks-jobs/running-jobs/slurm-commands)。

`srun` 用于运行单个程序，常见用法如：

```bash
srun -N 4 -n 8 --cpu-bind sockets ./test --args
```

由于机器数量有限，任务可能不会立刻被执行，此时 SLURM 会给出类似下面的提示，请耐心等待：

```text
srun: job 271 queued and waiting for resources
```

为了防止不同同学的进程互相干扰，实验集群的 SLURM 被配置为独占模式，即每个任务的 **最小分配粒度** 为单个节点。上述命令表示占用全部 4 个节点，共运行 8 个进程（每机 2 进程），并将每个进程绑定到一个 CPU socket（即一个 NUMA 节点）。通常来说，只需要关注 `-N` 和 `-n` 选项，用来控制进程数量；在一些负载上（尤其是 memory bound 程序），[进程绑定](faq/binding.md) 可能 **对性能有较大影响**，需要仔细调节。

`sbatch` 用于提交一个非交互式的运行脚本，适用于时间较长的或多个任务的提交。本文档中不详细介绍这一命令的用法，有需要的同学可以查看 [此教程](http://hpc.pku.edu.cn/_book/guide/slurm/sbatch.html)。在此脚本中，需要显式地加载 Spack、使用 Spack 加载依赖软件后，方可正常执行程序。使用 `sbatch` 和 `srun` 提交的任务都可以用 `scancel` 命令进行取消或终止。

由于 `salloc` 经常引发资源占用问题，实验集群上 **不允许** 使用此命令。

## 资源限制

!!! fail "禁止滥用"

    除了上述已经声明的事项，在使用集群时，以下行为也是 **严格禁止** 的：
    
    * 任何与课程教学内容无关的行为，包括且不限于用作入校连接跳板、下载或存放无关文件；
    * 任何尝试攻击集群的行为，包括且不限于非法提升权限、暴力破解密码、非正常读写磁盘；
    * 任何恶意的、违反法律法规的行为，包括且不限于发起网络攻击、运行加密货币挖矿；
    * 任何长时间抢占资源的行为，包括且不限于使用脚本循环提交大量任务、在跳板机上运行大量任务。

由于选课人数较多，为了保证同学们能够公平地分享集群资源，我们设定了一系列的资源限制，包括空间限制与任务运行限制。每个用户的 home 配额为 20GB，超出这一限制后将无法再创建或修改文件。如果有合理的需求，可以联系助教进行扩容。

学期中的大部分时间内，选课同学可以无限制地使用实验集群的所有计算资源，但任何 **单个任务** 消耗的实际时长被限制为 5 分钟以内。根据经验，集群在作业 deadline 前的一段时间较为繁忙，通常会出现提交任务需要排队，甚至排队较长时间的现象。为保证该时间段内所有同学均有可用的资源，在每次编程作业提交前一周（以网络学堂上的时间限制为准）内，每位同学的总机时将会被限制为 `112` 核时（即假设集群满占用状态下，每人至多在全机上运行一小时）。

如果使用的核时超出限制，可能会导致当次作业被 **扣除一定的分数** ；如果超出较多，将会导致你在本次作业周期内无法再提交任何任务。且对于超出限额的任务，随时可能会 **在不被通知的情况下被集群管理员中止** 。你可以在登录节点上运行 `my_quota` 命令来获取当前自己作业周期中的核时消耗数量（注意 `used` 对应的单位是 $核 \times 分钟$）。
