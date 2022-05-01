# 进程绑定 {#process-binding}

??? tip "TL; DR:"

    ```bash
    srun -n 28 -N 1 --cpu-bind=cores ./exe # 28P
    OMP_NUM_THREADS=28 OMP_PROC_BIND=true OMP_PLACES=cores srun -n 1 -N 1 --cpu-bind=none ./exe # 28T * 1P
    OMP_NUM_THREADS=14 OMP_PROC_BIND=true OMP_PLACES=cores srun -n 2 -N 1 --cpu-bind=sockets ./exe # 14T * 2P
    ```

在复制和使用上面的命令前，请确保你已经阅读和理解了下面的所有内容。

## 基础概念 {#basic-ideas}

### 多核处理器系统 {#multicore-system}

现代多核处理器系统通常由多个层级构成：

* 插槽（socket） / 封装（package）：指物理和机械上可分的 CPU。家用 PC 通常为单 socket，服务器通常可支持 2 socket（也常称为“双路”），也有 4 或者 8 socket。不同的 socket 之间通常通过高速总线连接，如 Intel 的 [QPI](https://www.intel.com/content/www/us/en/io/quickpath-technology/quickpath-technology-general.html)、AMD 的 [Infinity Fabric](https://www.amd.com/zh-hans/technologies/infinity-architecture)。
* 核心（core）：指 CPU 上完整、可独立执行控制流的处理单元，也是操作系统调度进程的单位。目前常见的家用和服务器处理器均为多核处理器，如一块 [AMD EPYC 7763](https://www.amd.com/zh-hans/products/cpu/amd-epyc-7763) 处理器有 64 个 core，而一块 [Intel Xeon Platinum 8380](https://www.intel.com/content/www/us/en/products/sku/212287/intel-xeon-platinum-8380-processor-60m-cache-2-30-ghz/specifications.html) 有 40 个 core。
* [超线程（hyper-threading，简写为 HT）](https://en.wikipedia.org/wiki/Hyper-threading)：将单个物理 CPU 核心虚拟为多个逻辑核心，以充分利用其中计算单元的技术。目前使用的处理器通常为每核心 2 超线程。通常所说 CPU 的“线程（thread）”或“硬件线程（hardware thread / hwt）”数包含超线程（注意与操作系统中的软件线程区分），如 Intel Core i7-10700K 有 8 个核心、16 个线程，可记为 8C16T。

由于 “CPU” 一词可被用于指代任一级别的单元，我们不推荐单独使用此措辞，以免产生歧义。

!!! note "超线程的利弊"

    超线程技术并非在所有情况下都能带来性能收益。  
    CPU 的指令级并行（ILP）也倾向于充分利用计算单元，在计算密集的负载上，超线程还可能会因引入额外开销（如系统调度等宏观因素，分支预测槽数量减少等微体系结构因素）而降低性能。

!!! example "`conv` 集群的结构"

    课程使用的 `conv` 集群每个节点安装了双路 [Intel(R) Xeon(R) CPU E5-2680 v4](https://www.intel.cn/content/www/cn/zh/products/sku/199335/intel-core-i710700k-processor-16m-cache-up-to-5-10-ghz/specifications.html) 处理器，并且关闭了超线程。
    每个节点共有 2 socket $\times$ 14 core $\times$ 1 = 28 threads。

### NUMA 架构与效应 {#numa-architecture-and-effect}

现代处理器均采用 [NUMA 架构](https://en.wikipedia.org/wiki/Non-uniform_memory_access)，每个 socket 通过内存控制器连接本地内存（local memory），通过 socket 间的高速总线访问属于其他 socket 的远端内存（remote memory）。我们将直接连接的 CPU core 和内存和其他外设（如网卡、GPU）称为一个 NUMA domain（或 NUMA node），在同一个 domain 中（intra-domain）的访存性能（包括带宽和延迟）通常显著高于跨 NUMA（inter-domain）的性能，这种现象被称为 NUMA 效应。

事实上，现代处理器的 NUMA domain 划分并不只到 socket 粒度，可以继续细分出不同级别。如 [AMD 文档](https://www.amd.com/system/files/2018-03/AMD-Optimizes-EPYC-Memory-With-NUMA.pdf) 的图 2 和 3 所示，EPYC 3 处理器使用的 Zen 3 架构中，每个 socket 由 4 个全相连的 die 构成，每个 die 直接连接自己的 DDR 内存控制器。因此每个 socket 可以划分出 4 个子 NUMA domain，子 domain 内的访存也快于跨子 domain 的互访。更进一步地，由于每四个 core 共享一个缓存控制器（CCX），因此 CCX 可以作为更次一级的 NUMA domain 划分依据。在这样的 socket - die - CCX 三级划分下，双路 EPYC 7763 处理器系统的 128 个 core 可以划分成 32 个最细粒度的 CCX-level domain，8 个 die-level domain 和 2 个 socket-level domain。

NUMA domain 越细分，则 NUMA 效应越不明显。通常， **只需关注 socket-level domain** 即可避免 NUMA 效应的负面影响。

??? tip "查看 NUMA 拓扑"

    通过 `lscpu` 即可查看系统的 NUMA domain 和 CPU 核心编号的映射，如：

    ```text
    NUMA node0 CPU(s):               0,2,4,6,8,10,12,14,16,18,20,22,24,26
    NUMA node1 CPU(s):               1,3,5,7,9,11,13,15,17,19,21,23,25,27
    ```

    表明此系统中的 CPU 核心编号划分是交错（interleaving）的，即编号为偶数的核心属于 NUMA node 0 (socket 0)，奇数属于 NUMA node 1 (socket 1)，依此类推。还有一类编号方式称为连续编号，即连续的若干 core 均属于同一个 NUMA domain。Intel CPU 通常使用交错编号，而 AMD CPU 通常使用连续编号。
    
    在有 $C$ 个 CPU 核心的交错编号 NUMA 系统中，任何一级 NUMA domain 的所有核心编号都可以写成 $2^L \times K + P$ 的形式，其中 $L$ 是 NUMA 层级，$P \in \{0, \dots, 2^L - 1\}$ 是 NUMA domain 的编号，$K = 0, \dots, \frac{C}{2^L} - 1$ 遍历 NUMA 中的所有核心。

    `numactl -H` 也可以显示类似的信息：

    ```text
    available: 2 nodes (0-1)
    node 0 cpus: 0 2 4 6 8 10 12 14 16 18 20 22 24 26
    node 0 size: 128831 MB
    node 0 free: 95549 MB
    node 1 cpus: 1 3 5 7 9 11 13 15 17 19 21 23 25 27
    node 1 size: 129019 MB
    node 1 free: 101947 MB
    node distances:
    node   0   1 
    0:  10  21 
    1:  21  10
    ```

    通过 `hwloc` 软件包中的 `lstopo` 命令可以获得更多细节信息。如在 `conv` 集群上，`lstopo` 输出如下：

    ```text
    Machine (252GB total)
    Package L#0
        NUMANode L#0 (P#0 126GB)
        L3 L#0 (35MB)
        L2 L#0 (256KB) + L1d L#0 (32KB) + L1i L#0 (32KB) + Core L#0 + PU L#0 (P#0)
        L2 L#1 (256KB) + L1d L#1 (32KB) + L1i L#1 (32KB) + Core L#1 + PU L#1 (P#2)
        L2 L#2 (256KB) + L1d L#2 (32KB) + L1i L#2 (32KB) + Core L#2 + PU L#2 (P#4)
        L2 L#3 (256KB) + L1d L#3 (32KB) + L1i L#3 (32KB) + Core L#3 + PU L#3 (P#6)
        L2 L#4 (256KB) + L1d L#4 (32KB) + L1i L#4 (32KB) + Core L#4 + PU L#4 (P#8)
        L2 L#5 (256KB) + L1d L#5 (32KB) + L1i L#5 (32KB) + Core L#5 + PU L#5 (P#10)
        L2 L#6 (256KB) + L1d L#6 (32KB) + L1i L#6 (32KB) + Core L#6 + PU L#6 (P#12)
        L2 L#7 (256KB) + L1d L#7 (32KB) + L1i L#7 (32KB) + Core L#7 + PU L#7 (P#14)
        L2 L#8 (256KB) + L1d L#8 (32KB) + L1i L#8 (32KB) + Core L#8 + PU L#8 (P#16)
        L2 L#9 (256KB) + L1d L#9 (32KB) + L1i L#9 (32KB) + Core L#9 + PU L#9 (P#18)
        L2 L#10 (256KB) + L1d L#10 (32KB) + L1i L#10 (32KB) + Core L#10 + PU L#10 (P#20)
        L2 L#11 (256KB) + L1d L#11 (32KB) + L1i L#11 (32KB) + Core L#11 + PU L#11 (P#22)
        L2 L#12 (256KB) + L1d L#12 (32KB) + L1i L#12 (32KB) + Core L#12 + PU L#12 (P#24)
        L2 L#13 (256KB) + L1d L#13 (32KB) + L1i L#13 (32KB) + Core L#13 + PU L#13 (P#26)
        HostBridge
        PCIBridge
            PCI 03:00.0 (RAID)
            Block(Disk) "sdf"
            Block(Disk) "sdd"
            Block(Disk) "sdb"
            Block(Disk) "sdg"
            Block(Disk) "sde"
            Block(Disk) "sdc"
            Block(Disk) "sda"
            Block(Disk) "sdh"
        PCIBridge
            PCI 02:00.0 (Ethernet)
            Net "eno3"
            PCI 02:00.1 (Ethernet)
            Net "eno4"
        PCIBridge
            PCI 01:00.0 (Ethernet)
            Net "eno1"
            PCI 01:00.1 (Ethernet)
            Net "eno2"
        PCI 00:11.4 (SATA)
        PCIBridge
            PCIBridge
            PCIBridge
                PCIBridge
                PCI 0a:00.0 (VGA)
        PCI 00:1f.2 (SATA)
            Block(Removable Media Device) "sr0"
    Package L#1
        NUMANode L#1 (P#1 126GB)
        L3 L#1 (35MB)
        L2 L#14 (256KB) + L1d L#14 (32KB) + L1i L#14 (32KB) + Core L#14 + PU L#14 (P#1)
        L2 L#15 (256KB) + L1d L#15 (32KB) + L1i L#15 (32KB) + Core L#15 + PU L#15 (P#3)
        L2 L#16 (256KB) + L1d L#16 (32KB) + L1i L#16 (32KB) + Core L#16 + PU L#16 (P#5)
        L2 L#17 (256KB) + L1d L#17 (32KB) + L1i L#17 (32KB) + Core L#17 + PU L#17 (P#7)
        L2 L#18 (256KB) + L1d L#18 (32KB) + L1i L#18 (32KB) + Core L#18 + PU L#18 (P#9)
        L2 L#19 (256KB) + L1d L#19 (32KB) + L1i L#19 (32KB) + Core L#19 + PU L#19 (P#11)
        L2 L#20 (256KB) + L1d L#20 (32KB) + L1i L#20 (32KB) + Core L#20 + PU L#20 (P#13)
        L2 L#21 (256KB) + L1d L#21 (32KB) + L1i L#21 (32KB) + Core L#21 + PU L#21 (P#15)
        L2 L#22 (256KB) + L1d L#22 (32KB) + L1i L#22 (32KB) + Core L#22 + PU L#22 (P#17)
        L2 L#23 (256KB) + L1d L#23 (32KB) + L1i L#23 (32KB) + Core L#23 + PU L#23 (P#19)
        L2 L#24 (256KB) + L1d L#24 (32KB) + L1i L#24 (32KB) + Core L#24 + PU L#24 (P#21)
        L2 L#25 (256KB) + L1d L#25 (32KB) + L1i L#25 (32KB) + Core L#25 + PU L#25 (P#23)
        L2 L#26 (256KB) + L1d L#26 (32KB) + L1i L#26 (32KB) + Core L#26 + PU L#26 (P#25)
        L2 L#27 (256KB) + L1d L#27 (32KB) + L1i L#27 (32KB) + Core L#27 + PU L#27 (P#27)
        HostBridge
        PCIBridge
            PCI 82:00.0 (VGA)
            CoProc(CUDA) "cuda0"
        PCIBridge
            PCI 83:00.0 (InfiniBand)
            Net "ibp131s0"
            OpenFabrics "ibp131s0"

    ```

    说明每个 socket 的 14 个 core 属于一个 NUMA domain，每个 domain 都安装了 128GB 内存。domain `L#0` 还安装了硬盘控制器、以太网卡等外设，`L#1` 则安装了 GPU 和 IB 卡。

### 进程绑定的意义 {#importance-of-binding}

当处理器中存在多个 CPU 核心时，操作系统的调度器会将进程在可用的核心间千亿，以试图维持负载均衡。在一个多 NUMA 系统中，如果进程被迁移到了与创建时不同的 NUMA domain，就可能影响性能（Linux 在 [NUMA 感知调度](https://lwn.net/Articles/568870/) 上进行了一些努力，但由于多种原因效果并不理想）。此外，进程迁移时必须暂停，在新的核心上也会不可避免地遇到 cache、分支预测器等组件的冷启动开销，产生性能波动。因此，在运行计算密集的程序时，通常需要将进程、线程与 CPU 核心进行绑定（binding / pinning），即控制进程与 CPU 核心的亲和性（affinity），消除上述的各类影响。

## 绑定方法 {#binding-approaches}

### MPI 程序 {#mpi-programs}

MPI 程序由于进程间不共享内存，受 NUMA 效应的影响一般不显著。这意味着通常运行 MPI 程序时，可以占满所有物理核心而无需考虑 NUMA 效应带来的性能损失。当然，实际进程数也需要根据程序的可扩展性确定。

#### MPI runner 绑定 {#mpi-runner-binding}

!!! note "课程集群不可用"

    `conv` 集群上不允许使用 `mpirun` 启动程序，因此无法使用此方法。

`mpirun` 在执行程序时可以使用一系列参数指导进程绑定，如 OpenMPI 支持：

* `--bind-to-x`：自动绑定每个进程到 core 或者 socket（并可通过 `--map-by` 控制进程映射），详见 [文档](https://www.open-mpi.org/faq/?category=tuning#using-paffinity-v1.4)，使用 `--report-bindings` 可以打印出绑定情况；
* [Rankfile](https://www.open-mpi.org/faq/?category=tuning#using-paffinity-v1.3): 手工编写文件精细调整每个进程的绑定。

Intel MPI 则使用一系列 `I_MPI_PIN` 开头的环境变量进行控制，行为较为复杂，可见 [文档](https://www.intel.com/content/www/us/en/develop/documentation/mpi-developer-reference-linux/top/environment-variable-reference/process-pinning/environment-variables-for-process-pinning.html) 说明。

#### SLURM 绑定 {#slurm-binding}

SLURM 的进程绑定分为三级，具体可以查阅 [此文档](https://slurm.schedmd.com/mc_support.html)。使用 low-level 的 `--cpu-bind` 参数可以用于精确地控制绑定，SLURM 也可以根据参数组合进行自动的绑定。在 `conv` 集群上使用 `-n 28 -N 1` 时（占满 CPU 核心），绑定参数效果举例如下：

* `[empty]`：自动绑定一个进程到每个核心，等价于 `--cpu-bind=cores`
* `--ntasks-per-socket=14`：每个 socket 绑定 14 个进程，等价于 `--cpu-bind=sockets` 或 `--cpu-bind=ldom`
* `--cpu-bind=none`：不进行任何绑定

??? tip "调试方法"

    可以给 `--cpu-bind` 传入 `verbose`（或者配置环境变量 `SLURM_CPU_BIND=verbose`）显示绑定结果，如：

    ```text
    $ srun -n 2 -N 1 --cpu-bind=verbose,sockets ./exe
    cpu-bind=MASK - conv2, task  1  1 [433646]: mask 0xaaaaaaa set
    cpu-bind=MASK - conv2, task  0  0 [433645]: mask 0x5555555 set
    ...
    ```

    SLURM 打印的是每个进程可以使用的 CPU core 的掩码，如上例中 0 号进程被绑定到 CPU 0 2 4 6 8 10 12 14 16 18 20 22 24 26，1 号进程被绑定到 CPU 1 3 5 7 9 11 13 15 17 19 21 23 25 27。

如果进程数没有占满 CPU 物理核心，则自动绑核无法工作， **必须手工指定** 上述参数。

#### `numactl` 手工绑定 {#numactl-manual-binding}

如果 MPI 或者 SLURM 提供的参数无法满足需求，或者需要在多个环境下工作，就需要使用 `numactl` 进行手工的映射和绑定，重要的参数包括：

* `--physcpubind / -C n`：绑定到编号为 `n` 的 core
* `--cpunodebind / -N n`：绑定到编号为 `n` 的 socket
* `--membind / -m n`：绑定到编号为 `n` 的 NUMA domain

使用 `numactl` 时，通常需要一个包裹脚本（wrapper script）来辅助工作。其可以从环境变量中得到自身在本机的进程编号，计算出需要的绑定参数并进行配置。

??? example "示例脚本"

    如下的脚本把每个进程绑定到一个 NUMA domain 的若干连续核心上（仅适用于 **交错编号** 的 CPU），并且相邻进程的 NUMA domain 编号也交错分布。这类绑定对下文提及的 OpenMP + MPI 混合情况很有用。

    ```bash
    #!/bin/bash

    # LOCAL_RANK=$OMPI_COMM_WORLD_LOCAL_RANK # for OpenMPI
    # LOCAL_RANK=$MPI_LOCALRANKID # for Intel MPI
    LOCAL_RANK=$SLURM_LOCALID # for SLURM

    # LOCAL_SIZE=$OMPI_COMM_WORLD_LOCAL_SIZE # for OpenMPI
    # LOCAL_SIZE=$MPI_LOCALNRANKS # for Intel MPI
    LOCAL_SIZE=$SLURM_TASKS_PER_NODE # for SLURM

    NCPUS=$(nproc --all) # eg: 28
    NUM_NUMA=2

    # calculate binding parameters
    # bind to sequential cores in a NUMA domain
    CORES_PER_PROCESS=$(($NCPUS / $LOCAL_SIZE)) # eg: 7 when LOCAL_SIZE=4
    NUMA_ID=$(($LOCAL_RANK / $NUM_NUMA)) # eg: 0, 0, 1, 1
    NUMA_OFFSET=$(($LOCAL_RANK % $NUM_NUMA)) # 0, 1, 0, 1
    CORE_START=$(($NUMA_ID * $CORES_PER_PROCESS * $NUM_NUMA + $NUMA_OFFSET)) # eg: 0, 1, 14, 15
    CORE_END=$((($NUMA_ID + 1) * $CORES_PER_PROCESS * $NUM_NUMA - $NUM_NUMA + $NUMA_OFFSET)) # eg: 12, 13, 26, 27
    CORES=$(seq -s, $CORE_START $NUM_NUMA $CORE_END) # eg: 0,2,4,6,8,10,12 for rank 0

    # execute command with specific cores
    echo "Process $LOCAL_RANK on $(hostname) bound to core $CORES"
    exec numactl -C "$CORES" $@
    ```

    如果任务使用 MPI launcher 直接启动，则应当使用 MPI 提供的环境变量，不同的实现名称可能不同。如果是使用 SLURM 启动的，则只能使用 SLURM 提供的环境变量，因为脚本执行时 MPI 环境尚未初始化。

使用 wrapper script 运行时，需要禁用 MPI 或者 SLURM 的进程绑定功能（如 `mpirun --bind-to-none` 或者 `srun --cpu-bind=none`），避免互相干扰，原本的运行命令直接作为 wrapper script 的参数传入即可，如：`srun -n 4 -N 1 --cpu-bind=none ./wrapper.sh ./exe --foo --bar`。

!!! warning "注意映射"

    编写 wrapper script 时，一定需要注意 CPU 核心编号与 NUMA domain 的对应关系（以及与进程通信、访存逻辑的配合），错误的绑定会带来 **严重的性能下降** 。

### OpenMP 程序 {#openmp-program}

同一进程内的所有 OpenMP 线程共享地址空间，因此容易受到 NUMA 效应的影响。尤其是访存密集的负载在线程数超过单个 NUMA domain 的核心数时，很可能产生性能下降。因此，线程数并非越多越好，编写程序时也需要考虑到此影响。

OpenMP 进程使用以下的方式控制线程的绑定：

* [`OMP_PROC_BIND` 环境变量](https://www.openmp.org/spec-html/5.0/openmpse52.html) / [`proc_bind` 指令](https://www.openmp.org/spec-html/5.0/openmpsu36.html#x56-900002.6.2)：控制线程绑定与否，以及线程对于绑定单元（称为 place）分布
* [`OMP_PLACES` 环境变量](https://www.openmp.org/spec-html/5.0/openmpse53.html)：控制每个 place 的对应，常用 `threads/cores/sockets`

在 `conv` 集群上举例如下：

* `OMP_NUM_THREADS=28 OMP_PROC_BIND=true OMP_PLACES=cores`：每个线程绑定到一个 core，使用默认的分布（线程 `n` 绑定到 core `n`）；
* `OMP_NUM_THREADS=2 OMP_PROC_BIND=true OMP_PLACES=sockets`：每个线程绑定到一个 socket；
* `OMP_NUM_THREADS=4 OMP_PROC_BIND=close OMP_PLACES=cores`：每个线程绑定到一个 core，线程在 socket 上连续分布（分别绑定到 core `0,1,2,3`；
* `OMP_NUM_THREADS=4 OMP_PROC_BIND=spread OMP_PLACES=cores`：每个线程绑定到一个 core，线程在 socket 上尽量散开分布（分别绑定到 core `0,7,14,21`；

特别地，Intel 的 OpenMP 运行时也支持通过 `KMP_AFFINITY` 环境变量控制绑定（可见 [文档](https://www.intel.com/content/www/us/en/develop/documentation/cpp-compiler-developer-guide-and-reference/top/optimization-and-programming-guide/openmp-support/openmp-library-support/thread-affinity-interface-linux-and-windows.html)）。但这一行为并不在 OpenMP 标准中，因此也不受其他的实现支持。

### MPI + OpenMP 混合程序 {#mpi-openmp-hybrid-program}

在使用 MPI + OpenMP 混合编程时，进程绑定对性能的影响尤为关键。每个 MPI 进程需要绑定在一组核心上（通常属于同一个 NUMA domain），并把它的 OpenMP 线程绑定在其中的每个核心上。如在 `conv` 集群上，使用 2 进程 $\times$ 14 线程的绑定方式为：

```bash
OMP_NUM_THREADS=14 OMP_PROC_BIND=true OMP_PLACES=cores srun -n 2 -N 1 --cpu-bind=sockets ./exe
```

OpenMP 线程只能绑定于其“可见”的核心上，也就是父进程被绑定的核心。上面使用 SLURM 的 `--cpu-bind=sockets` 实现了每进程分配 14 个核心，与 14 个 OpenMP 线程恰好一一对应。如果需要更复杂的绑定关系（如 4 进程 $\times$ 7 线程），则需要借助更复杂的进程绑定选项或者 wrapper script 来精细控制每个进程可见的核心。如使用上面提供的 wrapper script，可直接运行 `OMP_NUM_THREADS=7 OMP_PROC_BIND=true OMP_PLACES=cores srun -n 4 -N 1 --cpu-bind=none ./wrapper.sh ./exe`，则 4 个进程分别会被绑定在编号为 `0,2,4,6,8,10,12`，`1,3,5,7,9,11,13`，`14,16,18,20,22,24,26`，`15,17,19,21,23,25,27` 的核心上。

??? error "错误示例"

    在 `conv` 上，下面这种尝试是 **错误的**：

    ```bash
    OMP_NUM_THREADS=7 OMP_PROC_BIND=true OMP_PLACES=cores srun -n 4 -N 1 --cpu-bind=sockets ./exe
    ```

    这是由于 MPI 进程的绑定粒度为 socket，0、2 号进程“可见”的核心均为 socket 0 的所有 14 个核心。所以它们都会把自己绑定在 socket 0 的前 7 个核心上（并因此产生严重资源竞争），而不是均分这 14 个核心。1、3 号进程同样会竞争 socket 1 的前 7 个核心。

!!! warning "谨慎控制数量"

    无论使用何种编程模型，除非有充分的理由和实验证据，并行单元的数量 **不要** 超过系统的物理核心数（oversubscribe）。

### 程序主动绑定 {#programmatic-binding}

除了上述几种在运行时指定的绑定方式外，程序可以主动调用系统接口或第三方库控制自己的 CPU 绑定，例如：

* POSIX [`sched_setaffinity(2)`](https://man7.org/linux/man-pages/man2/sched_setaffinity.2.html) / [`pthread_getaffinity_np(3)`](https://linux.die.net/man/3/pthread_getaffinity_np) API；
* [`libnuma`](https://man7.org/linux/man-pages/man3/numa.3.html)：`numactl` 底层使用的库；
* [`libhwloc`](https://www.open-mpi.org/projects/hwloc/)：OpenMPI 项目中衍生的可移植库。

在程序中直接控制绑定可以实现更丰富灵活的功能，也是某些情况下的唯一选择（如基于 `pthread` 的多线程程序）。但这些方法更容易与外部的绑定配置产生冲突，因此需要谨慎使用。

## 调试工具 {#debugging-tools}

* launcher 打印：
    * `srun --cpu-bind=verbose`
    * `mpirun --report-binding`
* 进程内获取：
    * [`sched_getaffinity(2)`](https://man7.org/linux/man-pages/man2/sched_setaffinity.2.html) / [`pthread_getaffinity_np(3)`](https://linux.die.net/man/3/pthread_getaffinity_np)
    * `libnuma` / `libhwloc` 中的相应函数
* 工具程序：
    * `numactl --show`
    * **[`affinity-test`](https://github.com/thu-cs-lab/affinity-test)（推荐）** ：课程组编写的小工具，可以打印和绘制每个线程和进程的绑定情况

在 `conv` 集群上，可直接通过 `/home/course/hpc/tools/affinity-test` 运行 `affinity-test`。可以通过这一工具来测试上面各种方式的绑定结果，修改参数观察并对结果的影响，以获得更深的体会。

## 参考资料 {#references}

除上文中提及的文档外，还有一些可以参考的资料（不断更新）：

* [Binding/Pinning - HPC Wiki](https://hpc-wiki.info/hpc/Binding/Pinning)
* [AMD 2nd Gen EPYC CPU Tuning Guide for InfiniBand HPC](https://hpcadvisorycouncil.atlassian.net/wiki/spaces/HPCWORKS/pages/1280442391/AMD+2nd+Gen+EPYC+CPU+Tuning+Guide+for+InfiniBand+HPC)
