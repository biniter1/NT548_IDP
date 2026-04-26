# ${{ values.serviceName }} — ${{ values.language }}
{% if values.language === "go" %}
FROM golang:1.21-alpine AS builder
WORKDIR /app
COPY . .
RUN go build -o server .

FROM alpine:latest
WORKDIR /app
COPY --from=builder /app/server .
EXPOSE 8080
CMD ["./server"]
{% elif values.language === "python" %}
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
EXPOSE 8080
CMD ["python", "main.py"]
{% elif values.language === "nodejs" %}
FROM node:20-slim
WORKDIR /app
COPY package*.json .
RUN npm ci --production
COPY . .
EXPOSE 8080
CMD ["node", "index.js"]
{% endif %}