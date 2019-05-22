# defines which providor we are using and which region
# us-east-1 is Virginia :)
provider "aws" {
    region = "us-east-1"
}

# gets a referenece of all availibility zones from above region
data "aws_availability_zones" "all" {}


# describe and create instance type and what to install 
resource "aws_launch_configuration" "example" {
    image_id = "ami-0a313d6098716f372" #Ubuntu AMI ID
    instance_type = "t2.micro"
    security_groups = ["${aws_security_group.instance.id}"]

    # set up what content we want in our web server
    user_data = <<-EOF
                #!/bin/bash
                echo "Hello World" > index.html
                nohup busybox httpd -f -p 8080 &
                EOF

    # will create new webservers before destroying old ones
    lifecycle {
        create_before_destroy = true
    }
  
}

# create autoscaling group
resource "aws_autoscaling_group" "example" {
    launch_configuration    = "${aws_launch_configuration.example.id}"
    availability_zones      = ["${data.aws_availability_zones.all.names}"]

    load_balancers      = ["${aws_elb.example.name}"]
    health_check_type   = "ELB"
    
    min_size = 2
    max_size = 10

    tag {
        key                 = "name"
        value               = "terraform_asg_example"
        propagate_at_launch = true
    }
}

# create security group for instances
resource "aws_security_group" "instance" {
    name = "terraform-example-instance"

    ingress {
        from_port   = "${var.server_port}"
        to_port     = "${var.server_port}"
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    # we need this lifecycle so we can reapply the security group to our 
    # new instances that get deployed
    lifecycle {
        create_before_destroy = true 
    }
  
}

# create ELB
resource "aws_elb" "example" {
    name                = "terraform-asg-example"
    availability_zones  = ["${data.aws_availability_zones.all.names}"]
    security_groups     = ["${aws_security_group.elb.id}"]  

    # tell the ELB which listeners to open
    listener {
        lb_port             = 80
        lb_protocol         = "http"
        instance_port       = "${var.server_port}"
        instance_protocol    = "http"
    }

    health_check {
        healthy_threshold       = 2
        unhealthy_threshold     = 2
        timeout                 = 3
        interval                = 30
        target                  = "HTTP:${var.server_port}/"  
    }
  
}

resource "aws_security_group" "elb" {
    name = "terraform-example-elb"

    ingress {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
        
    }
}





