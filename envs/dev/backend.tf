# S3 バックエンド設定
# 初回は local バックエンドで apply し、S3 バケット作成後にコメントを外して migrate する
#
# terraform init -migrate-state

# terraform {
#   backend "s3" {
#     bucket         = "dev-ai-app-tfstate"
#     key            = "dev/bedrock-ai-app/terraform.tfstate"
#     region         = "ap-northeast-1"
#     dynamodb_table = "dev-ai-app-tfstate-lock"
#     encrypt        = true
#   }
# }
