#!/bin/bash
# 24小时测试监控脚本

LOG_DIR="logs/stability_test_24h"

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║         OpenClaw × Hermes 24小时测试监控                    ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

echo "【服务状态】"
ps aux | grep -E "clawfed" | grep -v grep | awk '{print "  ✓ "$11" "$12" "$13" "$14" "$15}'

echo ""
echo "【测试统计】"
METRICS=$(ls -t $LOG_DIR/metrics_*.csv 2>/dev/null | head -1)
if [ -f "$METRICS" ]; then
    awk -F',' 'NR>1 {
        oc+=$3; ocs+=$4
        hm+=$5; hms+=$6
        cr+=$7; crs+=$8
        cb+=$9; err+=$10
        iter=$2
    }
    END {
        print "  迭代次数: "iter
        print "  OpenClaw: "ocs"/"oc" ("int(ocs*100/oc)"%)"
        print "  Hermes:   "hms"/"hm" ("int(hms*100/hm)"%)"
        print "  跨Agent:  "crs"/"cr" ("int(crs*100/cr)"%)"
        print "  合规拦截: "cb
        print "  总错误:   "err
    }' "$METRICS"
    
    echo ""
    echo "【最近5次迭代】"
    echo "迭代 | OpenClaw | Hermes | 跨Agent | 合规 | 内存"
    tail -5 "$METRICS" | while IFS=',' read -r ts iter oc ocs hm hms cr crs cb err mem; do
        echo "$iter | $ocs/$oc | $hms/$hm | $crs/$cr | $cb | ${mem}MB"
    done
else
    echo "  等待指标文件..."
fi

echo ""
echo "【日志文件】"
ls -la $LOG_DIR/*.log $LOG_DIR/*.csv 2>/dev/null | tail -5

echo ""
echo "【运行时间】"
START=$(grep "测试开始时间:" $LOG_DIR/stability_24h_*.log 2>/dev/null | head -1 | sed 's/.*: //')
echo "  开始: $START"
echo "  当前: $(date)"
