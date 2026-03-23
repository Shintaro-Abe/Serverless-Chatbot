################################################################################
# Phase 1: Networking
################################################################################

module "networking" {
  source = "../../modules/networking"

  environment = var.environment
  aws_region  = var.aws_region

  vpc_cidr             = "10.0.0.0/16"
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]
  availability_zones   = ["ap-northeast-1a", "ap-northeast-1c"]

  enable_flow_log         = true
  flow_log_retention_days = 90
}

################################################################################
# Phase 2: AI / Bedrock
################################################################################

module "ai" {
  source = "../../modules/ai"

  environment      = var.environment
  aws_region       = var.aws_region
  bedrock_model_id = var.bedrock_model_id
}

module "compute" {
  source = "../../modules/compute"

  environment       = var.environment
  aws_region        = var.aws_region
  bedrock_model_id  = module.ai.bedrock_model_id
  bedrock_model_arn = module.ai.bedrock_model_arn

  vpc_id             = module.networking.vpc_id
  private_subnet_ids = module.networking.private_subnet_ids
  vpc_cidr_block     = module.networking.vpc_cidr_block

  bedrock_endpoint_security_group_id = module.networking.bedrock_endpoint_security_group_id

  # Phase 4 で追加: DynamoDB 接続
  dynamodb_table_name    = module.storage.dynamodb_table_name
  dynamodb_table_arn     = module.storage.dynamodb_table_arn
  enable_dynamodb_access = true
}

################################################################################
# Phase 3: API Gateway + 認証
################################################################################

module "api" {
  source = "../../modules/api"

  environment = var.environment
  aws_region  = var.aws_region

  lambda_function_invoke_arn = module.compute.lambda_function_invoke_arn
  lambda_function_name       = module.compute.lambda_function_name

  api_auth_type      = "API_KEY"
  cors_allow_origins = ["*"]
}

################################################################################
# Phase 4: Storage
################################################################################

module "storage" {
  source = "../../modules/storage"

  environment           = var.environment
  dynamodb_billing_mode = "PAY_PER_REQUEST"
}

################################################################################
# Phase 5: Monitoring
################################################################################

module "monitoring" {
  source = "../../modules/monitoring"

  environment = var.environment
  aws_region  = var.aws_region

  lambda_function_name   = module.compute.lambda_function_name
  api_gateway_id         = module.api.api_gateway_id
  api_gateway_stage_name = module.api.api_gateway_stage_name
  dynamodb_table_name    = module.storage.dynamodb_table_name
  bedrock_model_id       = module.ai.bedrock_model_id

  alert_email = var.alert_email
}
