FROM cloudron/base:2.0.0@sha256:f9fea80513aa7c92fe2e7bf3978b54c8ac5222f47a9a32a7f8833edf0eb5a4f4 as base

EXPOSE 8000

WORKDIR /app/code/

RUN git clone https://github.com/DefectDojo/django-DefectDojo.git . \
    && git checkout 1.6.5

RUN \
  apt-get -y update && \
  apt-get -y install \
    apt-utils \
    dnsutils \
    default-mysql-client \
    postgresql-client \
    xmlsec1 \
    python3-dev \
    gcc \
    uwsgi-plugin-python3 \
    && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists && \
  true

RUN pip3 install setuptools wheel
RUN rm requirements.txt
COPY requirements.txt /app/code/
RUN pip3 wheel --wheel-dir=/tmp/wheels -r ./requirements.txt

WORKDIR /app/code
RUN \
  apt-get -y update && \
  # ugly fix to install postgresql-client without errors
  mkdir -p /usr/share/man/man1 /usr/share/man/man7 && \
  apt-get -y install --no-install-recommends \
    # libopenjp2-7 libjpeg62 libtiff5 are required by the pillow package
    libopenjp2-7 \
    libjpeg62 \
    libtiff5 \
    dnsutils \
    default-mysql-client \
    libmariadb3 \
    xmlsec1 \
    # only required for the dbshell (used by the initializer job)
    postgresql-client \
    && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists && \
  true
RUN pip3 install --no-cache-dir --upgrade pip
#COPY --from=build /tmp/wheels /tmp/wheels
COPY requirements.txt ./
RUN pip3 install \
	--no-cache-dir \
	--no-index \
  --find-links=/tmp/wheels \
  -r ./requirements.txt

# Legacy installs need the modified settings.py, do not remove!
RUN \
  cp dojo/settings/settings.dist.py dojo/settings/settings.py

RUN \
  mkdir dojo/migrations && \
  chmod g=u dojo/migrations && \
  chmod g=u /var/run && \
  true
USER root
RUN chmod -R 0777 /app
USER 1001
ENV \
  DD_ADMIN_USER=admin \
  DD_ADMIN_MAIL=admin@defectdojo.local \
  DD_ADMIN_PASSWORD='' \
  DD_ADMIN_FIRST_NAME=Administrator \
  DD_ADMIN_LAST_NAME=User \
  DD_ALLOWED_HOSTS="*" \
  DD_CELERY_BEAT_SCHEDULE_FILENAME="/run/celery-beat-schedule" \
  DD_CELERY_BROKER_SCHEME="amqp" \
  DD_CELERY_BROKER_USER="defectdojo" \
  DD_CELERY_BROKER_PASSWORD="defectdojo" \
  DD_CELERY_BROKER_HOST="rabbitmq" \
  DD_CELERY_BROKER_PORT="5672" \
  DD_CELERY_BROKER_PATH="//" \
  DD_CELERY_LOG_LEVEL="INFO" \
  DD_DATABASE_ENGINE="django.db.backends.mysql" \
  DD_DATABASE_HOST="mysql" \
  DD_DATABASE_NAME="defectdojo" \
  DD_DATABASE_PASSWORD="defectdojo" \
  DD_DATABASE_PORT="3306" \
  DD_DATABASE_USER="defectdojo" \
  DD_INITIALIZE=true \
  DD_UWSGI_MODE="socket" \
  DD_UWSGI_ENDPOINT="0.0.0.0:3031" \
  DD_DJANGO_ADMIN_ENABLED="True" \
  DD_TRACK_MIGRATIONS="True" \
  DD_DJANGO_METRICS_ENABLED="False"
ENTRYPOINT ["/entrypoint-uwsgi.sh"]
