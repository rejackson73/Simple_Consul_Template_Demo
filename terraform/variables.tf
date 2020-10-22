variable "prefix" {
  description = "prefix for resources created"
}
variable "region" {
  description = "AWS region"
  default     = "us-east-1"
}

variable "allow_from" {
  description = "IP Address/Network to allow traffic from (i.e. 192.0.2.11/32)"
  type	      = string
}