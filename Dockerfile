FROM python:3.8-alpine3.14

LABEL org.opencontainers.image.authors="kirill@iliashenko.com"

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app
COPY requirements.txt /app
RUN apk add --no-cache openldap-dev gcc musl-dev && rm -rf /var/cache/apk/* \
&& python -m pip --no-cache-dir install -r requirements.txt && apk del gcc musl-dev
COPY . /app
# Uncomment this if your zabbix server uses certificate from internal CA and add mentioned files to the working directory
# or use "-n, --no-check-certificate" in CMD
RUN cat ca.pem >> /usr/local/lib/python3.8/site-packages/certifi/cacert.pem \
&& cat ca.crt >> /etc/ssl/certs/ca-certificates.crt
RUN adduser -u 1001 --disabled-password appuser && chown -R appuser /app
USER appuser

CMD [ "-srda", "-f", "/app/zabbix-ldap.conf" ]
ENTRYPOINT [ "/app/zabbix-ldap-sync" ]
