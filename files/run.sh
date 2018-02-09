#!/bin/sh

rsyslogd
haproxy -D -f /etc/haproxy/haproxy.cfg -p /tmp/haproxy.pid
docker-gen -watch -notify 'reload-haproxy' /app/haproxy.tpl /etc/haproxy/haproxy.cfg
