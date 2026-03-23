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
