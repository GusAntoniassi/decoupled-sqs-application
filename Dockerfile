FROM python:3.9.0a3-alpine3.10

LABEL maintainer="Gus Antoniassi"
LABEL repo="github.com/GusAntoniassi/decoupled-sqs-application"

ENV PATH=$PATH:/root/.local/bin

COPY . /app
WORKDIR /app

RUN \
    apk add bash jq git zip \
    && pip install awscli --upgrade --user \
    && chmod +x *.sh && chmod +x **/*.sh

CMD [ "/app/deploy-stack.sh" ]