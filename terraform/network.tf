############################################
# VPC
############################################
resource "aws_vpc" "vpc-prod" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "vpc-prod"
  }
}

############################################
# Subnets Públicas
############################################
resource "aws_subnet" "subnet-public-a" {
  vpc_id            = aws_vpc.vpc-prod.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "subnet-prod-public-a"
  }
}

resource "aws_subnet" "subnet-public-b" {
  vpc_id            = aws_vpc.vpc-prod.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "subnet-prod-public-b"
  }
}

############################################
# Subnets Privadas
############################################
resource "aws_subnet" "subnet-private-a" {
  vpc_id            = aws_vpc.vpc-prod.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "subnet-prod-private-a"
  }
}

resource "aws_subnet" "subnet-private-b" {
  vpc_id            = aws_vpc.vpc-prod.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "subnet-prod-private-b"
  }
}

############################################
# Internet Gateway
############################################
resource "aws_internet_gateway" "vpc-prod-igw" {
  vpc_id = aws_vpc.vpc-prod.id

  tags = {
    Name = "vpc-prod-igw"
  }
}

############################################
# Elastic IP para NAT
############################################
resource "aws_eip" "nat-eip" {
  domain = "vpc"

  tags = {
    Name = "nat-eip"
  }
}

############################################
# NAT Gateway (na subnet pública A)
############################################
resource "aws_nat_gateway" "nat-gw" {
  allocation_id = aws_eip.nat-eip.id
  subnet_id     = aws_subnet.subnet-public-a.id

  tags = {
    Name = "nat-gw"
  }

  depends_on = [aws_internet_gateway.vpc-prod-igw]
}

############################################
# Route Table Pública
############################################
resource "aws_route_table" "public-rtb" {
  vpc_id = aws_vpc.vpc-prod.id

  tags = {
    Name = "public-rtb"
  }
}

# Rota 0.0.0.0/0 via IGW
resource "aws_route" "public-default-route" {
  route_table_id         = aws_route_table.public-rtb.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.vpc-prod-igw.id
}

# Associar subnets públicas
resource "aws_route_table_association" "subnet-public-a-association" {
  subnet_id      = aws_subnet.subnet-public-a.id
  route_table_id = aws_route_table.public-rtb.id
}

resource "aws_route_table_association" "subnet-public-b-association" {
  subnet_id      = aws_subnet.subnet-public-b.id
  route_table_id = aws_route_table.public-rtb.id
}

############################################
# Route Table Privada
############################################
resource "aws_route_table" "private-rtb" {
  vpc_id = aws_vpc.vpc-prod.id

  tags = {
    Name = "private-rtb"
  }
}

# Rota 0.0.0.0/0 via NAT
resource "aws_route" "private-default-route" {
  route_table_id         = aws_route_table.private-rtb.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat-gw.id
}

# Associar subnets privadas
resource "aws_route_table_association" "subnet-private-a-association" {
  subnet_id      = aws_subnet.subnet-private-a.id
  route_table_id = aws_route_table.private-rtb.id
}

resource "aws_route_table_association" "subnet-private-b-association" {
  subnet_id      = aws_subnet.subnet-private-b.id
  route_table_id = aws_route_table.private-rtb.id
}

############################################
# Security Group ALB
############################################
resource "aws_security_group" "alb-prod-sg" {
  name        = "alb-prod-sg"
  description = "Allow HTTP inbound and all outbound traffic"
  vpc_id      = aws_vpc.vpc-prod.id

  tags = {
    Name = "alb-prod-sg"
  }
}

resource "aws_security_group_rule" "alb-http-ingress" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb-prod-sg.id
}

resource "aws_security_group_rule" "alb-egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb-prod-sg.id
}

############################################
# Security Group App
############################################
resource "aws_security_group" "dotgroup-app-prod-sg" {
  name        = "dotgroup-app-prod-sg"
  description = "Allow HTTP inbound from ALB and all outbound traffic"
  vpc_id      = aws_vpc.vpc-prod.id

  tags = {
    Name = "dotgroup-app-prod-sg"
  }
}

resource "aws_security_group_rule" "app-http-ingress" {
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  security_group_id         = aws_security_group.dotgroup-app-prod-sg.id
  source_security_group_id = aws_security_group.alb-prod-sg.id
}

resource "aws_security_group_rule" "app-egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.dotgroup-app-prod-sg.id
}