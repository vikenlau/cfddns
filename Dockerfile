FROM alpine:latest

RUN apk update && apk add --no-cache \
    bash \
    curl \
    openssl \
    jq \
    dumb-init

ARG IP_PROVIDER="https://ipinfo.io/ip"
ENV IP_PROVIDER="${IP_PROVIDER}"

ARG AUTH_KEY="NOT_INITIALIZED"
ENV AUTH_KEY="${AUTH_KEY}"
ARG AUTH_EMAIL="NOT_INITIALIZED"
ENV AUTH_EMAIL="${AUTH_EMAIL}"
ARG DNS_FQDN="NOT_INITIALIZED"
ENV DNS_FQDN="${DNS_FQDN}"
ARG DNS_TYPE="A"
ENV DNS_TYPE="${DNS_TYPE}"

COPY cfddns.sh /usr/local/bin/

ENTRYPOINT ["/usr/bin/dumb-init", "bash"]

CMD ["/usr/local/bin/cfddns.sh"]
