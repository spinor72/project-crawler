FROM python:3.6.0-alpine

WORKDIR /app
COPY ./requirements.txt /app
RUN apk add --no-cache && pip install -r /app/requirements.txt
COPY . /app
WORKDIR /app/ui

ENV FLASK_APP ui.py
CMD gunicorn ui:app -b 0.0.0.0
