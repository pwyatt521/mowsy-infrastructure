resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.environment}-mowsy-vpc"
    Environment = var.environment
    Project     = "mowsy"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.environment}-mowsy-igw"
    Environment = var.environment
    Project     = "mowsy"
  }
}

resource "aws_subnet" "public" {
  count = length(var.availability_zones)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.environment}-mowsy-public-${var.availability_zones[count.index]}"
    Environment = var.environment
    Project     = "mowsy"
    Type        = "public"
  }
}

resource "aws_subnet" "private" {
  count = length(var.availability_zones)

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name        = "${var.environment}-mowsy-private-${var.availability_zones[count.index]}"
    Environment = var.environment
    Project     = "mowsy"
    Type        = "private"
  }
}

resource "aws_eip" "nat" {
  count = var.enable_nat_gateway ? (var.environment == "dev" ? 1 : length(var.availability_zones)) : 0

  domain = "vpc"
  depends_on = [aws_internet_gateway.main]

  tags = {
    Name        = "${var.environment}-mowsy-nat-eip-${count.index + 1}"
    Environment = var.environment
    Project     = "mowsy"
  }
}

resource "aws_nat_gateway" "main" {
  count = var.enable_nat_gateway ? (var.environment == "dev" ? 1 : length(var.availability_zones)) : 0

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name        = "${var.environment}-mowsy-nat-${count.index + 1}"
    Environment = var.environment
    Project     = "mowsy"
  }

  depends_on = [aws_internet_gateway.main]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "${var.environment}-mowsy-public-rt"
    Environment = var.environment
    Project     = "mowsy"
  }
}

resource "aws_route_table" "private" {
  count = var.enable_nat_gateway ? (var.environment == "dev" ? 1 : length(var.availability_zones)) : 0

  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = {
    Name        = "${var.environment}-mowsy-private-rt-${count.index + 1}"
    Environment = var.environment
    Project     = "mowsy"
  }
}

resource "aws_route_table_association" "public" {
  count = length(var.availability_zones)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count = length(var.availability_zones)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = var.enable_nat_gateway ? aws_route_table.private[var.environment == "dev" ? 0 : count.index].id : aws_route_table.public.id
}

resource "aws_security_group" "lambda" {
  name_prefix = "${var.environment}-mowsy-lambda-"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.environment}-mowsy-lambda-sg"
    Environment = var.environment
    Project     = "mowsy"
  }
}

resource "aws_security_group" "rds" {
  name_prefix = "${var.environment}-mowsy-rds-"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda.id]
  }

  tags = {
    Name        = "${var.environment}-mowsy-rds-sg"
    Environment = var.environment
    Project     = "mowsy"
  }
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id          = aws_vpc.main.id
  service_name    = "com.amazonaws.${var.aws_region}.s3"
  route_table_ids = var.enable_nat_gateway ? concat([aws_route_table.public.id], aws_route_table.private[*].id) : [aws_route_table.public.id]

  tags = {
    Name        = "${var.environment}-mowsy-s3-endpoint"
    Environment = var.environment
    Project     = "mowsy"
  }
}