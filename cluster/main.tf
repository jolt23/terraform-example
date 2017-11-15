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
# CREATE THE AUTO SCALING GROUP
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_autoscaling_group" "example" {

  vpc_zone_identifier = ["${aws_subnet.example_subnet.id}"]
  launch_configuration = "${aws_launch_configuration.example.id}"

  min_size = 1
  max_size = 3

  load_balancers = ["${aws_elb.example_elb.name}"]
  health_check_type = "ELB"
  health_check_grace_period = 300

  tag {
    key = "Name"
    value = "terraform-asg-example"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }

  wait_for_capacity_timeout = "2m"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A LAUNCH CONFIGURATION THAT DEFINES EACH EC2 INSTANCE IN THE ASG
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_launch_configuration" "example" {

  image_id = "ami-2d39803a"
  instance_type = "t2.micro"
  security_groups = ["${aws_security_group.example_security_group.id}"]

  user_data = <<-EOF
              #!/bin/bash
              echo "Hello, Royal Caribbean! Let's Roll" > index.html
              nohup busybox httpd -f -p "${var.server_port}" &
              EOF

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
}