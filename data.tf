data "aws_vpc" "default_vpc" {
  default = true
}
output "default_vpc_id" {
    value = data.aws_vpc.default_vpc.id
}

data "aws_security_groups" "default_security_groups" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default_vpc.id]
  }
}

output "default_security_group_id" {
  value = data.aws_security_groups.default_security_groups.ids[0]
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default_vpc.id]
  }
}

data "aws_subnet" "default_ids" {
  for_each = toset(data.aws_subnets.default.ids)
  id       = each.value
}



output "default_subnet_ids" {
  value = [for s in data.aws_subnet.default_ids: s.id]
}

