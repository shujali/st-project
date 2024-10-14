resource "aws_key_pair" "tfkp1" {
  key_name   = "ali-tf1-key-pair-new"
  public_key = var.id_rsa_pub
}