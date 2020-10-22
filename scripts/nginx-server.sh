#!/bin/bash

#Get IP
local_ipv4="$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)"

#Utils
sudo apt-get install unzip

#Download Consul
CONSUL_VERSION="1.9.0-beta1"
curl --silent --remote-name https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_amd64.zip

#Install Consul
unzip consul_${CONSUL_VERSION}_linux_amd64.zip
sudo chown root:root consul
sudo mv consul /usr/local/bin/
consul -autocomplete-install
complete -C /usr/local/bin/consul consul

#Create Consul User
sudo useradd --system --home /etc/consul.d --shell /bin/false consul
sudo mkdir --parents /opt/consul
sudo chown --recursive consul:consul /opt/consul

#Create Systemd Config
sudo cat << EOF > /etc/systemd/system/consul.service
[Unit]
Description="HashiCorp Consul - A service mesh solution"
Documentation=https://www.consul.io/
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=/etc/consul.d/consul.hcl

[Service]
User=consul
Group=consul
ExecStart=/usr/local/bin/consul agent -config-dir=/etc/consul.d/
ExecReload=/usr/local/bin/consul reload
KillMode=process
Restart=always
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

#Create config dir
sudo mkdir --parents /etc/consul.d
sudo touch /etc/consul.d/consul.hcl
sudo chown --recursive consul:consul /etc/consul.d
sudo chmod 640 /etc/consul.d/consul.hcl

cat << EOF > /etc/consul.d/consul.hcl
datacenter = "dc1"
data_dir = "/opt/consul"
ui = true
disable_remote_exec = false
EOF

cat << EOF > /etc/consul.d/client.hcl
advertise_addr = "${local_ipv4}"
retry_join = ["provider=aws tag_key=Env tag_value=consul"]
EOF

cat << EOF > /etc/consul.d/nginx.json
{
  "service": {
    "name": "nginx-server",
    "port": 80,
    "checks": [
      {
        "id": "nginx-server",
        "name": "nginx TCP Check",
        "tcp": "localhost:80",
        "interval": "10s",
        "timeout": "1s"
      }
    ]
  }
}
EOF

#Install Consul Template
CONSUL_TEMPLATE_VERSION="0.25.1"
curl --silent --remote-name https://releases.hashicorp.com/consul-template/${CONSUL_TEMPLATE_VERSION}/consul-template_${CONSUL_TEMPLATE_VERSION}_linux_amd64.zip
unzip consul-template_${CONSUL_TEMPLATE_VERSION}_linux_amd64.zip
sudo chown root:root consul-template
sudo mv consul-template /usr/local/bin/

sudo mkdir --parents /etc/consul-template.d
cat << EOF > /etc/consul-template.d/consul-template-config.hcl
consul {
  address = ":8500"

  retry {
    enabled  = true
    attempts = 12
    backoff  = "250ms"
  }
}
template {
  source      = "/etc/nginx/conf.d/load-balancer.conf.ctmpl"
  destination = "/etc/nginx/conf.d/load-balancer.conf"
  perms       = 0600
  command     = "service nginx reload"
}
EOF

sudo chown --recursive consul:consul /etc/consul-template.d
sudo chmod 640 /etc/consul-template.d/consul-template-config.hcl

#Install nginx
echo "deb http://nginx.org/packages/ubuntu `lsb_release -cs` nginx"     | sudo tee /etc/apt/sources.list.d/nginx.list
curl -fsSL https://nginx.org/keys/nginx_signing.key | sudo apt-key add -
sudo apt update
sudo apt install nginx

sudo rm /etc/nginx/conf.d/default.conf

cat << EOF > /etc/nginx/conf.d/load-balancer.conf.ctmpl
upstream backend {
{{ range service "web" }}
  server {{ .Address }}:{{ .Port }};
{{ end }}
}

server {
   listen 80;

   location / {
      proxy_pass http://backend;
   }
}
EOF


#Enable the services
sudo systemctl enable consul
sudo service consul start
sudo service consul status
sudo systemctl enable nginx
sudo systemctl start nginx

# #Install Dockers
# sudo snap install docker
# sudo curl -L "https://github.com/docker/compose/releases/download/1.24.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
# sudo chmod +x /usr/local/bin/docker-compose

#Run  nginx
# sleep 10
# cat << EOF > docker-compose.yml
# version: "3.7"
# services:
#   web:
#     image: nginxdemos/hello
#     ports:
#     - "80:80"
#     restart: always
#     command: [nginx-debug, '-g', 'daemon off;']
#     network_mode: "host"
# EOF
# sudo docker-compose up -d
