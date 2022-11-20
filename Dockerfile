FROM nvidia/cuda:11.8.0-devel-ubuntu22.04
WORKDIR /app
RUN apt update && \
    apt upgrade -y && \
    apt install -y apt-utils

RUN apt install -y qt6-base-dev cmake clang-13
RUN apt install -y git
RUN apt install -y aria2 curl wget
RUN git clone https://github.com/pyenv/pyenv.git ~/.pyenv
ENV HOME="/root"
ENV PYENV_ROOT="${HOME}/.pyenv"
ENV PATH="${PYENV_ROOT}/shims:${PYENV_ROOT}/bin:${PATH}"
RUN apt install -y libreadline-dev libbz2-dev libssl-dev libsqlite3-dev lzma-dev
RUN pyenv install 3.11.0
RUN pyenv global 3.11.0
RUN pip install --upgrade pip
RUN pip install conan
#RUN echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.bashrc
#RUN echo 'command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.bashrc
#RUN echo 'eval "$(pyenv init -)"' >> ~/.bashrc
#RUN exec /bin/bash
#RUN source ~/.bashrc
#RUN echo $PYENV_ROOT
