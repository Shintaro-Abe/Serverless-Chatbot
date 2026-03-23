output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "プライベートサブネット ID のリスト"
  value       = module.vpc.private_subnets
}

output "public_subnet_ids" {
  description = "パブリックサブネット ID のリスト"
  value       = module.vpc.public_subnets
}

output "bedrock_endpoint_id" {
  description = "Bedrock Runtime VPC Endpoint ID"
  value       = aws_vpc_endpoint.bedrock_runtime.id
}

output "vpc_cidr_block" {
  description = "VPC CIDR ブロック"
  value       = module.vpc.vpc_cidr_block
}

output "bedrock_endpoint_security_group_id" {
  description = "Bedrock Endpoint 用セキュリティグループ ID"
  value       = aws_security_group.vpc_endpoints.id
}
