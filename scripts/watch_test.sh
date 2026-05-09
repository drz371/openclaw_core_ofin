#!/bin/bash
# 持续监控24小时测试进度

while true; do
    clear
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║         OpenClaw × Hermes 24小时测试实时监控              ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    
    # 服务状态
    echo "【服务状态】"
    ps aux | grep -E "clawfed|stability_test" | grep -v grep | grep -v watch_test | awk '{printf "  ✓ %s (PID: %s, CPU: %s, MEM: %s)\n", $11, $2, $3, $4}'
    
    echo ""
    echo "【测试统计】"
    METRICS=$(ls -t logs/stability_test_24h/metrics_*.csv 2>/dev/null | head -1)
    if [ -f "$METRICS" ]; then
        awk -F',' 'NR>1 {
            oc+=$3; ocs+=$4
            hm+=$5; hms+=$6
            cr+=$7; crs+=$8
            cb+=$9; err+=$10
            iter=$2
            last_time=$1
        }
        END {
            printf "  迭代次数: %d\n", iter
            printf "  OpenClaw: %d/%d (%d%%)\n", ocs, oc, (oc>0?int(ocs*100/oc):0)
            printf "  Hermes:   %d/%d (%d%%)\n", hms, hm, (hm>0?int(hms*100/hm):0)
            printf "  跨Agent:  %d/%d (%d%%)\n", crs, cr, (cr>0?int(crs*100/cr):0)
            printf "  合规拦截: %d\n", cb
            printf "  总错误:   %d\n", err
            printf "  最后更新: %s\n", strftime("%Y-%m-%d %H:%M:%S", last_time)
        }' "$METRICS"
        
        echo ""
        echo "【最近10次迭代】"
        echo "  迭代  | OpenClaw | Hermes | 跨Agent | 合规 | 错误"
        tail -10 "$METRICS" | while IFS=',' read -r ts iter oc ocs hm hms cr crs cb err mem; do
            printf "  %5s | %3s/%3s | %3s/%3s | %3s/%3s | %4s | %3s\n" "$iter" "$ocs" "$oc" "$hms" "$hm" "$crs" "$cr" "$cb" "$err"
        done
    else
        echo "  等待指标文件..."
    fi
    
    echo ""
    echo "【系统资源】"
    free -h | grep "Mem:" | awk '{printf "  内存: %s/%s (%s)\n", $3, $2, $7}'
    uptime | awk '{printf "  负载: %s %s %s\n", $(NF-2), $(NF-1), $NF}'
    
    echo ""
    echo "$(date '+%Y-%m-%d %H:%M:%S') - 刷新中... (按 Ctrl+C 退出)"
    
    sleep 5
done
