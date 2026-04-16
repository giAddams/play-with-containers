#!/bin/bash
set -e

# RabbitMQ on Debian needs some folder permissions set at runtime
mkdir -p /var/lib/rabbitmq /var/log/rabbitmq
chown -R rabbitmq:rabbitmq /var/lib/rabbitmq /var/log/rabbitmq

echo "Starting RabbitMQ Server..."

# Start RabbitMQ in the foreground
exec rabbitmq-server
