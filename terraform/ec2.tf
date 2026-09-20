# --- EC2 Instances ---

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

locals {
  user_data_a = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y nginx amazon-efs-utils
    systemctl enable nginx
    systemctl start nginx
    echo "<h1>Server in AZ: ${var.region}a</h1>" > /usr/share/nginx/html/index.html
    mkdir -p /mnt/shared
    mount -t efs -o tls ${aws_efs_file_system.shared_fs.id}:/ /mnt/shared
  EOF

  user_data_b = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y nginx amazon-efs-utils
    systemctl enable nginx
    systemctl start nginx
    echo "<h1>Server in AZ: ${var.region}b</h1>" > /usr/share/nginx/html/index.html
    mkdir -p /mnt/shared
    mount -t efs -o tls ${aws_efs_file_system.shared_fs.id}:/ /mnt/shared
  EOF
}

resource "aws_instance" "app_a" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.private_a.id
  vpc_security_group_ids      = [aws_security_group.app_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  associate_public_ip_address = false
  user_data                   = local.user_data_a

  root_block_device {
    encrypted   = true
    volume_type = "gp3"
  }
  
  tags = { Name = "depi-sec-app-a" }
  depends_on = [aws_efs_mount_target.target_a]
}

resource "aws_instance" "app_b" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.private_b.id
  vpc_security_group_ids      = [aws_security_group.app_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  associate_public_ip_address = false
  user_data                   = local.user_data_b

  root_block_device {
    encrypted   = true
    volume_type = "gp3"
  }

  tags = { Name = "depi-sec-app-b" }
  depends_on = [aws_efs_mount_target.target_b]
}