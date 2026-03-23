# Claude Code × Terraform 実践プロンプトガイド
## AWS Bedrock AI アプリ基盤構築

---

## 0. 前提：Dev Container でのセットアップ

### MCP Server の追加（初回のみ）

```bash
# Terraform MCP Server（HashiCorp 公式）
claude mcp add terraform -s user -t stdio \
  -- docker run -i --rm hashicorp/terraform-mcp-server

# AWS Labs Terraform MCP Server（AWS セキュリティコンプライアンス付き）
claude mcp add awslabs.terraform-mcp-server -s project \
  -e FASTMCP_LOG_LEVEL=ERROR \
  -- uvx awslabs.terraform-mcp-server@latest

# （任意）AWS CDK MCP Server
claude mcp add awslabs.cdk-mcp-server -s project \
  -e FASTMCP_LOG_LEVEL=ERROR \
  -- uvx awslabs.cdk-mcp-server@latest
```

### Terraform Skill の導入（推奨）

```bash
# マーケットプレイスから
/plugin marketplace add antonbabenko/terraform-skill

# または手動
git clone https://github.com/antonbabenko/terraform-skill \
  ~/.claude/skills/terraform-skill
```

### CLAUDE.md の配置

```bash
# プロジェクトルートに配置（同梱の CLAUDE.md を使用）
cp CLAUDE.md /path/to/your/project/CLAUDE.md
```

---

## 1. Phase 1 — ネットワーク基盤（VPC + Endpoints）

### プロンプト 1-1: VPC モジュール作成

```
modules/networking/ に Terraform モジュールを作成してください。

要件:
- 東京リージョン (ap-northeast-1)
- VPC CIDR: 10.0.0.0/16
- パブリックサブネット: 2つ（AZ-a, AZ-c）、CIDR: 10.0.1.0/24, 10.0.2.0/24
- プライベートサブネット: 2つ（AZ-a, AZ-c）、CIDR: 10.0.11.0/24, 10.0.12.0/24
- NAT Gateway: dev環境はシングル、prod環境はマルチAZ（変数で切替）
- VPC Endpoint:
  - com.amazonaws.ap-northeast-1.bedrock-runtime（Interface型）
  - com.amazonaws.ap-northeast-1.s3（Gateway型）
  - com.amazonaws.ap-northeast-1.dynamodb（Gateway型）
  - com.amazonaws.ap-northeast-1.logs（Interface型）
- VPC フローログ: S3 に出力

terraform-aws-modules/vpc/aws の最新バージョンを MCP Server で確認して使ってください。
出力: vpc_id, private_subnet_ids, public_subnet_ids, bedrock_endpoint_id
```

**ポイント:** 「MCP Server で確認して」と明示することで、Claude Code が Terraform Registry にリアルタイムクエリを投げます。

### プロンプト 1-2: 検証とエラー修正

```
modules/networking/ の Terraform コードに対して以下を実行してください:
1. terraform fmt -recursive
2. terraform validate
3. エラーがあれば修正して再度 validate
4. 問題がなければ、envs/dev/main.tf からこのモジュールを呼び出すコードも生成
```

---

## 2. Phase 2 — AI / Bedrock モジュール

### プロンプト 2-1: Bedrock + Lambda 構成

```
modules/compute/ と modules/ai/ を作成してください。

■ modules/ai/
- Bedrock Model Access の管理（※Terraform では有効化不可なので、
  terraform_data + local-exec で確認コマンドを実行し、
  未有効化の場合はエラーメッセージを出す仕組みにしてください）
- 将来的な Knowledge Base 用の placeholder を variables に用意

■ modules/compute/
- Lambda 関数（Python 3.12 ランタイム）
  - 関数名: ${env}-ai-app-chat-handler
  - メモリ: 512MB（Bedrock レスポンス処理のため）
  - タイムアウト: 30秒
  - VPC 内配置（プライベートサブネット）
  - 環境変数: BEDROCK_MODEL_ID, DYNAMODB_TABLE_NAME
- IAM ロール:
  - bedrock:InvokeModel（モデル ARN を指定、* は使わない）
  - dynamodb:PutItem, GetItem, Query（テーブル ARN を指定）
  - logs:CreateLogGroup, CreateLogStream, PutLogEvents
  - VPC 用: ec2:CreateNetworkInterface, ec2:DescribeNetworkInterfaces, ec2:DeleteNetworkInterface
- Lambda Layer: boto3 最新版（Bedrock API の最新機能を使うため）

セキュリティグループ:
- Lambda SG: アウトバウンドのみ（Bedrock VPC Endpoint への HTTPS 443）
- Bedrock Endpoint SG: Lambda SG からのインバウンド HTTPS 443 を許可

IAM ポリシーは必ず最小権限で、各 Statement に人間が読めるSid を付けてください。
```

### プロンプト 2-2: IAM ポリシーの確認

```
modules/compute/ で生成した IAM ポリシーを確認させてください。
以下の観点でレビューして、問題があれば修正してください:
1. Resource に * が使われていないか
2. 不要な Action が含まれていないか
3. Condition で制限を追加できる箇所はないか（例: bedrock:InvokeModel に aws:SourceVpc）
4. 各 Statement に分かりやすい Sid が付いているか
```

---

## 3. Phase 3 — API Gateway + 認証

### プロンプト 3-1: API Gateway モジュール

```
modules/api/ を作成してください。

要件:
- REST API（API Gateway v1）
  - リソース: /chat (POST)
  - Lambda プロキシ統合
  - CORS 設定: 許可オリジンは変数化
- 認証: API Key + Usage Plan
  - Rate limit: 100 req/sec
  - Burst: 200
  - Quota: 10,000 req/day
- WAF v2:
  - AWS Managed Rule: AWSManagedRulesCommonRuleSet
  - Rate-based Rule: 同一 IP から 300 req/5min 超でブロック
  - Body サイズ制限: 8KB（Bedrock リクエストの上限を考慮）
- ステージ: dev / prod（変数で切替）
- アクセスログ: CloudWatch Logs に出力

将来的に Cognito 認証に切り替える可能性があるので、
認証方式を変数 (api_auth_type = "API_KEY" | "COGNITO") で切り替えられる設計にしてください。
```

---

## 4. Phase 4 — データストア

### プロンプト 4-1: DynamoDB + S3

```
modules/storage/ を作成してください。

■ DynamoDB テーブル
- テーブル名: ${env}-ai-app-conversations
- パーティションキー: user_id (S)
- ソートキー: conversation_id (S)
- 課金モード: PAY_PER_REQUEST（dev）、PROVISIONED（prod、変数で切替）
- TTL: expires_at カラム
- GSI: conversation_id-index（conversation_id をパーティションキー）
- Point-in-Time Recovery: 有効
- 暗号化: AWS Managed Key
- DynamoDB Streams: NEW_AND_OLD_IMAGES（将来の分析パイプライン用）

■ S3 バケット
- 用途1: Lambda デプロイパッケージ格納
- 用途2: RAG 用ドキュメント格納（将来の Knowledge Base 連携用）
- 共通設定:
  - バージョニング有効
  - SSE-KMS 暗号化
  - パブリックアクセス完全ブロック
  - ライフサイクル: 90日後に Glacier Instant Retrieval（ドキュメントバケットのみ）
```

---

## 5. Phase 5 — 監視・運用

### プロンプト 5-1: モニタリング

```
modules/monitoring/ を作成してください。

- CloudWatch Alarms:
  - Lambda エラー率 > 5%（5分間）→ SNS 通知
  - Lambda 実行時間 p99 > 25秒 → SNS 通知
  - API Gateway 5xx > 10回/5分 → SNS 通知
  - DynamoDB ThrottledRequests > 0 → SNS 通知
- CloudWatch Dashboard:
  - Lambda: Invocations, Errors, Duration (p50/p99)
  - API Gateway: Count, 4xx, 5xx, Latency
  - DynamoDB: ConsumedRCU/WCU, ThrottledRequests
  - Bedrock: InvocationCount, InvocationLatency（※カスタムメトリクス）
- X-Ray トレーシング:
  - Lambda: Active tracing 有効
  - API Gateway: X-Ray tracing 有効
- SNS トピック: ${env}-ai-app-alerts（メール通知先は変数化）
```

---

## 6. Phase 6 — 環境統合と plan 実行

### プロンプト 6-1: dev 環境の統合

```
envs/dev/ に以下を構成してください:
1. backend.tf: S3 バックエンド（バケット名とDynamoDB テーブル名は変数化）
2. main.tf: 全モジュールの呼び出し
3. variables.tf: 全変数の定義
4. terraform.tfvars: dev 環境の具体値
5. outputs.tf: API Gateway の URL、Lambda 関数名など主要な出力

構成後、以下を実行してください:
1. terraform fmt -recursive
2. terraform validate
3. terraform plan -out=tfplan
4. plan の結果を要約して報告（作成/変更/削除されるリソース数と主要リソース一覧）
```

### プロンプト 6-2: plan 結果からの IAM ポリシー生成（CI/CD 用）

```
先ほどの terraform plan の結果を読んで、
GitHub Actions で terraform apply を実行するための
最小権限 IAM ポリシーを生成してください。

要件:
- OIDC 連携で AssumeRole する設計
- 各 Action に対して、なぜその権限が必要かをコメントで記載
- 不要な権限は含めない
- Condition で GitHub リポジトリと ref を制限
```

---

## 7. 便利な単発プロンプト集

### セキュリティ監査
```
このプロジェクトの Terraform コード全体を CIS AWS Foundations Benchmark v3.0 に照らしてレビューしてください。
問題点と修正パッチを優先度（Critical/High/Medium/Low）付きで報告してください。
```

### コスト見積もり
```
envs/dev/ の terraform plan 結果から、月間コストの概算を出してください。
各リソースの単価と想定利用量（1日あたり API コール 1000回、平均レスポンス 2KB）を前提にしてください。
```

### ドキュメント生成
```
このプロジェクトの全モジュールに対して terraform-docs 形式の README.md を自動生成してください。
各モジュールのディレクトリに配置し、inputs/outputs/resources の一覧を含めてください。
```

### 既存リソースの Import
```
既存の VPC (vpc-0123456789abcdef0) を modules/networking に import するための
terraform import コマンドと、対応する HCL コードを生成してください。
state の整合性を確認する plan も実行してください。
```

### マルチクラウド展開（将来）
```
modules/ai/ を抽象化して、AWS Bedrock と GCP Vertex AI の両方に対応できる
インターフェースモジュールを設計してください。
Provider の切り替えは変数 cloud_provider = "aws" | "gcp" で行います。
```

---

## 付録: プロンプト設計のコツ

### ✅ 良いプロンプトの特徴
1. **具体的なリソース名と設定値**を含める（CIDR、メモリサイズ、タイムアウト等）
2. **セキュリティ要件を明示**する（「* は使わない」「最小権限で」）
3. **MCP Server の活用を指示**する（「最新バージョンを確認して」）
4. **出力形式を指定**する（「variables.tf / main.tf / outputs.tf に分割して」）
5. **やらないことも書く**（「auto-approve は使わない」「Provisioned は不要」）

### ❌ 避けるべきプロンプト
- 「AWS で Bedrock の環境を作って」→ 曖昧すぎて汎用的なコードが出る
- 「セキュリティも考慮して」→ 具体的な基準がないと中途半端になる
- 「とりあえず動くものを」→ Skill なしだと全部 main.tf に詰め込まれる

### 🔄 AI-DLC ループの実践
1. Claude Code に **Plan モード** で計画を出させる
2. 人間が **アーキテクチャ判断** を行う（NAT は1つ？2つ？認証方式は？）
3. Claude Code が **実装を実行**し、validate/plan まで自動で回す
4. 人間が **plan 結果をレビュー**して apply を承認
5. エラー時は Claude Code が **自動修正→再 plan** を繰り返す
