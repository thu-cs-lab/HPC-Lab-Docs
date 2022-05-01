# 进程绑定

由于 SLURM 支持自动的进程绑定，因此很多时候不需要指定 `--cpu-bind` 参数也能正确地工作。如果需要更精细的进程绑定，可以查阅 [此文档](https://slurm.schedmd.com/mc_support.html)。

在单独使用 OpenMP 时，推荐将每个线程绑定到单个 CPU 核心，且不允许线程在核心之间切换（使用 `OMP_PROC_BIND=close OMP_PLACES=cores` 环境变量），以获得最佳性能。关于 OpenMP 线程绑定的更详细说明，可见 [Thread affinity with OpenMP 4.0](https://www.hpc.kaust.edu.sa/tips/thread-affinity-openmp-40) 。

在混合使用 OpenMP 与 MPI 编程时，推荐选取 rank 数量与 NUMA 节点数量相同（实验集群上为每机 2 进程），每个 rank 的线程数量与单个 NUMA 节点物理核心数量相同（实验集群上为每进程 14 线程），并将每个线程绑定到对应的物理核心上。此时应该使用 `srun` 的 `--cpu-bind=socket` 选项，并向 OpenMP 传入环境变量 `OMP_PROC_BIND=true OMP_PLACES=cores`。