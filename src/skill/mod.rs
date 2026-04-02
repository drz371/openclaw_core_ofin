use anyhow::{Context, Result};
use serde_json::Value;
use std::collections::HashMap;
use tracing::{debug, error, info};

pub type SkillHandler = Box<dyn Fn(&str) -> Result<String> + Send + Sync>;

pub struct Skill {
    pub name: String,
    pub description: String,
    pub handler: Option<SkillHandler>,
}

impl Skill {
    pub fn new(name: String) -> Self {
        Self {
            name,
            description: String::new(),
            handler: None,
        }
    }

    pub fn with_description(mut self, description: String) -> Self {
        self.description = description;
        self
    }

    pub fn with_handler(mut self, handler: SkillHandler) -> Self {
        self.handler = Some(handler);
        self
    }

    pub fn execute(&self, args_json: &str) -> Result<String> {
        debug!(
            skill = %self.name,
            args = %args_json,
            event = "skill_execute",
            status = "executing",
            "Executing skill"
        );

        if let Some(handler) = &self.handler {
            let result = handler(args_json).context("Skill handler failed")?;
            info!(
                skill = %self.name,
                event = "skill_execute_success",
                status = "success",
                "Skill executed successfully"
            );
            Ok(result)
        } else {
            error!(
                skill = %self.name,
                event = "skill_execute_failed",
                status = "error",
                reason = "no_handler",
                "Skill has no handler"
            );
            Err(anyhow::anyhow!("Skill {} has no handler", self.name))
        }
    }
}

pub struct SkillRegistry {
    skills: HashMap<String, Skill>,
}

impl SkillRegistry {
    pub fn new() -> Self {
        Self {
            skills: HashMap::new(),
        }
    }

    pub fn register(&mut self, skill: Skill) {
        info!(
            skill = %skill.name,
            event = "skill_register",
            status = "registered",
            "Registering skill"
        );
        self.skills.insert(skill.name.clone(), skill);
    }

    pub fn get(&self, name: &str) -> Option<&Skill> {
        self.skills.get(name)
    }

    pub fn list(&self) -> Vec<String> {
        self.skills.keys().cloned().collect()
    }

    pub fn has_skill(&self, name: &str) -> bool {
        self.skills.contains_key(name)
    }
}

impl Default for SkillRegistry {
    fn default() -> Self {
        Self::new()
    }
}

pub fn create_default_skills() -> Vec<Skill> {
    vec![
        Skill::new("detect_objects".to_string())
            .with_description("Detect objects in images".to_string())
            .with_handler(Box::new(|args| {
                let _args: Value = serde_json::from_str(args)?;
                Ok(serde_json::json!({
                    "objects": [
                        {"class": "person", "confidence": 0.95},
                        {"class": "car", "confidence": 0.87}
                    ],
                    "count": 2
                }).to_string())
            })),
        Skill::new("summarize_pdf".to_string())
            .with_description("Summarize PDF documents".to_string())
            .with_handler(Box::new(|args| {
                let _args: Value = serde_json::from_str(args)?;
                Ok(serde_json::json!({
                    "summary": "Document summary generated",
                    "key_points": ["Point 1", "Point 2"],
                    "word_count": 150
                }).to_string())
            })),
        Skill::new("process_text".to_string())
            .with_description("Process and analyze text".to_string())
            .with_handler(Box::new(|args| {
                let _args: Value = serde_json::from_str(args)?;
                Ok(serde_json::json!({
                    "processed": true,
                    "tokens": 42,
                    "sentences": 3
                }).to_string())
            })),
    ]
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_skill_creation() {
        let skill = Skill::new("test_skill".to_string())
            .with_description("A test skill".to_string());
        assert_eq!(skill.name, "test_skill");
        assert_eq!(skill.description, "A test skill");
    }

    #[test]
    fn test_skill_execution() {
        let skill = Skill::new("test_skill".to_string())
            .with_handler(Box::new(|args| {
                let _args: Value = serde_json::from_str(args)?;
                Ok(serde_json::json!({"result": "success"}).to_string())
            }));

        let result = skill.execute(r#"{"input": "test"}"#);
        assert!(result.is_ok());
        let result_json: Value = serde_json::from_str(&result.unwrap()).unwrap();
        assert_eq!(result_json["result"], "success");
    }

    #[test]
    fn test_skill_registry() {
        let mut registry = SkillRegistry::new();
        let skill = Skill::new("test_skill".to_string());
        registry.register(skill);

        assert!(registry.has_skill("test_skill"));
        assert!(!registry.has_skill("nonexistent"));
    }

    #[test]
    fn test_default_skills() {
        let skills = create_default_skills();
        assert!(!skills.is_empty());
        assert!(skills.iter().any(|s| s.name == "detect_objects"));
    }
}
