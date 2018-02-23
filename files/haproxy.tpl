{{ $CurrentContainer := where $ "ID" .Docker.CurrentContainerID | first }}

# Global settings
global
log         127.0.0.1 local2

chroot      /var/lib/haproxy
pidfile     /var/run/haproxy.pid
maxconn     10000
user        haproxy
group       haproxy
daemon

# Avoiding problems with SSL
tune.ssl.default-dh-param 2048
ssl-default-bind-ciphers ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA:ECDHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA256:DHE-RSA-AES256-SHA:ECDHE-ECDSA-DES-CBC3-SHA:ECDHE-RSA-DES-CBC3-SHA:EDH-RSA-DES-CBC3-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:DES-CBC3-SHA:!DSS
ssl-default-bind-options no-sslv3 no-tls-tickets
ssl-default-server-ciphers ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA:ECDHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA256:DHE-RSA-AES256-SHA:ECDHE-ECDSA-DES-CBC3-SHA:ECDHE-RSA-DES-CBC3-SHA:EDH-RSA-DES-CBC3-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:DES-CBC3-SHA:!DSS
ssl-default-server-options no-sslv3 no-tls-tickets

stats socket /var/lib/haproxy/stats

# Default settings
defaults
  log     global
  mode    http
  option  httplog
  option  dontlognull
  timeout connect 120000ms
  timeout client 120000ms
  timeout server 120000ms

{{ define "backend" }}
{{ if .Address }}
	{{/* If we got the containers from swarm and this container's port is published to host, use host IP:PORT */}}
	{{ if and .Container.Node.ID .Address.HostPort }}
  # {{ .Container.Node.Name }}/{{ .Container.Name }}
  server {{ .Container.Name }} {{ .Container.Node.Address.IP }}:{{ .Address.HostPort }} check inter 5s fall 3 rise 2
	{{/* If there is no swarm node or the port is not published on host, use container's IP:PORT */}}
	{{ else if .Network }}
  # {{ .Container.Name }}
  server {{ .Container.Name }} {{ .Network.IP }}:{{ .Address.Port }} check inter 5s fall 3 rise 2
	{{ end }}
{{ end }}
{{ end }}

# Frontend for HTTP (port: 80)
frontend http_in
  bind *:80
  mode http
  option forwardfor
  option http-server-close
  reqadd X-Forwarded-Proto:\ http

{{ range $host, $containers := groupByMulti $ "Env.VIRTUAL_HOST" "," }}
  {{ if (first (groupByKeys $containers "Env.WWW")) }}
  redirect prefix http://www.{{ $host }} code 301 if { hdr(host) -i {{ $host }}
  {{ end }}
  {{ if (first (groupByKeys $containers "Env.WWW_BOTH")) }}
  acl www.{{ $host }} hdr(host) -i www.{{ $host }}
  {{ end }}
  acl {{ $host }} hdr(host) -i {{ $host }}
{{ end }}

{{ range $host, $containers := groupByMulti $ "Env.VIRTUAL_HOST" "," }}
  {{ if (first (groupByKeys $containers "Env.WWW_BOTH")) }}
  use_backend {{ $host }} if www.{{ $host }}
  {{ end }}
  use_backend {{ $host }} if {{ $host }}
{{ end }}

# Frontend for HTTPS (port: 443)
{{ if (groupByKeys $containers "Env.SSL_FILE") }}
frontend https_in
  bind *:443 ssl{{ range $ssl, $containers := groupByMulti $ "Env.SSL_FILE" "," }} crt /etc/haproxy/certs/{{ $ssl }}.pem{{ end }}
  mode http
  option forwardfor
  option http-server-close
  reqadd X-Forwarded-Proto:\ https

  {{ range $host, $containers := groupByMulti $ "Env.VIRTUAL_HOST" "," }}
   {{ if (first (groupByKeys $containers "Env.SSL_FILE"))}}
   acl {{ $host }} hdr(host) -i {{ $host }}
   {{ end }}
  {{ end }}

  {{ range $host, $containers := groupByMulti $ "Env.VIRTUAL_HOST" "," }}
   {{ if (first (groupByKeys $containers "Env.SSL_FILE"))}}
   use_backend {{ $host }} if {{ $host }}
   {{ end }}
  {{ end }}
{{ end }}

{{ range $host, $containers := groupByMulti $ "Env.VIRTUAL_HOST" "," }}

# Backend for {{ $host }}
backend {{ $host }}
  mode http
  balance roundrobin
  option http-server-close
  option forwardfor
  option httpchk GET /
  {{ if (first (groupByKeys $containers "Env.SSL_FILE"))}}
    redirect scheme https if !{ ssl_fc }
  {{ end }}
{{ range $container := $containers }}
	{{ $addrLen := len $container.Addresses }}

{{ range $knownNetwork := $CurrentContainer.Networks }}
{{ range $containerNetwork := $container.Networks }}
{{ if eq $knownNetwork.Name $containerNetwork.Name }}
	{{/* If only 1 port exposed, use that */}}
	{{ if eq $addrLen 1 }}
	{{ $address := index $container.Addresses 0 }}
	{{ template "backend" (dict "Container" $container "Address" $address "Network" $containerNetwork) }}
	{{/* If more than one port exposed, use the one matching VIRTUAL_PORT env var, falling back to standard web port 80 */}}
	{{ else }}
	{{ $port := coalesce $container.Env.VIRTUAL_PORT "80" }}
	{{ $address := where $container.Addresses "Port" $port | first }}
	{{ template "backend" (dict "Container" $container "Address" $address "Network" $containerNetwork) }}
	{{ end }}
	{{ end }}
	{{ end }}
{{ end }}
{{ end }}
{{ end }}
