FROM python:3.6.0-alpine

WORKDIR /app
COPY ./requirements.txt /app
RUN apk add --no-cache && pip install -r /app/requirements.txt
COPY . /app
WORKDIR /app/crawler
ENV SITE_URL https://vitkhab.github.io/search_engine_test_site/

ENTRYPOINT python -u crawler.py "$SITE_URL"
