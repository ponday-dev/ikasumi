FROM elixir:1.6.6-slim

ENV APP_DIR /app

RUN mkdir /app
WORKDIR /app

SHELL ["/bin/bash", "-lc"]

RUN yes | mix local.hex
RUN yes | mix archive.install https://github.com/phoenixframework/archives/raw/master/phx_new.ez
RUN mix local.rebar --force

RUN apt-get update -y && \
    apt-get upgrade -y && \
    apt-get install -y \
    curl \
    git \
    gnupg1 \
    gnupg2 \
    mysql-client \
    inotify-tools \
    wget

RUN wget https://packages.erlang-solutions.com/erlang-solutions_1.0_all.deb
RUN dpkg -i erlang-solutions_1.0_all.deb && \
    apt-get update && \
    apt-get install -y esl-erlang

RUN curl -sL https://deb.nodesource.com/setup_10.x | bash -
RUN apt-get install -y nodejs
