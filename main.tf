resource "aws_iam_role" "lambda_role" {
    name = "aiops_lambda_excecution_role"

    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Action = "sts:AssumeRole"
                Effect = "Allow"
                Principal = {
                    Service = "lambda.amazonaws.com"
                }
            }
        ]
    })
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
    role = aws_iam_role.lambda_role.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "archive_file" "lambda_zip" {
    type = "zip"
    source_dir = "${path.module}/src"
    output_path = "${path.module}/src/lambda_function.zip"
}

resource "aws_lambda_function" "aiops_analyze" {
    filename = data.archive_file.lambda_zip.output_path
    function_name = "aiops_log_analyzer"
    role = aws_iam_role.lambda_role.arn
    handler = "lambda_function.lambda_handler"
    runtime = "python3.11"
    timeout = 30

    source_code_hash = data.archive_file.lambda_zip.output_base64sha256

    environment {
      variables = {
        GEMINI_API_KEY = var.gemini_api_key
        TELEGRAM_BOT_TOKEN = var.telegram_bot_token
        TELEGRAM_CHAT_ID = var.telegram_chat_id
      }
    }
}

resource "aws_cloudwatch_log_group" "simulated_logs" {
    name = "/aws/aiops/simulated_app_logs"
    retention_in_days = 7
}

resource "aws_cloudwatch_log_metric_filter" "error_filter" {
    name = "ErrorLogFilter"
    pattern = "ERROR"
    log_group_name = aws_cloudwatch_log_group.simulated_logs.name

    metric_transformation {
      name = "ErrorCount"
      namespace = "AiOpsMetrics"
      value = "1" 
    }
}

resource "aws_cloudwatch_metric_alarm" "error_alarm" {
    alarm_name          = "AIOps_Error_Spike_Alarm"
    comparison_operator = "GreaterThanOrEqualToThreshold"
    evaluation_periods  = 1
    metric_name         = "ErrorCount"
    namespace           = "AiOpsMetrics" 
    period              = 60
    statistic           = "Sum"
    threshold           = 1 
    alarm_description   = "Alarm ini menyala jika ada log ERROR pada aplikasi."
}

resource "aws_cloudwatch_event_rule" "alarm_rule" {
    name = "capture-cw-alarm-state-change"
    description = "Memicu Lambda saat alarm AIOps menyala"

    event_pattern = jsonencode({
        source = ["aws.cloudwatch"]
        "detail-type" = ["CloudWatch Alarm State Change"]
        detail = {
            alarmName = [aws_cloudwatch_metric_alarm.error_alarm.alarm_name]
            state = {
                value = ["ALARM"]
            }
        }
    })
}

resource "aws_cloudwatch_event_target" "lambda_target" {
    rule = aws_cloudwatch_event_rule.alarm_rule.name
    target_id = "SendToLambda"
    arn = aws_lambda_function.aiops_analyze.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
    statement_id = "AllowExecutionFromEventBridge"
    action        = "lambda:InvokeFunction"
    function_name = aws_lambda_function.aiops_analyze.function_name
    principal     = "events.amazonaws.com"
    source_arn    = aws_cloudwatch_event_rule.alarm_rule.arn
}