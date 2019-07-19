
 provider "aws" {
  region = "${var.aws_region}"
  profile = "${var.aws_profile}"
}
########################### Elb steps ###############################

resource "aws_elb" "newcluster" {

   name = "${var.cluster_name}"
   availability_zones = ["${var.elb_az}"]
   security_groups = ["${var.elb_sg_group}"]

    listener {
    instance_port     = 80
    instance_protocol = "HTTP"
    lb_port           = 80
    lb_protocol       = "HTTP"
  }

    listener {
    instance_port     = 443
    instance_protocol = "HTTPS"
    lb_port           = 443
    lb_protocol       = "HTTPS"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 6
    timeout             = 5
    target              = "HTTP:80/"
    interval            = 15
  }

  tags = {
    Name = "var.cluster_name"
  }
 }


/############################## launch template ########################
/##dependn on infrastructure you can either use scp or anythin for userdata

data "template_file" "user_data" {
        template = <<EOF
                #!/bin/bash
                wget https://personalurl.com/scripts/boot.sh -o /root/scripts/boot.sh
                chmod +x  /root/scripts/boot.sh
                /root/scripts/boot.sh > /root/scripts/boot.out
                EOF
}

/## I'm considering the instance store servers for my clusters so I'm considering two discs /dev/sdb & /dev/sdc 
resource "aws_launch_template" "newcluster"  {
  name = "${var.cluster_name}"

   block_device_mappings {
        device_name = "/dev/sdb"
        virtual_name = "ephemeral0"
        }

        block_device_mappings {
        device_name = "/dev/sdc"
        virtual_name = "ephemeral1"
        }

  disable_api_termination = false

  ebs_optimized = false

  iam_instance_profile {
      name = "${var.iam_role}"
  }

  image_id = "${var.ami_id}"

  instance_initiated_shutdown_behavior = "terminate"
  key_name = "${var.key_name}"

monitoring {
    enabled = false
  }

  vpc_security_group_ids = ["sg-0***********"]

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "${var.cluster_name}-Node"
      Instancetype = "spot"
      User = "any"
    }
  }

  user_data = "${base64encode(data.template_file.user_data.rendered)}"
}

####################### aws  ASG #######################33


resource "aws_vpc" "default" {
  cidr_block = "172.30.0.0/16"
}

resource "aws_subnet" "main" {
  vpc_id            = "${aws_vpc.default.id}"
  cidr_block        = "172.30.8.0/22"
  availability_zone = "us-east-1e"
}


resource "aws_autoscaling_group" "asg" {
  name                      = "${var.asg_name}"
  max_size                  = 0
  min_size                  = 0
  health_check_grace_period = 300
  health_check_type         = "ELB"
  desired_capacity          = 0
  force_delete              = true

#launch_template {
#    id      = "${aws_launch_template.RTB.id}"
#    version = "$Latest"
#  }

tags = [
    {
      key                 = "Name"
      value               = "${var.cluster_name}"
      propagate_at_launch = true
    },
  ]

vpc_zone_identifier = [
    "${aws_subnet.main.id}",
  ]

mixed_instances_policy {
    launch_template {
      launch_template_specification {
        launch_template_id = "${aws_launch_template.cluster_name.id}"
      }

      override {
        instance_type = "c3.2xlarge"
      }

      override {
        instance_type = "i3.8xlarge"
      }


    }
  instances_distribution {
      on_demand_base_capacity = "0"
      on_demand_percentage_above_base_capacity = "0"
      spot_max_price= "0.2"

    }


}

}
