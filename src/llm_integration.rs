use reqwest::Client;
use serde::{Deserialize, Serialize};
use std::time::Duration;

pub struct LlmService {
    client: Client,
    base_url: String,
    timeout: Duration,
}

#[derive(Debug, Serialize)]
struct ChatRequest {
    model: String,
    messages: Vec<Message>,
}

#[derive(Debug, Serialize, Deserialize)]
struct Message {
    role: String,
    content: String,
}

#[derive(Debug, Deserialize)]
struct ChatResponse {
    message: Message,
}

impl LlmService {
    pub fn new(base_url: &str) -> Self {
        Self {
            client: Client::builder()
                .timeout(Duration::from_secs(30))
                .build()
                .unwrap_or_default(),
            base_url: base_url.to_string(),
            timeout: Duration::from_secs(30),
        }
    }

    pub async fn chat(&self, prompt: &str) -> Result<String, String> {
        let request = ChatRequest {
            model: "agent-02".to_string(),
            messages: vec![Message {
                role: "user".to_string(),
                content: prompt.to_string(),
            }],
        };

        let response = self.client
            .post(format!("{}/api/chat", self.base_url))
            .json(&request)
            .send()
            .await
            .map_err(|e| format!("Request failed: {}", e))?;

        let chat_response: ChatResponse = response
            .json()
            .await
            .map_err(|e| format!("Parse failed: {}", e))?;

        Ok(chat_response.message.content)
    }
}

pub async fn call_llm(skill_name: &str, args_json: &str) -> String {
    let llm_url = std::env::var("LLM_URL").unwrap_or_else(|_| "http://127.0.0.1:8080".to_string());

    let prompt = match skill_name {
        "analyze_context" => {
            format!("请分析以下上下文并提供关键洞察: {}", args_json)
        }
        "generate_response" => {
            format!("基于以下分析结果生成回复: {}", args_json)
        }
        "translate_text" => {
            format!("翻译以下文本: {}", args_json)
        }
        "summarize_pdf" => {
            format!("总结以下文档内容: {}", args_json)
        }
        _ => {
            format!("处理技能 {} 的请求，参数: {}", skill_name, args_json)
        }
    };

    let llm = LlmService::new(&llm_url);
    match llm.chat(&prompt).await {
        Ok(response) => {
            serde_json::json!({
                "status": "success",
                "skill": skill_name,
                "response": response,
                "llm": "connected"
            })
            .to_string()
        }
        Err(e) => {
            tracing::warn!(error = %e, "LLM call failed, using fallback");
            serde_json::json!({
                "status": "fallback",
                "skill": skill_name,
                "error": e,
                "response": format!("LLM unavailable: {}", e)
            })
            .to_string()
        }
    }
}
