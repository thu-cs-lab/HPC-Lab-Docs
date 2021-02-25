# 工具链使用

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

## Linux `perf` 命令

TODO

## Intel vTune Amplifier

TODO

## Intel Advisor

TODO
