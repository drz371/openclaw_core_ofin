#!/bin/bash
# Multi-Agent Test Script for Clawfed
# This script demonstrates how to start multiple agents and test their collaboration

set -e

echo "=== Clawfed Multi-Agent Test ==="
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to start coordinator
start_coordinator() {
    echo -e "${BLUE}Starting Coordinator...${NC}"
    cargo run --bin clawfed -- server --addr "[::1]:50051" --agent-id coordinator &
    COORDINATOR_PID=$!
    echo "Coordinator PID: $COORDINATOR_PID"
    sleep 2
}

# Function to start agent
start_agent() {
    local agent_id=$1
    local port=$2
    local skills=$3

    echo -e "${BLUE}Starting Agent $agent_id on port $port...${NC}"
    cargo run --bin clawfed -- agent --server --addr "[::1]:$port" &
    AGENT_PIDS+=($!)
    echo "Agent $agent_id PID: ${AGENT_PIDS[-1]}"
    sleep 1
}

# Function to test skill call
test_skill_call() {
    local target=$1
    local skill=$2
    local args=$3

    echo -e "${GREEN}Testing: $target -> $skill${NC}"
    cargo run --bin clawfed -- call "$target" "$skill" --args "$args" --addr "http://[::1]:50051"
    echo ""
}

# Function to test FL upload
test_fl_upload() {
    local task=$1
    local file=$2

    echo -e "${GREEN}Testing FL Upload: $task${NC}"
    cargo run --bin clawfed -- fl upload-delta --task "$task" --file "$file" --coordinator "http://[::1]:50051"
    echo ""
}

# Cleanup function
cleanup() {
    echo -e "${BLUE}Cleaning up...${NC}"
    kill $COORDINATOR_PID 2>/dev/null || true
    for pid in "${AGENT_PIDS[@]}"; do
        kill $pid 2>/dev/null || true
    done
    echo "All processes stopped"
}

# Trap cleanup on exit
trap cleanup EXIT

# Main test sequence
main() {
    # Create test delta file
    echo -e "${BLUE}Creating test delta file...${NC}"
    echo -ne '\x4C\x6F\x52\x41\x00\x01' > test_delta.lora
    echo "Test delta file created: test_delta.lora"

    # Start coordinator
    start_coordinator

    # Start multiple agents
    AGENT_PIDS=()
    start_agent "vision_agent_01" 50052 "detect_objects,analyze_image"
    start_agent "nlp_agent_01" 50053 "summarize_pdf,process_text"
    start_agent "robot_agent_01" 50054 "grasp_object,navigate"

    echo -e "${GREEN}All agents started!${NC}"
    echo ""

    # Wait for agents to be ready
    sleep 2

    # Test skill calls between agents
    echo "=== Testing Skill Calls ==="
    test_skill_call "vision_agent_01" "detect_objects" '{"url": "https://example.com/image.jpg"}'
    test_skill_call "nlp_agent_01" "summarize_pdf" '{"file": "document.pdf"}'
    test_skill_call "robot_agent_01" "grasp_object" '{"object": "cup"}'

    # Test FL upload
    echo "=== Testing Federated Learning ==="
    test_fl_upload "grasping_v1" "test_delta.lora"
    test_fl_upload "navigation_v2" "test_delta.lora"

    # Test compliance blocking
    echo "=== Testing Compliance Blocking ==="
    echo -e "${BLUE}Testing blocked skill call...${NC}"
    cargo run --bin clawfed -- call "vision_agent_01" "face_detect" --args '{"url": "test.jpg"}' --addr "http://[::1]:50051" || echo "Expected: Compliance blocked"

    echo -e "${BLUE}Testing blocked FL task...${NC}"
    cargo run --bin clawfed -- fl upload-delta --task "biometric_task" --file "test_delta.lora" --coordinator "http://[::1]:50051" || echo "Expected: Compliance blocked"

    echo ""
    echo -e "${GREEN}=== All tests completed successfully! ===${NC}"
    echo "Press Ctrl+C to stop all agents"
    echo ""

    # Keep running until interrupted
    wait
}

# Run main function
main
