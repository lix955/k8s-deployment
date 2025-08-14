FROM alpine:latest

RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories && \
    apk update && apk add --no-cache python3 py3-pip

RUN ln -sf python3 /usr/bin/python && \
    ln -sf pip3 /usr/bin/pip

RUN python --version && pip --version

WORKDIR /app

COPY . .

CMD ["python", "your_script.py"]
