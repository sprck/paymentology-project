# Subnets
# Public Subnets

resource "aws_subnet" "public-subnet-pay_app" {
  for_each = { for i, az in var.availability_zones : i => az }

  vpc_id                  = aws_vpc.pay-demo-vpc.id
  availability_zone       = each.value
  map_public_ip_on_launch = true

  cidr_block = cidrsubnet(var.vpc_cidr_block, 8, each.key)

  tags = merge(var.tags, { Name = "${var.app_name}-public-${each.value}" })
}

# Private Subnets
resource "aws_subnet" "private-subnet-pay_app" {
  for_each = { for i, az in var.availability_zones : i => az }

  vpc_id            = aws_vpc.pay-demo-vpc.id
  availability_zone = each.value

  cidr_block = cidrsubnet(var.vpc_cidr_block, 4, each.key + 1)

  tags = merge(var.tags, { Name = "${var.app_name}-private-${each.value}" })
}


#Internet Gateway

resource "aws_internet_gateway" "igw-pay" {
  vpc_id = aws_vpc.pay-demo-vpc.id

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-igw"
    }
  )
}

# Nat Gateway EIP

resource "aws_eip" "eip-pay" {
  for_each = { for i, az in var.availability_zones : i => az }
  domain   = "vpc"

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-nat-eip-${each.value}"
    }
  )
  
  depends_on = [aws_internet_gateway.igw-pay]
}

# Nat Gateway

resource "aws_nat_gateway" "nat-gw-pay" {
  for_each = { for i, az in var.availability_zones : i => az }

  allocation_id = aws_eip.eip-pay[each.key].id
  subnet_id     = aws_subnet.public-subnet-pay_app[each.key].id

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-nat-gw-${each.value}"
    }
  )

  depends_on = [aws_internet_gateway.igw-pay]
}

# Route Tables
# Public Route Table
resource "aws_route_table" "public-route-table-pay" {
  vpc_id = aws_vpc.pay-demo-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw-pay.id
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-public-rt"
    }
  )
}
# Public Route Table Association
resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public-subnet-pay_app
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public-route-table-pay.id
}

# Private Route Table
resource "aws_route_table" "private-route-table-pay" {
  for_each = { for i, az in var.availability_zones : i => az }
  vpc_id   = aws_vpc.pay-demo-vpc.id

  # Each route table points to the NAT Gateway in its own AZ.
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat-gw-pay[each.key].id
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-private-rt-${each.value}"
    }
  )
}

# Private Route Table Association

resource "aws_route_table_association" "private" {
  for_each = { for i, az in var.availability_zones : i => az }

  # Associate the private subnet in this AZ with the private route table for this AZ.
  subnet_id      = aws_subnet.private-subnet-pay_app[each.key].id
  route_table_id = aws_route_table.private-route-table-pay[each.key].id
} 