# Clawfed CLI Usage Examples

## 1. Starting an Agent

### Basic Start
```bash
clawfed agent --config ./clawfed.toml
```

### Start with Debug Logging
```bash
clawfed agent --config ./clawfed.toml --log-level debug --log-format json
```

### Start with Pretty Logging
```bash
clawfed agent --config ./clawfed.toml --log-level info --log-format pretty
```

## 2. Calling Remote Skills

### Basic Skill Call
```bash
clawfed call vision_agent_01 detect_objects
```

### Skill Call with Arguments
```bash
clawfed call vision_agent_01 detect_objects --args '{"url": "https://example.com/image.jpg"}'
```

### Skill Call with Complex Arguments
```bash
clawfed call nlp_agent_01 summarize_text --args '{
  "text": "Long text to summarize...",
  "max_length": 100,
  "language": "en"
}'
```

### Compliance-Blocked Skill Call (CN Region)
```bash
# This will be blocked with error: CN-DATA-001
clawfed call vision_agent_01 face_detect --args '{"url": "..."}'

# This will also be blocked
clawfed call auth_agent_01 id_card_generate --args '{"name": "..."}'
```

## 3. Federated Learning

### Upload Model Delta
```bash
clawfed fl upload-delta --task grasping_v1 --file delta.lora
```

### Upload LoRA Weights
```bash
clawfed fl upload-delta --task navigation_v2 --file model.lora
```

### Upload with Full Path
```bash
clawfed fl upload-delta --task grasping_v1 --file /path/to/model/delta.lora
```

### Compliance-Blocked FL Task (CN Region)
```bash
# This will be blocked with error: CN-DATA-001
clawfed fl upload-delta --task biometric_task --file delta.lora

# This will also be blocked
clawfed fl upload-delta --task portrait_recognition --file delta.lora
```

### Size-Limited Upload
```bash
# Default max size: 10MB
# Files larger than 10MB will be rejected with error: SIZE-001
clawfed fl upload-delta --task grasping_v1 --file large_delta.lora
```

## 4. Configuration Examples

### Minimal Configuration (clawfed.toml)
```toml
agent_id = "my_agent"

[compliance]
enabled = true
country = "CN"

[features]
enable_skills = true
enable_fl = false
fl_max_upload_mb = 10
```

### Full Configuration
```toml
agent_id = "production_agent_01"

[security]
trusted_agents = ["coordinator", "backup_coordinator"]
use_sm_crypto = false

[compliance]
enabled = true
country = "CN"

[features]
enable_skills = true
enable_fl = true
fl_max_upload_mb = 50
```

### Non-CN Configuration (No Compliance Blocking)
```toml
agent_id = "us_agent_01"

[security]
trusted_agents = ["coordinator"]
use_sm_crypto = false

[compliance]
enabled = true
country = "US"

[features]
enable_skills = true
enable_fl = true
fl_max_upload_mb = 100
```

## 5. Delta File Formats

### LoRA Format
Magic bytes: `0x4C 0x6F 0x52 0x41` ("LoRA")

```bash
# Create a LoRA file
echo -ne '\x4C\x6F\x52\x41\x00\x01' > model.lora
clawfed fl upload-delta --task grasping_v1 --file model.lora
```

### DELTA Format
Magic bytes: `0x44 0x45 0x4C 0x54` ("DELT")

```bash
# Create a DELTA file
echo -ne '\x44\x45\x4C\x54\x00\x01' > delta.delta
clawfed fl upload-delta --task navigation_v1 --file delta.delta
```

## 6. Troubleshooting

### Check if File Exists
```bash
# Before uploading, verify file exists
ls -la delta.lora
```

### Verify File Size
```bash
# Check file size before upload
ls -lh delta.lora

# If larger than fl_max_upload_mb, it will be rejected
```

### Enable Debug Logging
```bash
# Run with debug logging to see detailed information
clawfed fl upload-delta --task grasping_v1 --file delta.lora --log-level debug
```

### Check Compliance Status
```bash
# Review logs for compliance checks
clawfed call vision_agent_01 face_detect --args '{}' --log-level debug
# Look for: "compliance_blocked" in logs
```

## 7. Common Error Messages

### CN-DATA-001 (Compliance Blocked)
```
Error: Status { code: PermissionDenied, message: "CN-DATA-001", ... }
```
**Cause**: Operation blocked by CN compliance policy
**Solution**: Use different skill name or task ID, or change country setting

### SIZE-001 (File Too Large)
```
Error: File size 15 MB exceeds maximum allowed 10 MB
```
**Cause**: Delta file exceeds fl_max_upload_mb limit
**Solution**: Reduce file size or increase fl_max_upload_mb in config

### FILE-NOT-FOUND
```
Error: File not found: delta.lora
```
**Cause**: Specified file does not exist
**Solution**: Verify file path and name

### CONFIG-NOT-FOUND
```
Error: Configuration file not found: ./clawfed.toml
```
**Cause**: Configuration file missing
**Solution**: Create clawfed.toml with proper configuration

## 8. Advanced Usage

### Batch Upload Multiple Deltas
```bash
for task in grasping_v1 navigation_v2 detection_v3; do
  clawfed fl upload-delta --task $task --file ${task}.lora
done
```

### Automated Skill Calls
```bash
# Call multiple skills in sequence
clawfed call agent_01 skill_a --args '{"input": "data"}'
clawfed call agent_02 skill_b --args '{"input": "result"}'
```

### Integration with Scripts
```bash
#!/bin/bash
# upload_deltas.sh

TASK_ID=$1
DELTA_FILE=$2

if [ ! -f "$DELTA_FILE" ]; then
  echo "Error: File not found: $DELTA_FILE"
  exit 1
fi

clawfed fl upload-delta --task "$TASK_ID" --file "$DELTA_FILE"
```

## 9. Monitoring and Logs

### JSON Log Format
```bash
clawfed agent --log-level info --log-format json
```

Output:
```json
{"timestamp":"2026-03-31T10:30:00.000Z","level":"INFO","agent_id":"my_agent","event":"agent_start","status":"started"}
```

### Pretty Log Format
```bash
clawfed agent --log-level debug --log-format pretty
```

Output:
```
2026-03-31T10:30:00.000Z INFO clawfed: Agent started with config: ./clawfed.toml
```

### Filter Logs by Event
```bash
# Using jq to filter JSON logs
clawfed agent --log-format json | jq 'select(.event == "compliance_blocked")'
```
