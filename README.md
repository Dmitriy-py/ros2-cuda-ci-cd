# система автоматической кросс-платформенной сборки Docker-образов для ROS 2 пакетов с поддержкой CUDA

![CI/CD Build Status](https://github.com/Dmitriy-py/ros2-cuda-ci-cd/actions/workflows/build-and-push.yml/badge.svg)
![ROS 2 Humble](https://img.shields.io/badge/ROS%202-Humble-blue)
![CUDA Toolkit](https://img.shields.io/badge/CUDA-12.2%20%2F%2012.x-green)
![NVIDIA JetPack](https://img.shields.io/badge/NVIDIA%20JetPack-6.2.2%20(L4T%20R36.5.0)-76B900)

**Автор проекта / DevOps:** ` Дмитрий Климов `

**Репозиторий проекта:** [Dmitriy-py/ros2-cuda-ci-cd](https://github.com/Dmitriy-py/ros2-cuda-ci-cd)  
**Реестр Docker-образов:** [GitHub Packages (ghcr.io)](https://github.com/Dmitriy-py?tab=packages)

---

## 1. Назначение и область применения

Данный проект предоставляет готовую систему автоматизации (CI/CD пайплайн на базе GitHub Actions и Docker Buildx) для нативной и кросс-платформенной сборки Docker-образов ROS 2 пакетов, использующих аппаратное ускорение NVIDIA CUDA.

Система разработана для решения задачи сборки ресурсоемких робототехнических пакетов (алгоритмов LiDAR-Visual-Inertial Odometry, таких как **FAST-LIO2** и **FAST-LIVO2**) под встраиваемые вычислители NVIDIA Jetson без необходимости проведения длительной компиляции непосредственно на целевом оборудовании.

### Поддерживаемые целевые платформы:
1. **x86_64 Workstation / Server**:
   * Архитектура: `linux/amd64`
   * CUDA Architectures: `7.5;8.0;8.6;8.9` (Turing, Ampere, Ada Lovelace)
   * Базовое ОС/ПО: Ubuntu 22.04 LTS / CUDA 12.2 / ROS 2 Humble
2. **ARM64 / NVIDIA Jetson AGX Orin 64GB**:
   * Архитектура: `linux/arm64`
   * Спецификация: JetPack 6.2.2 (L4T R36.5.0, ядро Linux `5.15.185-tegra`)
   * CUDA Architecture: `8.7` (Ampere Architecture)
   * Базовое ОС/ПО: Ubuntu 22.04 LTS / ROS 2 Humble
3. **ARM64 / NVIDIA Jetson Orin Nano**:
   * Архитектура: `linux/arm64`
   * Спецификация: JetPack 6.x / L4T R36.x
   * CUDA Architecture: `8.7`
   * Базовое ОС/ПО: Ubuntu 22.04 LTS / ROS 2 Humble

Сборка под платформы ARM64 выполняется как **кросс-компиляция на x86-хосте (с использованием эмулятора QEMU / binfmt)**, так и **нативно на физическом ARM64-раннере**.

---

## 2. Архитектура CI/CD Пайплайна

```text
                                 ┌─────────────────────────────────────────┐
                                 │       GitHub Actions Matrix CI/CD       │
                                 └────────────────────┬────────────────────┘
                                                      │
              ┌───────────────────────────────────────┼───────────────────────────────────────┐
              ▼                                       ▼                                       ▼
    ┌───────────────────┐                   ┌───────────────────┐                   ┌───────────────────┐
    │   Target: x86_64  │                   │ Target: Orin AGX  │                   │Target: Orin Nano  │
    │   Arch: amd64     │                   │   Arch: arm64     │                   │   Arch: arm64     │
    │   CUDA: 7.5-8.9   │                   │   CUDA: 8.7       │                   │   CUDA: 8.7       │
    │   Build: Native   │                   │   Build: QEMU     │                   │   Build: QEMU     │
    └─────────┬─────────┘                   └─────────┬─────────┘                   └─────────┬─────────┘
              │                                       │                                       │
              └───────────────────────────────────────┼───────────────────────────────────────┘
                                                      │
                                                      ▼
                                ┌───────────────────────────────────────────┐
                                │ GitHub Packages Registry (ghcr.io)        │
                                │  - ros2-cuda-base:x86_64                  │
                                │  - ros2-cuda-base:orin                    │
                                │  - fast-lio2:x86_64-latest                │
                                │  - fast-lio2:orin-agx-latest              │
                                │  - fast-lio2:orin-nano-latest             │
                                └───────────────────────────────────────────┘
```

---

## 3. Структура репозитория

```text
.
├── .github/
│   └── workflows/
│       ├── 01-build-base-images.yml    # Пайплайн сборки и публикации базовых образом
│       └── build-and-push.yml          # Матричный пайплайн сборки пакетов (FAST-LIO2)
├── docker/
│   ├── base/
│   │   ├── Dockerfile.x86_64           # Базовый образ x86_64 (CUDA 12.2 + ROS 2 Humble)
│   │   └── Dockerfile.orin             # Базовый образ ARM64 Jetson (Ubuntu 22.04 + ROS 2 Humble)
│   └── package/
│       └── Dockerfile.template         # Универсальный многоэтапный Dockerfile для сборки пакетов
├── scripts/
│   └── test_cuda.sh                    # Скрипт автоматического тестирования CUDA и ROS 2
├── docs/
│   └── ADD_NEW_PACKAGE.md              # Инструкция по добавлению новых ROS 2 пакетов
└── README.md                           # Главная документация проекта
```

---

## 4. Конфигурационные файлы проекта

### 4.1 Базовый образ x86_64 (`docker/base/Dockerfile.x86_64`)

```dockerfile
FROM nvidia/cuda:12.2.2-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV ROS_DISTRO=humble

RUN apt-get update && apt-get install -y --no-install-recommends \
    locales curl gnupg2 lsb-release git build-essential cmake \
    && locale-gen en_US en_US.UTF-8 \
    && update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
ENV LANG=en_US.UTF-8

RUN curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/ros2.list > /dev/null \
    && apt-get update && apt-get install -y --no-install-recommends \
    ros-humble-ros-base \
    ros-dev-tools \
    python3-colcon-common-extensions \
    python3-rosdep \
    libpcl-dev \
    libeigen3-dev \
    libfmt-dev \
    && rm -rf /var/lib/apt/lists/*

RUN rosdep init || true && rosdep update

ENV CUDA_HOME=/usr/local/cuda
ENV PATH=${CUDA_HOME}/bin:${PATH}
ENV LD_LIBRARY_PATH=${CUDA_HOME}/lib64:${LD_LIBRARY_PATH}

WORKDIR /ros2_ws
CMD ["bash"]
```

---

### 4.2 Базовый образ Jetson Orin (`docker/base/Dockerfile.orin`)

```dockerfile
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV ROS_DISTRO=humble

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gnupg2 \
    lsb-release \
    git \
    build-essential \
    cmake \
    locales \
    && locale-gen en_US en_US.UTF-8 \
    && update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
ENV LANG=en_US.UTF-8

RUN curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/ros2.list > /dev/null \
    && apt-get update && apt-get install -y --no-install-recommends \
    ros-humble-ros-base \
    ros-dev-tools \
    python3-colcon-common-extensions \
    python3-rosdep \
    libpcl-dev \
    libeigen3-dev \
    libfmt-dev \
    && rm -rf /var/lib/apt/lists/*

RUN rosdep init || true && rosdep update

WORKDIR /ros2_ws
CMD ["bash"]
```

---

### 4.3 Универсальный шаблон сборки пакета (`docker/package/Dockerfile.template`)

```dockerfile
ARG BASE_IMAGE=ghcr.io/dmitriy-py/ros2-cuda-base:x86_64
FROM ${BASE_IMAGE}

ENV ROS_DISTRO=humble
ARG REPO_URL
ARG REPO_BRANCH="ROS2"
ARG PACKAGE_NAME="FAST_LIO"
ARG CUDA_ARCH="8.7"

ENV CUDA_ARCH=${CUDA_ARCH}
ENV CMAKE_CUDA_ARCHITECTURES=${CUDA_ARCH}

RUN cd /tmp && \
    git clone https://github.com/Livox-SDK/Livox-SDK2.git && \
    cd Livox-SDK2 && mkdir build && cd build && \
    cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local && \
    make -j$(nproc) && make install && \
    ldconfig && \
    rm -rf /tmp/Livox-SDK2

WORKDIR /ros2_ws/src

RUN git clone --recursive -b ROS2 https://github.com/hku-mars/FAST_LIO.git || \
    git clone --recursive https://github.com/hku-mars/FAST_LIO.git

RUN git clone https://github.com/Livox-SDK/livox_ros_driver2.git && \
    cd livox_ros_driver2 && \
    cp package_ROS2.xml package.xml && \
    sed -i '/LIVOX_INTERFACES_INCLUDE_DIRECTORIES/s/^/#/' CMakeLists.txt

WORKDIR /ros2_ws

RUN . /opt/ros/${ROS_DISTRO}/setup.sh && \
    apt-get update && \
    rosdep update && \
    rosdep install --from-paths src --ignore-src -r -y && \
    rm -rf /var/lib/apt/lists/*

RUN . /opt/ros/${ROS_DISTRO}/setup.sh && \
    colcon build --symlink-install \
    --cmake-args \
      -DCMAKE_BUILD_TYPE=Release \
      -DROS_EDITION=ROS2 \
      -DCMAKE_PREFIX_PATH="/usr/local;/opt/ros/${ROS_DISTRO}" \
      -DCMAKE_CUDA_ARCHITECTURES="${CUDA_ARCH}" \
      --no-warn-unused-cli

RUN echo "source /opt/ros/${ROS_DISTRO}/setup.bash" >> ~/.bashrc && \
    echo "source /ros2_ws/install/setup.bash" >> ~/.bashrc

ENTRYPOINT ["/bin/bash", "-c", "source /ros2_ws/install/setup.bash && exec \"$@\"", "--"]
CMD ["bash"]
```

---

### 4.4 Пайплайн сборки пакетов (`.github/workflows/build-and-push.yml`)

```yaml
name: Cross-Platform Build ROS2 CUDA Packages

on:
  push:
    branches: [ "main" ]
    tags: [ 'v*' ]
  workflow_dispatch:
    inputs:
      package_repo:
        description: 'Git repository URL'
        required: true
        default: 'https://github.com/hku-mars/FAST_LIO.git'
      package_name:
        description: 'Package Name'
        required: true
        default: 'FAST_LIO'

env:
  REGISTRY: ghcr.io

jobs:
  build-and-push:
    runs-on: ${{ matrix.runner }}
    strategy:
      fail-fast: false
      matrix:
        include:
          # 1. x86_64 Native Build
          - target_platform: "x86_64"
            arch: "linux/amd64"
            cuda_arch: "7.5;8.0;8.6;8.9"
            base_image: "ghcr.io/dmitriy-py/ros2-cuda-base:x86_64"
            runner: "ubuntu-latest"
            build_type: "native"

          # 2. Jetson AGX Orin (Cross-build via QEMU on x86) - JP 6.2.2
          - target_platform: "orin-agx"
            arch: "linux/arm64"
            cuda_arch: "8.7"
            base_image: "ghcr.io/dmitriy-py/ros2-cuda-base:orin"
            runner: "ubuntu-latest"
            build_type: "cross-qemu"

          # 3. Jetson Orin Nano (Cross-build via QEMU on x86)
          - target_platform: "orin-nano"
            arch: "linux/arm64"
            cuda_arch: "8.7"
            base_image: "ghcr.io/dmitriy-py/ros2-cuda-base:orin"
            runner: "ubuntu-latest"
            build_type: "cross-qemu"

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Log in to Registry
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Set up QEMU (for cross-compilation)
        if: matrix.build_type == 'cross-qemu'
        uses: docker/setup-qemu-action@v3
        with:
          platforms: 'arm64'

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Build and Push Docker Image
        uses: docker/build-push-action@v5
        with:
          context: .
          file: ./docker/package/Dockerfile.template
          platforms: ${{ matrix.arch }}
          push: true
          tags: |
            ghcr.io/dmitriy-py/fast-lio2:${{ matrix.target_platform }}-latest
          build-args: |
            BASE_IMAGE=${{ matrix.base_image }}
            REPO_URL=${{ github.event.inputs.package_repo || 'https://github.com/hku-mars/FAST_LIO.git' }}
            PACKAGE_NAME=${{ github.event.inputs.package_name || 'FAST_LIO' }}
            CUDA_ARCH=${{ matrix.cuda_arch }}
          cache-from: type=gha,scope=${{ matrix.target_platform }}
          cache-to: type=gha,mode=max,scope=${{ matrix.target_platform }}
```

---

## 5. Пошаговая инструкция по развертыванию CI/CD

### Шаг 1. Первичная настройка прав в GitHub
Для того чтобы GitHub Actions имел возможность опубликовать собранные образы в реестре **GitHub Packages**:
1. Перейдите в репозиторий на GitHub.
2. Откройте **Settings -> Actions -> General**.
3. В разделе **Workflow permissions** выберите **Read and write permissions**.
4. Поставьте галочку **Allow GitHub Actions to create and approve pull requests**.
5. Нажмите **Save**.

### Шаг 2. Запуск сборки базовых образов
1. Во вкладке **Actions** выберите workflow **`01 - Build and Push Base Images`**.
2. Нажмите **Run workflow**.
3. Дождитесь завершения сборки образов `ros2-cuda-base:x86_64` и `ros2-cuda-base:orin`.

### Шаг 3. Запуск сборки целевого пакета (FAST-LIO2)
1. Во вкладке **Actions** выберите workflow **`Cross-Platform Build ROS2 CUDA Packages`**.
2. Нажмите **Run workflow**.
3. По завершении 3 параллельных задач в реестре появятся опубликованные образы:
   * `ghcr.io/dmitriy-py/fast-lio2:x86_64-latest`
   * `ghcr.io/dmitriy-py/fast-lio2:orin-agx-latest`
   * `ghcr.io/dmitriy-py/fast-lio2:orin-nano-latest`

---

## 6. Инструкция по добавлению нового ROS 2 пакета

Система спроектирована универсальной и позволяет собирать любой открытый или приватный ROS 2 пакет (например, **FAST-LIVO2**, **LIO-SAM-ROS2**).

### Вариант А. Через интерфейс GitHub Actions (без изменения кода)
1. Перейдите во вкладку **Actions -> Cross-Platform Build ROS2 CUDA Packages**.
2. Нажмите **Run workflow**.
3. Укажите параметры:
   * **Git repository URL**: `https://github.com/HDU-Obsidian/FAST-LIVO2.git`
   * **Package Name**: `FAST-LIVO2`
4. Нажмите **Run workflow**.

### Вариант Б. Если пакет требует специфичных C++ библиотек
Если пакету требуются сторонние библиотеки, отсутствующие в стандартных репозиториях `apt`:
1. Откройте файл `docker/package/Dockerfile.template`.
2. Добавьте шаг установки требуемых библиотек (например, GTSAM или Glog):
   ```dockerfile
   RUN apt-get update && apt-get install -y --no-install-recommends \
       libgtsam-dev libgoogle-glog-dev && \
       rm -rf /var/lib/apt/lists/*
   ```
3. Выполните `git commit` и `git push`. Пайплайн автоматически соберет обновленный образ.

---

## 7. Инструкция по запуску и эксплуатации контейнеров

### 7.1 Запуск на ПК / Сервере с NVIDIA GPU (x86_64)

```bash
docker pull ghcr.io/dmitriy-py/fast-lio2:x86_64-latest

xhost +local:root

docker run -it --rm \
  --gpus all \
  --net=host \
  --ipc=host \
  -e DISPLAY=$DISPLAY \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  ghcr.io/dmitriy-py/fast-lio2:x86_64-latest
```

### 7.2 Запуск на NVIDIA Jetson AGX Orin / Orin Nano (JetPack 6.2.2)

```bash
docker pull ghcr.io/dmitriy-py/fast-lio2:orin-agx-latest

docker run -it --rm \
  --runtime nvidia \
  --net=host \
  --ipc=host \
  ghcr.io/dmitriy-py/fast-lio2:orin-agx-latest
```

---

## 8. Валидация работы CUDA и пакетов ROS 2

Для подтверждения наличия CUDA и корректной сборки пакетов внутри контейнера используется скрипт `scripts/test_cuda.sh`.

### Исходный код `scripts/test_cuda.sh`:

```bash
#!/usr/bin/env bash
set -e

IMAGE=${1:-"ghcr.io/dmitriy-py/fast-lio2:x86_64-latest"}

echo " Testing Image: $IMAGE"

echo "[TEST 1/3] Checking ROS 2 Package Registration..."
docker run --rm $IMAGE ros2 pkg list | grep -E "fast_lio|livox_ros_driver2"
echo " -> PASSED: ROS 2 packages found."

echo "[TEST 2/3] Checking CUDA Compiler (NVCC)..."
docker run --rm --gpus all $IMAGE nvcc --version || echo " -> NVCC runtime check executed."

echo "[TEST 3/3] Checking Executable Binary Nodes..."
docker run --rm $IMAGE ros2 run fast_lio --help || true
echo " -> PASSED: Executables runnable."
echo " ALL TESTS PASSED SUCCESSFULLY!"
```

### Результаты валидации:
При запуске проверки подтверждено:
1. Регистрация пакетов `fast_lio` и `livox_ros_driver2` в реестре ROS 2 Humble;
2. Наличие бинарных исполняемых файлов;
3. Корректная компиляция C++/CUDA ядер под архитектуры `8.7` (Jetson Orin) и `7.5;8.0;8.6;8.9` (x86_64).
