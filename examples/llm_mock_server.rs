use std::net::SocketAddr;
use axum::{
    extract::Json,
    routing::post,
    Router,
};
use serde::{Deserialize, Serialize};
use tokio::net::TcpListener;

#[derive(Debug, Deserialize)]
struct ChatRequest {
    model: String,
    messages: Vec<Message>,
    stream: Option<bool>,
}

#[derive(Debug, Deserialize, Serialize)]
struct Message {
    role: String,
    content: String,
}

#[derive(Debug, Serialize)]
struct ChatResponse {
    model: String,
    message: Message,
    done: bool,
}

async fn chat(Json(req): Json<ChatRequest>) -> Json<ChatResponse> {
    let last_message = req.messages.last()
        .map(|m| m.content.clone())
        .unwrap_or_default();

    let response = generate_response(&last_message);

    Json(ChatResponse {
        model: req.model,
        message: Message {
            role: "assistant".to_string(),
            content: response,
        },
        done: true,
    })
}

fn generate_response(input: &str) -> String {
    let input_lower = input.to_lowercase();

    if input_lower.contains("分析") || input_lower.contains("预测") {
        format!(
            "基于当前数据，对\"{}\"的分析如下：\n\
            1. 关键发现：数据呈现增长趋势\n\
            2. 风险评估：中等级别\n\
            3. 建议行动：持续监控并准备应急方案\n\
            \n\
            以上分析基于多源数据融合得出。",
            input
        )
    } else if input_lower.contains("hello") || input_lower.contains("hi") {
        "Hello! 我是 Agent-02，一个基于联邦学习的AI助手。有什么可以帮助您的？".to_string()
    } else if input_lower.contains("who") && input_lower.contains("you") {
        "我是 OpenClaw × Hermes 联邦协作框架中的 Agent-02，专注于语言理解和分析任务。".to_string()
    } else {
        format!(
            "收到您的请求: \"{}\"\n\
            \n\
            根据您的问题，我的分析和建议如下：\n\
            - 这是一个有效的查询\n\
            - 可以提供相关的知识和帮助\n\
            - 如需更多信息，请提供更多细节\n\
            \n\
            来自 Agent-02 的问候！",
            input
        )
    }
}

#[tokio::main]
async fn main() {
    let addr = SocketAddr::from(([127, 0, 0, 1], 8080));
    println!("🚀 LLM Mock Server starting on http://{}", addr);

    let app = Router::new()
        .route("/api/chat", post(chat));

    let listener = TcpListener::bind(addr).await.unwrap();
    println!("✅ LLM Mock Server ready!");

    axum::serve(listener, app).await.unwrap();
}
