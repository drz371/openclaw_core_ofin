#!/bin/bash
# OpenClaw 20-Minute Stability Test
# Uses real clawfed binary for gRPC service stability testing

set -e

DURATION_SECONDS=1200  # 20 minutes
LOG_DIR="logs/stability_test"
mkdir -p "$LOG_DIR"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$LOG_DIR/stability_test_${TIMESTAMP}.log"
CLAWFED="./target/release/clawfed"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE"; }

cleanup() {
    log_info "Stopping test services..."
    [ -n "$COORD_PID" ] && kill "$COORD_PID" 2>/dev/null || true
    [ -n "$AGENT_PID" ] && kill "$AGENT_PID" 2>/dev/null || true
    wait 2>/dev/null || true
    log_info "Services stopped."
}
trap cleanup EXIT

echo "========================================" | tee -a "$LOG_FILE"
echo "    OpenClaw 20-Minute Stability Test" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Stats
ITERATION=0
SKILL_CALLS=0
SKILL_ERRORS=0
COMPLIANCE_BLOCKED=0
COMPLIANCE_ERRORS=0
MEMORY_CHECKS=0
UPTIME_CHECKS=0
UPTIME_ERRORS=0

# Start coordinator
log_info "Starting coordinator server on port 50051..."
$CLAWFED server --addr "0.0.0.0:50051" --agent-id coordinator > "$LOG_DIR/coordinator.log" 2>&1 &
COORD_PID=$!
sleep 2

# Verify coordinator is running
if ! kill -0 "$COORD_PID" 2>/dev/null; then
    log_error "Coordinator failed to start!"
    exit 1
fi
log_success "Coordinator started (PID: $COORD_PID)"

# Start agent
log_info "Starting agent server on port 50052..."
$CLAWFED agent --config clawfed.toml --server --addr "0.0.0.0:50052" > "$LOG_DIR/agent.log" 2>&1 &
AGENT_PID=$!
sleep 2

# Verify agent is running
if ! kill -0 "$AGENT_PID" 2>/dev/null; then
    log_error "Agent failed to start!"
    exit 1
fi
log_success "Agent started (PID: $AGENT_PID)"

# Wait for gRPC to be ready
sleep 1
log_success "Services ready. Starting stability test..."
echo "" | tee -a "$LOG_FILE"

START_TIME=$(date +%s)
END_TIME=$((START_TIME + DURATION_SECONDS))

SKILLS=("detect_objects" "summarize_pdf" "unknown_skill" "process_data")

while [ "$(date +%s)" -lt "$END_TIME" ]; do
    ITERATION=$((ITERATION + 1))
    ELAPSED=$(( $(date +%s) - START_TIME ))
    REMAINING=$(( END_TIME - $(date +%s) ))
    
    # Convert to minutes
    ELAPSED_MIN=$((ELAPSED / 60))
    ELAPSED_SEC=$((ELAPSED % 60))
    REMAINING_MIN=$((REMAINING / 60))
    REMAINING_SEC=$((REMAINING % 60))
    
    log_info "========================================"
    log_info "Iteration #${ITERATION} | Elapsed: ${ELAPSED_MIN}m${ELAPSED_SEC}s | Remaining: ${REMAINING_MIN}m${REMAINING_SEC}s"
    log_info "========================================"
    
    # Test 1: Skill call - detect_objects
    log_info "Test 1: Skill call detect_objects..."
    OUTPUT=$($CLAWFED call agent_01 detect_objects --addr "http://127.0.0.1:50052" --args '{"url": "https://example.com/image.jpg"}' 2>&1)
    if echo "$OUTPUT" | grep -q "Called skill"; then
        log_success "detect_objects OK"
        SKILL_CALLS=$((SKILL_CALLS + 1))
    else
        log_error "detect_objects FAILED: $OUTPUT"
        SKILL_ERRORS=$((SKILL_ERRORS + 1))
    fi
    
    # Test 2: Skill call - summarize_pdf
    log_info "Test 2: Skill call summarize_pdf..."
    OUTPUT=$($CLAWFED call agent_01 summarize_pdf --addr "http://127.0.0.1:50052" --args '{"file": "test.pdf"}' 2>&1)
    if echo "$OUTPUT" | grep -q "Called skill"; then
        log_success "summarize_pdf OK"
        SKILL_CALLS=$((SKILL_CALLS + 1))
    else
        log_error "summarize_pdf FAILED: $OUTPUT"
        SKILL_ERRORS=$((SKILL_ERRORS + 1))
    fi
    
    # Test 3: Compliance check - blocked skill
    log_info "Test 3: Compliance check (should be blocked)..."
    OUTPUT=$($CLAWFED call agent_01 face_detect --addr "http://127.0.0.1:50052" --args '{}' 2>&1) || true
    if echo "$OUTPUT" | grep -q "Compliance check failed"; then
        log_success "Compliance block OK (face_detect blocked)"
        COMPLIANCE_BLOCKED=$((COMPLIANCE_BLOCKED + 1))
    else
        log_error "Compliance check unexpected result: $OUTPUT"
        COMPLIANCE_ERRORS=$((COMPLIANCE_ERRORS + 1))
    fi
    
    # Test 4: Process uptime check
    log_info "Test 4: Checking process uptime..."
    if kill -0 "$COORD_PID" 2>/dev/null && kill -0 "$AGENT_PID" 2>/dev/null; then
        log_success "Both processes alive"
        UPTIME_CHECKS=$((UPTIME_CHECKS + 1))
    else
        log_error "Process died! Coordinator: $(kill -0 "$COORD_PID" 2>/dev/null && echo alive || echo dead), Agent: $(kill -0 "$AGENT_PID" 2>/dev/null && echo alive || echo dead)"
        UPTIME_ERRORS=$((UPTIME_ERRORS + 1))
        
        # Try to restart if process died
        if ! kill -0 "$COORD_PID" 2>/dev/null; then
            log_warn "Restarting coordinator..."
            $CLAWFED server --addr "0.0.0.0:50051" --agent-id coordinator > "$LOG_DIR/coordinator.log" 2>&1 &
            COORD_PID=$!
            sleep 2
        fi
        if ! kill -0 "$AGENT_PID" 2>/dev/null; then
            log_warn "Restarting agent..."
            $CLAWFED agent --config clawfed.toml --server --addr "0.0.0.0:50052" > "$LOG_DIR/agent.log" 2>&1 &
            AGENT_PID=$!
            sleep 2
        fi
    fi
    
    # Test 5: Memory usage check
    log_info "Test 5: Checking memory usage..."
    COORD_MEM=$(ps -o rss= -p "$COORD_PID" 2>/dev/null || echo "0")
    AGENT_MEM=$(ps -o rss= -p "$AGENT_PID" 2>/dev/null || echo "0")
    COORD_MEM_MB=$((COORD_MEM / 1024))
    AGENT_MEM_MB=$((AGENT_MEM / 1024))
    log_info "Memory - Coordinator: ${COORD_MEM_MB}MB, Agent: ${AGENT_MEM_MB}MB"
    MEMORY_CHECKS=$((MEMORY_CHECKS + 1))
    
    # Report statistics every 10 iterations
    if [ $((ITERATION % 10)) -eq 0 ]; then
        TOTAL_SKILL=$((SKILL_CALLS + SKILL_ERRORS))
        TOTAL_COMPLIANCE=$((COMPLIANCE_BLOCKED + COMPLIANCE_ERRORS))
        TOTAL_OPS=$((TOTAL_SKILL + TOTAL_COMPLIANCE))
        SUCCESS_RATE=100
        if [ "$TOTAL_OPS" -gt 0 ]; then
            SUCCESS_RATE=$(( (SKILL_CALLS + COMPLIANCE_BLOCKED) * 100 / TOTAL_OPS ))
        fi
        
        log_info "========================================"
        log_info "Statistics (Iteration ${ITERATION})"
        log_info "========================================"
        log_info "Skill Calls Success: ${SKILL_CALLS}, Errors: ${SKILL_ERRORS}"
        log_info "Compliance Blocks: ${COMPLIANCE_BLOCKED}, Errors: ${COMPLIANCE_ERRORS}"
        log_info "Uptime Checks: ${UPTIME_CHECKS}, Errors: ${UPTIME_ERRORS}"
        log_info "Success Rate: ${SUCCESS_RATE}%"
        log_info "========================================"
    fi
    
    # Variable sleep between 3-8 seconds
    SLEEP_TIME=$(( (RANDOM % 6) + 3 ))
    log_info "Waiting ${SLEEP_TIME} seconds..."
    sleep "$SLEEP_TIME"
    
done

# Final report
FINAL_ELAPSED=$(( $(date +%s) - START_TIME ))
FINAL_MIN=$((FINAL_ELAPSED / 60))
FINAL_SEC=$((FINAL_ELAPSED % 60))

TOTAL_SKILL=$((SKILL_CALLS + SKILL_ERRORS))
TOTAL_COMPLIANCE=$((COMPLIANCE_BLOCKED + COMPLIANCE_ERRORS))
TOTAL_OPS=$((TOTAL_SKILL + TOTAL_COMPLIANCE))
SUCCESS_RATE=100
if [ "$TOTAL_OPS" -gt 0 ]; then
    SUCCESS_RATE=$(( (SKILL_CALLS + COMPLIANCE_BLOCKED) * 100 / TOTAL_OPS ))
fi

echo "" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"
echo "    20-Minute Stability Test Complete!" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"
log_info "Total Runtime: ${FINAL_MIN}m${FINAL_SEC}s"
log_info "Total Iterations: ${ITERATION}"
log_info "Skill Calls Success: ${SKILL_CALLS}, Errors: ${SKILL_ERRORS}"
log_info "Compliance Blocks: ${COMPLIANCE_BLOCKED}, Errors: ${COMPLIANCE_ERRORS}"
log_info "Uptime Checks: ${UPTIME_CHECKS}, Errors: ${UPTIME_ERRORS}"
log_info "Memory Checks: ${MEMORY_CHECKS}"
log_info "Overall Success Rate: ${SUCCESS_RATE}%"
echo "========================================" | tee -a "$LOG_FILE"
log_success "Log saved to: $LOG_FILE"
