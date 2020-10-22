output "Consul_UI" {
  value = "http://${aws_instance.consul.public_ip}:8500"
}

output "Consul_Server_IP" {
  value = "${aws_instance.consul.public_ip}"
}

output "NGINX_LB_IP" {
  value = "${aws_instance.nginx-server.public_ip}"
}