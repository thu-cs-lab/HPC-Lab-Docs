# HPC-Lab Documentation

![Build documentation with mkdocs](https://github.com/thu-cs-lab/HPC-Lab-Docs/workflows/Build%20documentation%20with%20mkdocs/badge.svg)

本项目为高性能计算导论课程的实验文档，采用 `mkdocs` 编写。

本站点的自动编译版本在 [这里](https://lab.cs.tsinghua.edu.cn/hpc/doc/) 发布。

## 撰写

本站点内容使用 Markdown 进行编写。具体可查看 [mkdocs](https://www.mkdocs.org/) 和 [mkdocs-material](https://squidfunk.github.io/mkdocs-material/extensions/pymdown/) 文档。

如果创建了新页面，需要插入到 `mkdocs.yml` 的 `nav` 部分，否则将不会出现在编译结果中。

## 编译

首先安装依赖，而后编译即可：

```bash
python3 -m pip install --user -r requirements.txt # 安装 Python 依赖包
mkdocs serve # 直接在本地 serve，或者：
mkdocs build --clean # 生成于 site/ 文件夹中
```

## 生成离线版

生成 PDF 和 DOCX 版本需要（经过修改的） [`mkdocs-combine`](https://github.com/Harry-Chen/mkdocs-combine) 插件的支持。首先安装插件：

```bash
pip3 install git+https://github.com/Harry-Chen/mkdocs-combine.git
```

而后运行：

```bash
make docx
make pdf
```

即可在 `generated` 目录下获得相应格式的文件。
