resource "aws_vpc" "my-vpc" {
  cidr_block           = "10.31.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "dev"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.my-vpc.id
  cidr_block              = "10.31.0.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "eu-west-2a"

  tags = {
    Name = "dev_public"
  }
}

resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my-vpc.id

  tags = {
    Name = "dev_igw"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.my-vpc.id

  tags = {
    Name = "dev_public_rt"
  }
}

resource "aws_route" "default_route" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.my_igw.id
}

resource "aws_route_table_association" "my_public_rt_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_security_group" "my_sg" {
  name        = "dev_sg"
  description = "dev security group"
  vpc_id      = aws_vpc.my-vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["81.107.84.205/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "my_auth" {
  key_name   = "mykey"
  public_key = file("~/.ssh/mykey.pub")
}

resource "aws_instance" "dev_node" {
  instance_type          = "t2.micro"
  ami                    = data.aws_ami.server_ami.id
  key_name               = aws_key_pair.my_auth.id
  vpc_security_group_ids = [aws_security_group.my_sg.id]
  subnet_id              = aws_subnet.public_subnet.id
  user_data              = file("userdata.tpl")

  root_block_device {
    volume_size = 10
  }

  tags = {
    name = "dev-node"

  }

  provisioner "local-exec" {
    command = templatefile("${var.host_os}-ssh-config.tpl", {
      hostname     = self.public_ip,
      user         = "ubuntu",
      identityfile = "~/.ssh/mykey"

    })
    interpreter = var.host_os == "linux" ? ["bash", "-c"] : ["Powershell", "Command"] 
  }
}