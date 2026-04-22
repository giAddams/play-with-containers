#!/bin/bash
set -e

# RabbitMQ on Debian needs some folder permissions set at runtime
mkdir -p /var/lib/rabbitmq /var/log/rabbitmq
chown -R rabbitmq:rabbitmq /var/lib/rabbitmq /var/log/rabbitmq

RABBIT_USER=${RABBITMQ_DEFAULT_USER:-guest}
RABBIT_PASS=${RABBITMQ_DEFAULT_PASS:-guest}

echo "Bootstrapping RabbitMQ credentials..."
rabbitmq-server -detached
rabbitmqctl await_startup

if rabbitmqctl list_users | awk '{print $1}' | grep -qx "$RABBIT_USER"; then
	rabbitmqctl change_password "$RABBIT_USER" "$RABBIT_PASS"
else
	rabbitmqctl add_user "$RABBIT_USER" "$RABBIT_PASS"
fi

rabbitmqctl set_user_tags "$RABBIT_USER" administrator
rabbitmqctl set_permissions -p / "$RABBIT_USER" ".*" ".*" ".*"

if [ "$RABBIT_USER" != "guest" ] && rabbitmqctl list_users | awk '{print $1}' | grep -qx guest; then
	rabbitmqctl delete_user guest || true
fi

rabbitmqctl stop

echo "Starting RabbitMQ Server..."
exec rabbitmq-server
