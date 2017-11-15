variable "key_name" {
  description = "Name of the SSH keypair to use in AWS."
  default = "ansible_key"
}

variable "server_port" {
  description = "The port the server will use for HTTP requests"
  default = 80
}