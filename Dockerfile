FROM alpine:latest

ARG HTTP_PROXY
ARG HTTPS_PROXY
ENV HTTP_PROXY=$HTTP_PROXY
ENV HTTPS_PROXY=$HTTPS_PROXY

RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories && \
    apk update && apk add --no-cache python3 py3-pip

ENV HTTP_PROXY=
ENV HTTPS_PROXY=

RUN ln -sf python3 /usr/bin/python && \
    ln -sf pip3 /usr/bin/pip

RUN python --version && pip --version

WORKDIR /app

COPY . .

CMD ["python", "your_script.py"]
