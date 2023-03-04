FROM archlinux:latest as builder
RUN pacman -Syyu --noconfirm \
    && pacman -S --noconfirm base-devel \
    && pacman -S --noconfirm python python-pip \
    && pip install --upgrade pip \
    && pip install conan \
    && pacman -S --noconfirm cmake ninja cuda \
    && rm -rf /var/cache/pacman/pkg/* \
    && rm -rf `pip cache dir`

FROM builder as conan_installer
WORKDIR /app/conan
COPY conanfile.txt .
RUN conan profile detect
RUN conan install . -s build_type=Release --build=missing
WORKDIR /app
RUN /bin/bash

FROM conan_installer as build
COPY --from=conan_installer  /root/.conan2 /root
RUN pacman -S --noconfirm qt6-base qt6-webengine \
    && rm -rf /var/cache/pacman/pkg/*
WORKDIR /app