//! OpenClaw 自主任务编排器 (Autonomous Orchestrator)
//!
//! 目标驱动的多 Agent 协作框架，实现：
//! 1. 目标分解 - 将复杂目标分解为可执行子任务
//! 2. 计划执行 - 自动选择 Agent 并执行任务
//! 3. 自我评估 - 验证结果并决定是否重试
//! 4. 联邦学习 - 自动聚合知识 Delta

use crate::net::{AgentClient, AgentRegistry};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use tracing::{info, warn, error};

/// 任务状态
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum TaskStatus {
    Pending,
    InProgress,
    Completed,
    Failed,
    Retrying,
}

/// 子任务定义
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SubTask {
    pub id: String,
    pub description: String,
    pub target_agent: Option<String>,
    pub skill: Option<String>,
    pub args: HashMap<String, String>,
    pub status: TaskStatus,
    pub result: Option<String>,
    pub retry_count: u32,
    pub max_retries: u32,
}

impl SubTask {
    pub fn new(id: &str, description: &str) -> Self {
        Self {
            id: id.to_string(),
            description: description.to_string(),
            target_agent: None,
            skill: None,
            args: HashMap::new(),
            status: TaskStatus::Pending,
            result: None,
            retry_count: 0,
            max_retries: 3,
        }
    }

    pub fn with_agent(mut self, agent: &str, skill: &str) -> Self {
        self.target_agent = Some(agent.to_string());
        self.skill = Some(skill.to_string());
        self
    }
}

/// 执行计划
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ExecutionPlan {
    pub goal: String,
    pub sub_tasks: Vec<SubTask>,
    pub dependencies: HashMap<String, Vec<String>>,
    pub current_index: usize,
}

impl ExecutionPlan {
    pub fn new(goal: &str) -> Self {
        Self {
            goal: goal.to_string(),
            sub_tasks: Vec::new(),
            dependencies: HashMap::new(),
            current_index: 0,
        }
    }

    pub fn add_task(&mut self, task: SubTask) -> &mut SubTask {
        self.sub_tasks.push(task);
        self.sub_tasks.last_mut().unwrap()
    }

    pub fn add_dependency(&mut self, task_id: &str, depends_on: &str) {
        self.dependencies
            .entry(task_id.to_string())
            .or_insert_with(Vec::new)
            .push(depends_on.to_string());
    }

    pub fn next_ready_task(&self) -> Option<usize> {
        for (i, task) in self.sub_tasks.iter().enumerate() {
            if task.status != TaskStatus::Pending {
                continue;
            }

            // 检查依赖是否都完成
            let deps = self.dependencies.get(&task.id);
            let all_deps_done = deps.map(|d| {
                d.iter().all(|dep_id| {
                    self.sub_tasks.iter().any(|t| t.id == *dep_id && t.status == TaskStatus::Completed)
                })
            }).unwrap_or(true);

            if all_deps_done {
                return Some(i);
            }
        }
        None
    }

    pub fn is_complete(&self) -> bool {
        self.sub_tasks.iter().all(|t| t.status == TaskStatus::Completed)
    }

    pub fn has_failures(&self) -> bool {
        self.sub_tasks.iter().any(|t| t.status == TaskStatus::Failed)
    }
}

/// 执行结果
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ExecutionResult {
    pub success: bool,
    pub plan: ExecutionPlan,
    pub federated_delta: Option<Vec<u8>>,
    pub total_tasks: usize,
    pub completed_tasks: usize,
    pub failed_tasks: usize,
}

/// 目标分解策略
pub struct GoalPlanner;

impl GoalPlanner {
    /// 根据目标自动分解子任务
    pub fn decompose(goal: &str) -> ExecutionPlan {
        let mut plan = ExecutionPlan::new(goal);
        let goal_lower = goal.to_lowercase();

        // 关键词匹配策略
        if goal_lower.contains("预测") || goal_lower.contains("forecast") || goal_lower.contains("predict") {
            Self::decompose_forecast_task(&mut plan, goal);
        } else if goal_lower.contains("分析") || goal_lower.contains("analyze") {
            Self::decompose_analysis_task(&mut plan, goal);
        } else if goal_lower.contains("报告") || goal_lower.contains("report") {
            Self::decompose_report_task(&mut plan, goal);
        } else if goal_lower.contains("安全") || goal_lower.contains("security") {
            Self::decompose_security_task(&mut plan, goal);
        } else {
            Self::decompose_general_task(&mut plan, goal);
        }

        plan
    }

    fn decompose_forecast_task(plan: &mut ExecutionPlan, goal: &str) {
        // 1. 数据收集 - Hermes
        let mut task1 = SubTask::new("data_collection", "收集相关领域数据");
        task1.target_agent = Some("agent_02".to_string());
        task1.skill = Some("analyze_context".to_string());
        task1.args.insert("topic".to_string(), goal.to_string());
        task1.args.insert("scope".to_string(), "comprehensive".to_string());
        plan.add_task(task1);

        // 2. 数据处理 - OpenClaw
        let mut task2 = SubTask::new("data_processing", "处理和分析数据");
        task2.target_agent = Some("agent_01".to_string());
        task2.skill = Some("process_data".to_string());
        plan.add_task(task2);
        plan.add_dependency("data_processing", "data_collection");

        // 3. 模式识别 - OpenClaw
        let mut task3 = SubTask::new("pattern_recognition", "识别趋势和模式");
        task3.target_agent = Some("agent_01".to_string());
        task3.skill = Some("detect_objects".to_string());
        plan.add_task(task3);
        plan.add_dependency("pattern_recognition", "data_processing");

        // 4. 报告生成 - Hermes
        let mut task4 = SubTask::new("report_generation", "生成预测报告");
        task4.target_agent = Some("agent_02".to_string());
        task4.skill = Some("generate_response".to_string());
        plan.add_task(task4);
        plan.add_dependency("report_generation", "pattern_recognition");

        // 5. 翻译整理 - Hermes
        let mut task5 = SubTask::new("translation", "翻译和整理最终报告");
        task5.target_agent = Some("agent_02".to_string());
        task5.skill = Some("translate_text".to_string());
        plan.add_task(task5);
        plan.add_dependency("translation", "report_generation");
    }

    fn decompose_analysis_task(plan: &mut ExecutionPlan, goal: &str) {
        // 1. 上下文分析 - Hermes
        let mut task1 = SubTask::new("context_analysis", "分析任务上下文");
        task1.target_agent = Some("agent_02".to_string());
        task1.skill = Some("analyze_context".to_string());
        task1.args.insert("text".to_string(), goal.to_string());
        plan.add_task(task1);

        // 2. 数据摘要 - OpenClaw
        let mut task2 = SubTask::new("data_summarize", "生成摘要");
        task2.target_agent = Some("agent_01".to_string());
        task2.skill = Some("summarize_pdf".to_string());
        plan.add_task(task2);
        plan.add_dependency("data_summarize", "context_analysis");

        // 3. 结果生成 - Hermes
        let mut task3 = SubTask::new("result_generation", "生成分析结果");
        task3.target_agent = Some("agent_02".to_string());
        task3.skill = Some("generate_response".to_string());
        plan.add_task(task3);
        plan.add_dependency("result_generation", "data_summarize");
    }

    fn decompose_report_task(plan: &mut ExecutionPlan, goal: &str) {
        // 1. 文档分析 - OpenClaw
        let mut task1 = SubTask::new("doc_analysis", "分析和汇总文档");
        task1.target_agent = Some("agent_01".to_string());
        task1.skill = Some("summarize_pdf".to_string());
        plan.add_task(task1);

        // 2. 内容生成 - Hermes
        let mut task2 = SubTask::new("content_generation", "生成报告内容");
        task2.target_agent = Some("agent_02".to_string());
        task2.skill = Some("generate_response".to_string());
        plan.add_task(task2);
        plan.add_dependency("content_generation", "doc_analysis");
    }

    fn decompose_security_task(plan: &mut ExecutionPlan, goal: &str) {
        // 合规检查任务
        let mut task1 = SubTask::new("security_check", "执行安全检查");
        task1.target_agent = Some("agent_01".to_string());
        task1.skill = Some("detect_objects".to_string());
        task1.args.insert("mode".to_string(), "security".to_string());
        plan.add_task(task1);

        let mut task2 = SubTask::new("risk_assessment", "风险评估");
        task2.target_agent = Some("agent_02".to_string());
        task2.skill = Some("analyze_context".to_string());
        plan.add_task(task2);
        plan.add_dependency("risk_assessment", "security_check");
    }

    fn decompose_general_task(plan: &mut ExecutionPlan, goal: &str) {
        // 通用任务：分析 + 生成
        let mut task1 = SubTask::new("general_analysis", "执行通用分析");
        task1.target_agent = Some("agent_02".to_string());
        task1.skill = Some("analyze_context".to_string());
        task1.args.insert("task".to_string(), goal.to_string());
        plan.add_task(task1);

        let mut task2 = SubTask::new("general_response", "生成响应");
        task2.target_agent = Some("agent_02".to_string());
        task2.skill = Some("generate_response".to_string());
        plan.add_task(task2);
        plan.add_dependency("general_response", "general_analysis");
    }
}

/// 计划执行器
pub struct PlanExecutor {
    coordinator_addr: String,
}

impl PlanExecutor {
    pub fn new(coordinator_addr: &str) -> Self {
        Self {
            coordinator_addr: coordinator_addr.to_string(),
        }
    }

    /// 执行单个子任务
    pub async fn execute_task(&self, task: &mut SubTask) -> Result<String, String> {
        info!(
            task_id = %task.id,
            agent = ?task.target_agent,
            skill = ?task.skill,
            event = "task_execution_start",
            "Starting task execution"
        );

        let agent_id = task.target_agent.as_ref().ok_or("No target agent specified")?;
        let skill = task.skill.as_ref().ok_or("No skill specified")?;

        // 1. 发现目标 Agent 地址
        let agent_addr = self.discover_agent(agent_id).await?;

        // 2. 构建参数
        let args = serde_json::to_string(&task.args)
            .unwrap_or_else(|_| "{}".to_string());

        // 3. 调用 Agent 技能 (地址已经是完整URL格式)
        let mut client = AgentClient::connect(agent_addr)
            .await
            .map_err(|e| format!("Failed to connect: {}", e))?;

        let result = client
            .call_skill(agent_id, skill, &args)
            .await
            .map_err(|e| format!("Skill call failed: {}", e))?;

        let result_str = &result.result_json;
        info!(
            task_id = %task.id,
            result_preview = %result_str.chars().take(100).collect::<String>(),
            event = "task_execution_complete",
            "Task execution completed"
        );

        Ok(result_str.clone())
    }

    /// 发现 Agent 地址
    async fn discover_agent(&self, agent_id: &str) -> Result<String, String> {
        let coordinator_url = if self.coordinator_addr.starts_with("http") {
            self.coordinator_addr.clone()
        } else {
            format!("http://{}", self.coordinator_addr)
        };

        let mut client = AgentClient::connect(coordinator_url)
            .await
            .map_err(|e| format!("Failed to connect to coordinator: {}", e))?;

        let response = client
            .get_agent(agent_id)
            .await
            .map_err(|e| format!("Get agent failed: {}", e))?;

        let agent = response.agent
            .ok_or_else(|| format!("Agent {} not found", agent_id))?;

        tracing::info!(
            agent_id = %agent_id,
            returned_agent_id = %agent.agent_id,
            returned_address = %agent.address,
            returned_port = agent.port,
            returned_skills = ?agent.skills,
            event = "agent_info_retrieved",
            "Retrieved agent info from coordinator"
        );

        let addr = if agent.address.contains(':') {
            format!("http://[{}]:{}", agent.address, agent.port)
        } else {
            format!("http://{}:{}", agent.address, agent.port)
        };

        info!(
            agent_id = %agent_id,
            address = %addr,
            event = "agent_discovered",
            "Agent discovered"
        );

        Ok(addr)
    }
}

/// 自我评估器
pub struct SelfEvaluator {
    quality_threshold: f32,
}

impl SelfEvaluator {
    pub fn new(quality_threshold: f32) -> Self {
        Self { quality_threshold }
    }

    /// 评估任务结果
    pub fn evaluate(&self, task: &SubTask, result: &str) -> EvaluationResult {
        let score = self.calculate_score(task, result);

        EvaluationResult {
            passed: score >= self.quality_threshold,
            score,
            feedback: self.generate_feedback(task, result, score),
            should_retry: score < self.quality_threshold && task.retry_count < task.max_retries,
        }
    }

    fn calculate_score(&self, task: &SubTask, result: &str) -> f32 {
        let mut score = 0.0;

        // 基础分数：结果非空
        if !result.is_empty() {
            score += 0.2;
        }

        // JSON 格式检查
        if result.trim().starts_with('{') || result.trim().starts_with('[') {
            score += 0.3;
        }

        // 状态检查
        if result.contains("success") || result.contains("processed") || result.contains("completed") {
            score += 0.3;
        }

        // 结果长度合理性
        let len = result.len();
        if len > 10 && len < 100000 {
            score += 0.2;
        }

        score
    }

    fn generate_feedback(&self, task: &SubTask, result: &str, score: f32) -> String {
        if score >= 0.8 {
            format!("Task '{}' completed with high quality (score: {:.2})", task.id, score)
        } else if score >= 0.5 {
            format!("Task '{}' completed with medium quality (score: {:.2})", task.id, score)
        } else {
            format!(
                "Task '{}' needs improvement (score: {:.2}). Result preview: {}",
                task.id,
                score,
                &result.chars().take(50).collect::<String>()
            )
        }
    }
}

/// 评估结果
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EvaluationResult {
    pub passed: bool,
    pub score: f32,
    pub feedback: String,
    pub should_retry: bool,
}

/// 自主编排器主类
pub struct AutonomousOrchestrator {
    planner: GoalPlanner,
    executor: PlanExecutor,
    evaluator: SelfEvaluator,
}

impl AutonomousOrchestrator {
    pub fn new(coordinator_addr: &str) -> Self {
        Self {
            planner: GoalPlanner,
            executor: PlanExecutor::new(coordinator_addr),
            evaluator: SelfEvaluator::new(0.6),
        }
    }

    /// 执行自主任务流
    pub async fn execute(&self, goal: &str) -> ExecutionResult {
        info!(
            goal = %goal,
            event = "orchestration_start",
            "Starting autonomous orchestration"
        );

        // 1. 目标分解
        let mut plan = GoalPlanner::decompose(goal);
        info!(
            task_count = plan.sub_tasks.len(),
            event = "goal_decomposed",
            "Goal decomposed into tasks"
        );

        // 2. 执行计划
        let mut completed = 0;
        let mut failed = 0;
        let mut federated_delta: Vec<u8> = Vec::new();

        while let Some(idx) = plan.next_ready_task() {
            let task_result = self.execute_subtask(&mut plan.sub_tasks[idx], &mut federated_delta).await;

            match task_result {
                Ok(_) => {
                    completed += 1;
                }
                Err(e) => {
                    error!(
                        task_id = %plan.sub_tasks[idx].id,
                        error = %e,
                        event = "task_failed",
                        "Task execution failed"
                    );
                    failed += 1;

                    // 如果失败且可重试，标记为待重试
                    if plan.sub_tasks[idx].retry_count < plan.sub_tasks[idx].max_retries {
                        plan.sub_tasks[idx].status = TaskStatus::Retrying;
                    } else {
                        plan.sub_tasks[idx].status = TaskStatus::Failed;
                    }
                }
            }
        }

        let total_tasks = plan.sub_tasks.len();
        let success = plan.is_complete() && !plan.has_failures();

        info!(
            success = %success,
            completed = completed,
            failed = failed,
            total = total_tasks,
            event = "orchestration_complete",
            "Orchestration completed"
        );

        ExecutionResult {
            success,
            plan,
            federated_delta: if federated_delta.is_empty() { None } else { Some(federated_delta) },
            total_tasks,
            completed_tasks: completed,
            failed_tasks: failed,
        }
    }

    async fn execute_subtask(
        &self,
        task: &mut SubTask,
        federated_delta: &mut Vec<u8>,
    ) -> Result<String, String> {
        task.status = TaskStatus::InProgress;

        // 执行任务
        let result = self.executor.execute_task(task).await?;

        // 评估结果
        let eval = self.evaluator.evaluate(task, &result);

        if eval.should_retry {
            warn!(
                task_id = %task.id,
                retry_count = task.retry_count,
                score = eval.score,
                event = "task_retrying",
                "Task needs retry"
            );
            task.retry_count += 1;
            task.status = TaskStatus::Retrying;
            return Err(eval.feedback);
        }

        // 记录结果
        task.result = Some(result.clone());
        task.status = TaskStatus::Completed;

        // 生成联邦学习 Delta
        let delta = format!(
            "DELTA:{}:{}",
            task.id,
            serde_json::to_string(&result).unwrap_or_default()
        );
        federated_delta.extend(delta.as_bytes());

        info!(
            task_id = %task.id,
            score = eval.score,
            feedback = %eval.feedback,
            event = "task_evaluated",
            "Task evaluated"
        );

        Ok(result)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_goal_planner_forecast() {
        let plan = GoalPlanner::decompose("预测全球 AI 发展趋势");
        assert!(!plan.sub_tasks.is_empty());
        assert!(plan.sub_tasks.iter().any(|t| t.id == "data_collection"));
        assert!(plan.sub_tasks.iter().any(|t| t.id == "report_generation"));
    }

    #[test]
    fn test_plan_execution_order() {
        let mut plan = GoalPlanner::decompose("分析市场数据并生成报告");

        // 第一个ready的任务应该是 data_collection
        assert_eq!(plan.next_ready_task(), Some(0));

        // 完成后第二个应该是 doc_analysis
        plan.sub_tasks[0].status = TaskStatus::Completed;
        // doc_analysis 依赖 context_analysis，所以还是 pending
    }
}
