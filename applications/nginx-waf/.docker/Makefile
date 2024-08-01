nginx-waf-with-modsecurity: Dockerfile
	DOCKER_BUILDKIT=1 docker build --tag nginx-modsecurity .
	DOCKER_BUILDKIT=1 docker create --name nginx-vol nginx-modsecurity
	DOCKER_BUILDKIT=1 docker cp nginx-vol:/ngx_http_modsecurity_module.so ../modules
	DOCKER_BUILDKIT=1 docker rm -f nginx-vol
	DOCKER_BUILDKIT=1 docker rmi -f nginx-modsecurity
