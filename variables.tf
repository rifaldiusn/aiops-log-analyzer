variable "aws_region"{
    type = string
    description = "region aws"
    default = "us-east-1"
}

variable "gemini_api_key" {
    type = string
    description = "Gemini API Key"
    sensitive = true
}

variable "telegram_bot_token" {
    type = string
    description = "Telegram Bot Token"
    sensitive = true
}

variable "telegram_chat_id" {
    type = string
    description = "chat id telegram penerima"
    sensitive = true
}