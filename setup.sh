#!/bin/bash
# ============================================================
# Claude Code × Terraform クイックスタートセットアップ
# AWS Bedrock AI App Infrastructure
# ============================================================

set -euo pipefail

PROJECT_NAME="bedrock-ai-app"
PROJECT_DIR="${1:-./${PROJECT_NAME}}"

echo "🚀 プロジェクト作成: ${PROJECT_DIR}"

# ディレクトリ構成
mkdir -p "${PROJECT_DIR}"/{envs/{dev,prod},modules/{networking,api,compute,ai,storage,monitoring}}

# ---------- backend.tf (dev) ----------
cat > "${PROJECT_DIR}/envs/dev/backend.tf" << 'EOF'
terraform {
  backend "s3" {
    bucket         = "YOUR-TFSTATE-BUCKET"      # ← 要変更
    key            = "dev/bedrock-ai-app/terraform.tfstate"
    region         = "ap-northeast-1"
    dynamodb_table = "YOUR-TFSTATE-LOCK-TABLE"   # ← 要変更
    encrypt        = true
  }
}
EOF

# ---------- versions.tf (dev) ----------
cat > "${PROJECT_DIR}/envs/dev/versions.tf" << 'EOF'
terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"  # MCP Server で最新を確認して更新してください
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      Project     = "ai-app"
      ManagedBy   = "Terraform"
      Owner       = "ai-team"
      CostCenter  = var.cost_center
    }
  }
}
EOF

# ---------- variables.tf (dev) ----------
cat > "${PROJECT_DIR}/envs/dev/variables.tf" << 'EOF'
variable "aws_region" {
  description = "AWS リージョン"
  type        = string
  default     = "ap-northeast-1"
}

variable "environment" {
  description = "環境名 (dev/stg/prod)"
  type        = string
}

variable "cost_center" {
  description = "コストセンター"
  type        = string
}

variable "bedrock_model_id" {
  description = "Bedrock モデル ID"
  type        = string
}

variable "alert_email" {
  description = "アラート通知先メールアドレス"
  type        = string
}
EOF

# ---------- terraform.tfvars (dev) ----------
cat > "${PROJECT_DIR}/envs/dev/terraform.tfvars" << 'EOF'
environment       = "dev"
cost_center       = "YOUR-COST-CENTER"            # ← 要変更
bedrock_model_id  = "apac.anthropic.claude-sonnet-4-20250514-v1:0"
alert_email       = "your-email@example.com"      # ← 要変更
EOF

# ---------- main.tf placeholder (dev) ----------
cat > "${PROJECT_DIR}/envs/dev/main.tf" << 'EOF'
# ============================================================
# Claude Code に以下のプロンプトを送って、モジュール呼び出しを生成してもらう:
#
# > envs/dev/main.tf に全モジュール (networking, compute, ai, api,
# >   storage, monitoring) の呼び出しを追加してください。
# >   変数は variables.tf から参照し、モジュール間の依存関係
# >   (VPC ID → Lambda、Lambda ARN → API Gateway 等) を正しく接続してください。
# ============================================================
EOF

# ---------- 各モジュールの placeholder ----------
for mod in networking api compute ai storage monitoring; do
  for f in main.tf variables.tf outputs.tf; do
    touch "${PROJECT_DIR}/modules/${mod}/${f}"
  done
done

# ---------- .gitignore ----------
cat > "${PROJECT_DIR}/.gitignore" << 'EOF'
.terraform/
*.tfstate
*.tfstate.*
*.tfplan
tfplan
.terraform.lock.hcl
*.tfvars
!terraform.tfvars.example
crash.log
override.tf
override.tf.json
*_override.tf
*_override.tf.json
EOF

# ---------- terraform.tfvars.example ----------
cat > "${PROJECT_DIR}/envs/dev/terraform.tfvars.example" << 'EOF'
environment       = "dev"
cost_center       = "CHANGE-ME"
bedrock_model_id  = "apac.anthropic.claude-sonnet-4-20250514-v1:0"
alert_email       = "your-email@example.com"
EOF

# ---------- CLAUDE.md をコピー（同じディレクトリにある場合）----------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "${SCRIPT_DIR}/CLAUDE.md" ]; then
  cp "${SCRIPT_DIR}/CLAUDE.md" "${PROJECT_DIR}/CLAUDE.md"
  echo "✅ CLAUDE.md をプロジェクトルートに配置しました"
fi

# ---------- README ----------
cat > "${PROJECT_DIR}/README.md" << 'READMEEOF'
# Bedrock AI App Infrastructure

## 概要
Amazon Bedrock を中心とした AI アプリケーション基盤の Terraform コード。

## アーキテクチャ
```
[Client] → [API Gateway + WAF] → [Lambda (VPC)] → [Bedrock Runtime (VPC Endpoint)]
                                       ↓
                                  [DynamoDB] (会話履歴)
                                  [S3]       (RAG ドキュメント)
```

## 前提条件
- Terraform >= 1.6
- AWS CLI 設定済み
- Bedrock モデルアクセスが有効化済み（AWS コンソールで手動設定が必要）
  - 対象モデル: Claude Sonnet 4 (`apac.anthropic.claude-sonnet-4-20250514-v1:0`)
  - リージョン: ap-northeast-1

## セットアップ

### 1. Claude Code + MCP Server（推奨）
```bash
# Terraform MCP Server を追加
claude mcp add terraform -s user -t stdio \
  -- docker run -i --rm hashicorp/terraform-mcp-server

# プロジェクトディレクトリで Claude Code を起動
cd envs/dev
claude
```

### 2. 手動
```bash
cd envs/dev
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars を編集
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

## モジュール構成
| モジュール | 概要 |
|-----------|------|
| networking | VPC, サブネット, NAT Gateway, VPC Endpoints |
| api | API Gateway, WAF, 認証 |
| compute | Lambda, IAM Role, Security Group |
| ai | Bedrock Model Access, Knowledge Base (将来) |
| storage | DynamoDB, S3 |
| monitoring | CloudWatch Alarms, Dashboard, X-Ray, SNS |

## Claude Code での開発
`CLAUDE.md` にプロジェクト規約を記載しています。
`PROMPT_GUIDE.md` に Phase 別のプロンプト例があります。
READMEEOF

echo ""
echo "✅ プロジェクト構成を作成しました: ${PROJECT_DIR}"
echo ""
echo "📁 ディレクトリ構成:"
find "${PROJECT_DIR}" -type f | sort | sed "s|${PROJECT_DIR}/|  |"
echo ""
echo "📋 次のステップ:"
echo "  1. cd ${PROJECT_DIR}"
echo "  2. envs/dev/backend.tf の S3 バケット名を変更"
echo "  3. envs/dev/terraform.tfvars の値を変更"
echo "  4. claude コマンドで Claude Code を起動"
echo "  5. PROMPT_GUIDE.md の Phase 1 プロンプトを送信"
echo ""
