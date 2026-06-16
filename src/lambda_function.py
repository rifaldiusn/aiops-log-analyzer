import json
import os
import urllib.request
import urllib.error

def lambda_handler(event, context):
    gemini_key = os.environ.get("GEMINI_API_KEY")
    telegram_token = os.environ.get("TELEGRAM_BOT_TOKEN")
    telegram_chat_id = os.environ.get("TELEGRAM_CHAT_ID")

    print("Received event:", json.dumps(event))
    error_message = event.get("message", "Simulasi: Terjadi spike CPU di atas 90% pada instance EC2-Production")

    ai_analysis = analyze_with_gemini(error_message, gemini_key)
    send_to_telegram(ai_analysis, telegram_token, telegram_chat_id)

    return {
        'statusCode': 200,
        'body': json.dumps('Alert processed successfully')
    }

def analyze_with_gemini(log_content, api_key):
    url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key={api_key}"

    prompt = (
        "Kamu adalah seorang Senior DevOps Engineer. Analisis log error berikut ini. "
        "Jelaskan penyebab utamanya secara singkat dalam bahasa Indonesia (maksimal 2 paragraf), "
        "lalu berikan maksimal 3 langkah perbaikan taktis yang bisa langsung dilakukan.\n\n"
        f"LOG ERROR:\n{log_content}"
    )

    headers = {"Content-Type": "application/json"}
    data = {
        "contents": [{
            "parts": [{"text": prompt}]
        }]
    }

    req = urllib.request.Request(url, data=json.dumps(data).encode("utf-8"), headers=headers, method="POST")
    try:
        with urllib.request.urlopen(req) as response:
            res_body = json.loads(response.read().decode("utf-8"))
            ai_text = res_body["candidates"][0]["content"]["parts"][0]["text"]
            return ai_text
    except urllib.error.HTTPError as e:
        print(f"Gemini API Error: {e.read().decode('utf-8')}")
        return f"Gagal menganalisis log menggunakan Gemini. Error code: {e.code}"
    except Exception as e:
        print(f"General Error: {str(e)}")
        return "Terjadi kesalahan koneksi saat menghubungi Gemini API."

def send_to_telegram(message, token, chat_id):
    url = f"https://api.telegram.org/bot{token}/sendMessage"

    payload = {
        "chat_id": chat_id,
        "text": f"AiOps Alert Analysis:\n\n{message}",
        "parse_mode": "Markdown"
    }

    headers = {"Content-Type": "application/json"}
    req = urllib.request.Request(url, data=json.dumps(payload).encode("utf-8"), headers=headers, method="POST")
    try:
        with urllib.request.urlopen(req) as response:
            print("Telegram response:", response.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        print(f"Telegram API Error: {e.read().decode('utf-8')}")
    except Exception as e:
        print(f"General Error: {str(e)}")