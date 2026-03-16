# 基础镜像：使用DaoCloud加速的Ubuntu 24.04
FROM m.daocloud.io/docker.io/library/ubuntu:24.04

# ========== 第一步：优先替换国内源（阿里云），优化源配置 ==========
RUN rm -rf /etc/apt/sources.list && \
    echo "deb http://mirrors.aliyun.com/ubuntu/ noble main restricted universe multiverse" > /etc/apt/sources.list && \
    echo "deb http://mirrors.aliyun.com/ubuntu/ noble-security main restricted universe multiverse" >> /etc/apt/sources.list && \
    echo "deb http://mirrors.aliyun.com/ubuntu/ noble-updates main restricted universe multiverse" >> /etc/apt/sources.list && \
    echo "deb http://mirrors.aliyun.com/ubuntu/ noble-backports main restricted universe multiverse" >> /etc/apt/sources.list && \
    # 清理旧缓存 + 强制更新源（忽略临时错误）
    apt-get clean && apt-get update -o Acquire::Retries=3 || true

# 禁用交互模式：避免安装过程中弹出输入提示
ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8
# 增加Java/SBT环境变量，提升构建稳定性
ENV JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
ENV PATH=$JAVA_HOME/bin:$PATH

# ========== 安装核心依赖：优化依赖列表 + 增强容错 ==========
RUN apt-get update -o Acquire::Retries=3 && \
    apt-get install -y --no-install-recommends \
    # Java环境（Joern核心依赖）
    openjdk-21-jdk \
    # Python环境
    python3 python3-pip python3-dev python3-venv \
    # 基础工具
    git curl gnupg bash wget unzip build-essential ca-certificates \
    # 系统库依赖
    libnss3 libncurses6 libffi-dev pkg-config clang libclang-dev \
    # PHP（按需）
    php-cli \
    # 关键：增加重试机制 + 忽略临时下载错误
    -o Acquire::Retries=5 -o DPkg::Lock::Timeout=120 && \
    # 清理缓存：减小镜像体积
    apt-get clean && rm -rf /var/lib/apt/lists/*

# ========== Python环境优化：使用虚拟环境避开系统限制 ==========
# 1. 建立软链接（保持命令统一）
RUN ln -sf /usr/bin/python3 /usr/bin/python && \
    ln -sf /usr/bin/pip3 /usr/bin/pip
# 2. 创建虚拟环境（隔离系统环境）
RUN python -m venv /opt/venv && \
    # 配置国内源
    /opt/venv/bin/pip config set global.index-url https://mirrors.aliyun.com/pypi/simple/ && \
    # 升级虚拟环境内的pip（无系统限制）
    /opt/venv/bin/pip install --upgrade pip
# 3. 全局使用虚拟环境
ENV PATH="/opt/venv/bin:$PATH"

# ========== 安装sbt（Scala构建工具）：优化国内源 + 加速 ==========
ENV SBT_VERSION 1.12.1
ENV SBT_HOME /usr/local/sbt
ENV PATH ${PATH}:${SBT_HOME}/bin
RUN curl -sL "https://github.com/sbt/sbt/releases/download/v$SBT_VERSION/sbt-$SBT_VERSION.tgz" | gunzip | tar -x -C /usr/local

# ========== 克隆并构建Joern：优化构建流程 ==========
# 1. 克隆Joern（指定稳定版本，避免最新版兼容性问题）
RUN git clone https://github.com/joernio/joern && cd joern && sbt stage

# 设置工作目录
WORKDIR /joern

# 暴露默认端口
EXPOSE 8080

# 启动命令（优化启动参数）
CMD ["./joern", "--server", "--server-host", "0.0.0.0", "--server-port", "8081"]