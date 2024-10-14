# Output public and private IPs for Ansible host
output "ansible_host_ips" {
  description = "Public and Private IP addresses for Ansible host"
  value = {
    "ali-ansible-host" = {
      public_ip  = aws_instance.team4-ansible-host.public_ip
      private_ip = aws_instance.team4-ansible-host.private_ip
    }
  }
}

# Output public and private IPs for Kubernetes instances
output "k8s_instance_ips" {
  description = "Public and Private IP addresses for K8s instances"
  value = {
    for instance in aws_instance.team4-k8s :
    instance.tags["Name"] => {
      public_ip  = instance.public_ip
      private_ip = instance.private_ip
    }
  }
}


output "key_pair_name" {
  value = aws_key_pair.tfkp1.key_name
}

output "security_group_id" {
  value = aws_security_group.in-out-http-ssh.id
}

output "subnet_id" {
  value = aws_subnet.sn1.id
}

output "region" {
  value = var.ali1_location
}