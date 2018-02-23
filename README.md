# HA Proxy
Image developed to create automatic load balancing and reverse proxy using HAProxy and docker-gen. Idea got from [nginx-proxy by jwilder](https://github.com/jwilder/nginx-proxy).

#### Usage

To run it only with HTTP method:
```console
git clone https://github.com/RiadVargas/haproxy-auto.git
cd haproxy-auto
docker build -t riadvargas/haproxy-auto .
docker run -d -p 80:80 -v /var/run/docker.sock:/tmp/docker.sock:ro riadvargas/haproxy-auto
```

And if you want to run with HTTP and HTTPS:
```console
docker run -d -p 80:80 -p 443:443 -v PATH:/etc/haproxy/certs -v /var/run/docker.sock:/tmp/docker.sock:ro riadvargas/haproxy-auto
```

Then start any containers you want be proxied with an env var called `VIRTUAL_HOST`:
```console
docker run -e VIRTUAL_HOST=foo.bar.com  ...
```

Or if you to enable SSL for this domain use:
```console
docker run -e VIRTUAL_HOST=foo.bar.com  -e SSL_FILE=filename ...
```
Remember to use a bundled certificate. It presumes the certificate extension is `pem`.


#### TODO
- Support Swarm endpoint

Please create an issue if you want something else.
