use reqwest::Client;
use serde::{Deserialize, Serialize};

pub struct LlmClient {
    client: Client,
    base_url: String,
}

#[derive(Debug, Serialize, Deserialize)]
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

impl LlmClient {
    pub fn new(base_url: &str) -> Self {
        Self {
            client: Client::new(),
            base_url: base_url.to_string(),
        }
    }

    pub async fn chat(&self, prompt: &str) -> Result<String, String> {
        let request = ChatRequest {
            model: "mock-llm".to_string(),
            messages: vec![
                Message {
                    role: "user".to_string(),
                    content: prompt.to_string(),
                }
            ],
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
