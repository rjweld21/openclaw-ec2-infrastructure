# Session Health Monitor
# Quick check of token usage and recommendations

Write-Host "🔍 OpenClaw Session Health Check" -ForegroundColor Blue
Write-Host ""

# This would be run by calling session_status, but here's what to watch:
Write-Host "📊 Token Usage Monitoring:" -ForegroundColor Yellow
Write-Host ""
Write-Host "🟢 Healthy Context: <50% of context limit" -ForegroundColor Green
Write-Host "🟡 Warning: 50-80% context used" -ForegroundColor Yellow  
Write-Host "🔴 Critical: >80% context used" -ForegroundColor Red
Write-Host ""
Write-Host "💡 Output Token Tips:" -ForegroundColor Cyan
Write-Host "• Break complex requests into steps"
Write-Host "• Ask for summaries first, details second"
Write-Host "• Use shorter sub-agent task descriptions"
Write-Host "• Start new session for major topic changes"
Write-Host ""
Write-Host "🤖 Sub-Agent Management:" -ForegroundColor Blue
Write-Host "• Kill stuck sub-agents with: 'kill all sub-agents'"
Write-Host "• Redeploy with shorter, focused tasks"
Write-Host "• Monitor with: 'list sub-agents'"
Write-Host ""
Write-Host "💰 Cost Optimization:" -ForegroundColor Green
Write-Host "• Your current approach saves ~$500/month vs API!"
Write-Host "• Efficient sessions = even more savings"
Write-Host ""

Write-Host "Run this check periodically to maintain session health!" -ForegroundColor Yellow