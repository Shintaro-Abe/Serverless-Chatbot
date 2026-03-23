# CLAUDE.md — Bedrock AI App Infrastructure

## プロジェクト概要
Amazon Bedrock を中心とした AI アプリケーション基盤を Terraform で構築する。
社内向け AI チャットボット / RAG アプリのバックエンドインフラ。

## アーキテクチャ方針
- サーバーレス優先（Lambda + API Gateway + DynamoDB）
- Bedrock はオンデマンド推論を基本とし、Provisioned Throughput は明示指示があるときのみ
- VPC Lambda は Bedrock エンドポイント経由でアクセス（VPC Endpoint: com.amazonaws.{region}.bedrock-runtime）
- マルチAZ構成、プライベートサブネットに Lambda を配置

## Terraform 規約

### バージョン・バックエンド
- Terraform >= 1.6
- AWS Provider >= 5.0（MCP Server で最新を確認すること）
- バックエンド: S3 + DynamoDB（state locking）
- Provider ブロックに `default_tags` を必ず設定

### ディレクトリ構成
```
envs/
  dev/
    main.tf          # モジュール呼び出し
    variables.tf     # 環境固有変数
    terraform.tfvars # 環境固有値
    backend.tf       # S3 バックエンド
  prod/
modules/
  networking/        # VPC, Subnets, NAT, Endpoints
  api/               # API Gateway, WAF
  compute/           # Lambda, IAM Role
  ai/                # Bedrock Model Access, Knowledge Base
  storage/           # S3, DynamoDB
  monitoring/        # CloudWatch, Alarms, X-Ray
```

### 命名規則
- リソース名: `{env}-{project}-{resource}` 例: `dev-ai-app-lambda-chat`
- Terraform リソース名（HCL内）: スネークケース `aws_lambda_function.chat_handler`
- 変数名: スネークケース `bedrock_model_id`

### タグ戦略（必須タグ）
```hcl
default_tags {
  tags = {
    Environment = var.environment      # dev / stg / prod
    Project     = "ai-app"
    ManagedBy   = "Terraform"
    Owner       = "ai-team"
    CostCenter  = var.cost_center
  }
}
```

### セキュリティ要件
- IAM は最小権限。`*` アクションは絶対に使わない
- Lambda 実行ロールは `bedrock:InvokeModel` のみ、対象モデル ARN を明示
- API Gateway には WAF + Cognito or API Key 認証を付与
- S3 バケットは暗号化（SSE-KMS）+ パブリックアクセスブロック必須
- DynamoDB は暗号化（AWS Managed Key 以上）
- CloudWatch Logs は KMS 暗号化 + 保持期間 90日

### ワークフロー
1. `terraform fmt` → `terraform validate` → 必ず先に実行
2. `terraform plan -out=tfplan` → 人間がレビュー
3. `terraform apply tfplan` → 人間の明示的承認後のみ
4. エラー発生時: エラーメッセージを分析し、修正を提案（自動 apply しない）

### やらないこと
- `terraform apply -auto-approve` は絶対に使わない
- ハードコードされた AWS アカウント ID やシークレットをコードに含めない
- Provisioned Concurrency / Provisioned Throughput は明示指示なしに設定しない
- NAT Gateway は使用しない（全 AWS サービスへは VPC Endpoint 経由でアクセス）

## Bedrock 固有の注意事項
- モデル ID は変数化する（例: `apac.anthropic.claude-sonnet-4-20250514-v1:0`）
- 推論プロファイル ID（apac./global./jp. 等のプレフィックス付き）の場合は inference-profile ARN を使用
- Bedrock Model Access は Terraform で有効化できない → 手動有効化を README に記載
- Knowledge Base 用 S3 バケットと OpenSearch Serverless は別モジュール
- InvokeModel のレスポンスサイズに注意（Lambda のメモリ / タイムアウト設定）

## コマンドリファレンス
```bash
# 初期化
cd envs/dev && terraform init

# 検証
terraform fmt -recursive && terraform validate

# 計画
terraform plan -out=tfplan

# 適用（人間の確認後）
terraform apply tfplan

# 破棄（開発環境のみ）
terraform destroy
```
