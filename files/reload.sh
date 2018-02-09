#!/bin/sh

haproxy -f /etc/haproxy/haproxy.cfg -p /tmp/haproxy.pid -sf $(cat /tmp/haproxy.pid) 
