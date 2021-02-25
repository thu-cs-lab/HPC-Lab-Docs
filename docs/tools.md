# 工具说明

本页包含了一些常用的工具的简要说明， **强烈推荐** 使用前阅读它们自带的文档并理解各个选项的含义。

### 编译器、支持库

## GCC

GCC 内置于系统中可以直接使用，常用编译选项：

* `-O[1-3,fast]`：优化等级，越高则越激进；
* `-march=native -mtune=native`：目标平台，使用 `native` 一般可以获得最高性能；
* `-g`：启用调试符号
* `-fopenmp`：启用 OpenMP 支持
* `-lfoo`：链接到名为 `libfoo.so/a` 的库

## Intel C++ Compiler (ICC)

使用 ICC 前需要先加载（见集群使用说明），其常用编译选项与 GCC 基本一致，不同的包括：

* `-xHost` 替代了 `-march=native`
* `-qopenmp` 代替了 `-mopenmp`

## OpenMPI / Intel MPI

在使用 MPI 时，需要加载对应的软件，并使用如下的命令：

* `mpicc/mpicxx/mpifort`: OpenMPI + GCC
* `mpiicc/mpiicpc`: Intel MPI + ICC

MPI 与编译器并非绑定的，这两者都支持通过环境变量调整实际使用的编译器，具体可自行查询。

## Intel Math Kernel Library (MKL)

如果需要使用 MKL，则将引入比较复杂的编译选项。推荐使用 [Intel 提供的工具](https://software.intel.com/sites/products/mkl/mkl_link_line_advisor.htm) 来生成所需的编译和链接选项。


### 性能分析工具

在使用性能分析工具前，请确保编译时打开了调试符号（`-g` 选项），否则可能得到无法理解的结果。

## Linux `perf` 命令

`perf` 是 Linux 自带的 Profiler，可以分析程序的热点和多种性能指标。常用的子命令包括：

* `perf record`：运行程序并采样以供分析；
* `perf report`：对此前的采样文件进行分析并呈现热点；
* `perf stat`：运行程序并统计性能指标；
* `perf top`：查看当前运行的程序的概况。

具体用法可查阅 [perf Examples](http://www.brendangregg.com/perf.html) 或 [Perf Wiki](https://perf.wiki.kernel.org/index.php/Main_Page)。

## NVIDIA `nvprof` 命令

`nvprof` 是 CUDA 自带的 profiler，需要使用 Spack 加载 `cuda` 后方可使用。其最简单的用法是直接在运行的程序前面添加 `nvprof`，即可得到所有 kernel 的性能指标。通常，还可以将 profile 结果写入文件，即 `nvprof -o name.nvprof ./cuda_prog`。`nvprof` 生成的 trace 文件可以使用图形化工具 NVIDIA Visual Profiler 打开，并进行进一步的分析。只需要使用 X11 转发连接集群（或者将它们复制到本地），并运行 `nvvp` 即可。

## Intel VTune Profiler

Intel VTune Profiler 是分析程序热点的强大工具，它同时提供命令行与图形版本。在使用前，首先需要加载 Intel oneAPI 的相关组件。最简单的用法为 `vtune -collect hotspots ./my_prog --arguments`，在运行完成后即可在当前目录下生成 `r0xxhs` 这一结果目录。可以使用 `vtune` 来对结果进行进一步分析和呈现，也可以直接在 X11 转发启用的情况下（或者复制到本地），使用 `vtune-gui` 直接打开图形化结果并进行分析。

## Intel Advisor

Intel Advisor 是进行并行性能优化、性能建模的工具，它也同时提供命令行与图形版本，并需要加载后使用。由于本课程中不涉及到性能模型的相关要求，故不加以详细介绍。有兴趣的同学可以自行查阅使用方法。
