use clawfed::llm_integration::call_llm_sync;

fn main() {
    println!("🧪 Testing LLM Integration\n");

    println!("1️⃣ Testing analyze_context skill:");
    let result1 = call_llm_sync("analyze_context", r#"{"data": "test data", "context": "analysis"}"#);
    println!("Result: {}\n", result1);

    println!("2️⃣ Testing generate_response skill:");
    let result2 = call_llm_sync("generate_response", r#"{"analysis": "positive trend", "confidence": 0.85}"#);
    println!("Result: {}\n", result2);

    println!("3️⃣ Testing translate_text skill:");
    let result3 = call_llm_sync("translate_text", "Hello, how are you?");
    println!("Result: {}\n", result3);

    println!("4️⃣ Testing summarize_pdf skill:");
    let result4 = call_llm_sync("summarize_pdf", r#"{"title": "Annual Report 2024", "pages": 50}"#);
    println!("Result: {}\n", result4);

    println!("✅ LLM Integration Test Complete!");
}
