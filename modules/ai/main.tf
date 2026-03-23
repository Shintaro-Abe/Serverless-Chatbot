################################################################################
# Bedrock Model Access 確認
#
# Terraform では Bedrock Model Access を有効化できないため、
# terraform_data + local-exec で有効化状況を確認し、
# 未有効化の場合はエラーメッセージを出力する。
################################################################################

# モデル ID が変更されたときにチェックを再実行するためのトリガー
resource "terraform_data" "bedrock_model_id_trigger" {
  input = var.bedrock_model_id
}

resource "terraform_data" "bedrock_model_access_check" {
  provisioner "local-exec" {
    command = <<-EOT
      echo "========================================="
      echo "Checking Bedrock model access: ${var.bedrock_model_id}"
      echo "========================================="

      MODEL_STATUS=$(aws bedrock get-foundation-model \
        --model-identifier "${var.bedrock_model_id}" \
        --region "${var.aws_region}" \
        --query 'modelDetails.modelLifecycle.status' \
        --output text 2>/dev/null || echo "UNKNOWN")

      ACCESS_STATUS=$(aws bedrock list-foundation-models \
        --region "${var.aws_region}" \
        --query "modelSummaries[?modelId=='${var.bedrock_model_id}'].modelLifecycle.status" \
        --output text 2>/dev/null || echo "UNKNOWN")

      echo "Model Status: $MODEL_STATUS"
      echo "Access Status: $ACCESS_STATUS"

      if [ "$MODEL_STATUS" = "UNKNOWN" ] && [ "$ACCESS_STATUS" = "UNKNOWN" ]; then
        echo ""
        echo "ERROR: Bedrock model '${var.bedrock_model_id}' のアクセスを確認できません。"
        echo "以下を手動で実施してください:"
        echo "  1. AWS Console > Amazon Bedrock > Model access"
        echo "  2. '${var.bedrock_model_id}' のアクセスを有効化"
        echo "  3. リージョン: ${var.aws_region}"
        echo ""
        echo "※ AWS CLI 認証情報が設定されていない場合もこのエラーが発生します。"
        exit 1
      fi

      echo "Bedrock model access check passed."
    EOT
  }

  lifecycle {
    replace_triggered_by = [terraform_data.bedrock_model_id_trigger]
  }
}

################################################################################
# Bedrock Model ARN（他モジュール参照用）
################################################################################

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  # 推論プロファイル ID（apac. / global. 等のプレフィックスあり）の場合は inference-profile ARN を使用
  is_inference_profile = can(regex("^(apac|global|jp|us|eu)\\.", var.bedrock_model_id))
  bedrock_model_arn    = local.is_inference_profile ? "arn:${data.aws_partition.current.partition}:bedrock:${var.aws_region}:${data.aws_caller_identity.current.account_id}:inference-profile/${var.bedrock_model_id}" : "arn:${data.aws_partition.current.partition}:bedrock:${var.aws_region}::foundation-model/${var.bedrock_model_id}"
}
