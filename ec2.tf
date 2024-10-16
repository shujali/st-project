# Ansible Host Instance
resource "aws_instance" "team4-ansible-host" {
  ami                         = "ami-0d64bb532e0502c46" # Replace with a valid Ubuntu AMI for your region
  instance_type               = "t2.small"
  key_name                    = aws_key_pair.tfkp1.key_name
  vpc_security_group_ids      = [aws_security_group.in-out-http-ssh.id]
  subnet_id                   = aws_subnet.sn1.id
  associate_public_ip_address = true

  tags = {
    Name = "team4-ansible-host"
  }

  # Copy the Ansible inventory file to the Ansible host
  provisioner "file" {
    source      = "ansible-inventory.ini"
    destination = "/home/ubuntu/ansible-inventory.ini"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = var.id_rsa
      host        = self.public_ip
    }
  }

  # Copy docker install yaml file to the Ansible host
  provisioner "file" {
    source      = "u-docker-install.yaml"
    destination = "/home/ubuntu/u-docker-install.yaml"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = var.id_rsa
      host        = self.public_ip
    }
  }

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = var.id_rsa
      host        = self.public_ip
    }

    inline = [
      "sudo apt update -y && sudo apt upgrade -y",
      "sudo apt install -y nano net-tools vim",
      "sudo apt install software-properties-common -y",
      "sudo add-apt-repository --yes --update ppa:ansible/ansible",
      "sudo apt install ansible -y",
      "sudo hostnamectl set-hostname team4-ansible-host",
      "echo 'team4-ansible-host' | sudo tee /etc/hostname",
      # # Back up the existing hosts file
      "if [ -f /etc/ansible/hosts ]; then sudo mv /etc/ansible/hosts /etc/ansible/hosts.bak; fi",

      #Copy the new inventory file from the local machine to /etc/ansible/hosts
      "sudo cp /home/ubuntu/ansible-inventory.ini /etc/ansible/hosts",
    ]
  }
}

# Kubernetes Instances (1 master, 2 clients)
resource "aws_instance" "team4-k8s" {
  count                       = 3
  ami                         = "ami-0d64bb532e0502c46" # Replace with a vteam4d Ubuntu AMI
  instance_type               = "t2.medium"
  key_name                    = aws_key_pair.tfkp1.key_name
  vpc_security_group_ids      = [aws_security_group.in-out-http-ssh.id]
  subnet_id                   = aws_subnet.sn1.id
  associate_public_ip_address = true

  tags = {
    Name = element(["team4-k8s-master", "team4-k8s-client1", "team4-k8s-client2"], count.index)
  }

  # Update hostnames for K8s instances
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = var.id_rsa
      host        = self.public_ip
    }

    inline = [
      "sudo apt update -y && sudo apt upgrade -y",
      "sudo hostnamectl set-hostname ${element(["k8s-master", "k8s-client1", "k8s-client2"], count.index)}",
      "echo '${element(["k8s-master", "k8s-client1", "k8s-client2"], count.index)}' | sudo tee /etc/hostname",
      "sudo apt install -y nano vim"
    ]
  }
}

# Update /etc/hosts on Ansible host with private IPs of K8s nodes
resource "null_resource" "update_hosts" {
  depends_on = [aws_instance.team4-ansible-host, aws_instance.team4-k8s]

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = var.id_rsa
      host        = aws_instance.team4-ansible-host.public_ip
    }

    inline = [
      "echo '${aws_instance.team4-k8s[0].private_ip} k8s-master' | sudo tee -a /etc/hosts",
      "echo '${aws_instance.team4-k8s[1].private_ip} k8s-client1' | sudo tee -a /etc/hosts",
      "echo '${aws_instance.team4-k8s[2].private_ip} k8s-client2' | sudo tee -a /etc/hosts"
    ]
  }
}

# Generate SSH key on Ansible host
resource "null_resource" "generate_ssh_key" {
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = var.id_rsa
      host        = aws_instance.team4-ansible-host.public_ip
    }

    inline = [
      # Ensure the /root/.ssh directory exists
      "sudo mkdir -p /root/.ssh",

      # Set the right permissions for the .ssh directory
      "sudo chmod 700 /root/.ssh",

      # Generate SSH key for root user
      "sudo ssh-keygen -t rsa -b 2048 -f /root/.ssh/id_rsa -q -N ''",

      # Set proper permissions for the private and public key
      "sudo chmod 600 /root/.ssh/id_rsa",
      "sudo chmod 644 /root/.ssh/id_rsa.pub"
    ]
  }
}

# Copy public key to a user-accessible location
resource "null_resource" "copy_public_key" {
  depends_on = [null_resource.generate_ssh_key]

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = var.id_rsa
      host        = aws_instance.team4-ansible-host.public_ip
    }

    inline = [
      "sudo cp /root/.ssh/id_rsa.pub /home/ubuntu/id_rsa.pub",
      "sudo chown ubuntu:ubuntu /home/ubuntu/id_rsa.pub"
    ]
  }
}

# # Fetch the public key from the Ansible host
# resource "null_resource" "fetch_public_key" {
#   depends_on = [null_resource.copy_public_key] # Ensure the public key is already copied to the user-accessible folder

#   provisioner "local-exec" {
#       command = "ssh -vvv -i /mnt/c/Users/Ali/.ssh/id_rsa -o StrictHostKeyChecking=no ubuntu@${aws_instance.team4-ansible-host.public_ip} 'cat /home/ubuntu/id_rsa.pub' > ansible_public_key.pub"
#   }
# }

# AWS Infrastructure Components (VPC, IGW, Route Table, Subnets, Security Group)
resource "aws_internet_gateway" "team4gw" {
  vpc_id = aws_vpc.team4vpc.id
  tags = {
    "Name" = "team4-tf-igw"
  }
}

resource "aws_route_table" "rtb1" {
  vpc_id = aws_vpc.team4vpc.id
  tags = {
    "Name" = "team4-tf-rtb"
  }
}

resource "aws_route" "igr" {
  route_table_id         = aws_route_table.rtb1.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.team4gw.id
}

resource "aws_security_group" "in-out-http-ssh" {
  vpc_id = aws_vpc.team4vpc.id
  name   = "in-out-http-ssh"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # Allow internal communication
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "in_out_http_ssh"
  }
}

resource "aws_subnet" "sn1" {
  vpc_id     = aws_vpc.team4vpc.id
  cidr_block = "10.1.1.0/25"
  tags = {
    "Name" = "team4-tf-vpc-sn1"
  }
}

resource "aws_route_table_association" "associatesn1" {
  subnet_id      = aws_subnet.sn1.id
  route_table_id = aws_route_table.rtb1.id
}

resource "aws_vpc" "team4vpc" {
  cidr_block = "10.1.1.0/24"
  tags = {
    "Name" = "team4-tf-vpc"
  }
}
