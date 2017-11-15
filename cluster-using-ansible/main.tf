# ------------------------------------------------------------------------------
# CONFIGURE OUR AWS CONNECTION
# ------------------------------------------------------------------------------

provider "aws" {

  region = "us-east-1"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A VPC FOR OUR PRIVATE CLOUD
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_vpc" "example_vpc" {

  cidr_block       = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags {
    Name = "terraform-example-vpc"
  }
}

data "aws_availability_zones" "all" {}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A SUBNET TO HOST OUR WEB SERVER
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_subnet" "example_subnet" {

  vpc_id                  = "${aws_vpc.example_vpc.id}"
  cidr_block              = "10.0.0.0/24"
  map_public_ip_on_launch = true

  availability_zone = "us-east-1b"

  tags {
    Name = "terraform-example-subnet"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE INTERNET GATEWAY
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_internet_gateway" "example_gw" {

  vpc_id = "${aws_vpc.example_vpc.id}"

  tags {
    Name = "terraform-example-gateway"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE ROUTE TABLE
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_route_table" "example_route_table" {

  vpc_id = "${aws_vpc.example_vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.example_gw.id}"
  }

  tags {
    Name = "terraform-example-route-table"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A SUBNET TO HOST OUR WEB SERVER
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_route_table_association" "example_route_table_association" {

  subnet_id      = "${aws_subnet.example_subnet.id}"
  route_table_id = "${aws_route_table.example_route_table.id}"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE SECURITY GROUP THAT'S APPLIED TO EACH EC2 INSTANCE IN THE ASG
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_security_group" "example_security_group" {

  name = "terraform-example-elb"
  description = "Used in the terraform"
  vpc_id      = "${aws_vpc.example_vpc.id}"

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP access from anywhere
  ingress {
    from_port = "${var.server_port}"
    to_port = "${var.server_port}"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE SECURITY GROUP THAT'S APPLIED TO ELB
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_security_group" "example_elb_security_group" {

  name = "terraform-example-instance"

  vpc_id = "${aws_vpc.example_vpc.id}"

  # Inbound HTTP from anywhere
  ingress {
    from_port = "${var.server_port}"
    to_port = "${var.server_port}"
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  depends_on = ["aws_internet_gateway.example_gw"]
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE AN ELB TO ROUTE TRAFFIC ACROSS THE AUTO SCALING GROUP
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_elb" "example_elb" {

  name = "terraform-asg-example"

  subnets = ["${aws_subnet.example_subnet.id}"]
  security_groups = ["${aws_security_group.example_elb_security_group.id}"]

  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    timeout = 3
    interval = 30
    target = "HTTP:${var.server_port}/"
  }

  # This adds a listener for incoming HTTP requests.
  listener {
    lb_port = 80
    lb_protocol = "http"
    instance_port = "${var.server_port}"
    instance_protocol = "http"
  }

  instances                   = ["${aws_instance.web_1.id}","${aws_instance.web_2.id}"]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE AN EC2 INSTANCE
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_instance" "web_1" {

  instance_type = "t2.micro"
  ami = "ami-2d39803a"

  key_name = "${var.key_name}"

  # Our Security group to allow HTTP and SSH access
  vpc_security_group_ids = ["${aws_security_group.example_security_group.id}"]
  subnet_id              = "${aws_subnet.example_subnet.id}"
  associate_public_ip_address = true

  provisioner "local-exec" {
      command = "sleep 120; ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook --private-key ~/.aws/id_rsa -i '${aws_instance.web_1.public_ip},' -u ubuntu playbook/webplaybook.yml"}
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE AN EC2 INSTANCE
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_instance" "web_2" {

  instance_type = "t2.micro"
  ami = "ami-2d39803a"

  key_name = "${var.key_name}"

  # Our Security group to allow HTTP and SSH access
  vpc_security_group_ids = ["${aws_security_group.example_security_group.id}"]
  subnet_id              = "${aws_subnet.example_subnet.id}"
  associate_public_ip_address = true

  provisioner "local-exec" {
      command = "sleep 120; ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook --private-key ~/.aws/id_rsa -i '${aws_instance.web_2.public_ip},' -u ubuntu playbook/webplaybook.yml"}
}