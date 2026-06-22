#!/bin/bash
# ╔══════════════════════════════════════════════════════════════╗
# ║   ALGORA BOUNTY SENTINEL PRO v4.0                           ║
# ║   By @Bakomebandias — github.com/BAKOME-hub                 ║
# ║   APIs: Algora + DeepSeek AI + Wikipedia + GitHub + more    ║
# ╚══════════════════════════════════════════════════════════════╝

# ═══ CONFIG ═══
ALGORA_API="https://algora.io/api"
DEEPSEEK_API="https://api.deepseek.com/v1/chat/completions"
DEEPSEEK_KEY="${DEEPSEEK_API_KEY:-}"
WIKIPEDIA_API="https://en.wikipedia.org/api/rest_v1/page/summary"
GITHUB_API="https://api.github.com"
DATA_DIR="${HOME}/.algora-sentinel"
HISTORY_FILE="$DATA_DIR/history.log"
mkdir -p "$DATA_DIR"

# ═══ COLORS ═══
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; PURPLE='\033[0;35m'; CYAN='\033[0;36m'; NC='\033[0m'

# ═══ BANNER ═══
banner() {
  echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${PURPLE}║${NC}${CYAN}   ALGORA BOUNTY SENTINEL PRO v4.0                           ${PURPLE}║${NC}"
  echo -e "${PURPLE}║${NC}${CYAN}   By @Bakomebandias — github.com/BAKOME-hub                 ${PURPLE}║${NC}"
  echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}"
  echo ""
}

# ═══ API FUNCTIONS ═══

ask_ai() {
  local PROMPT="$1"
  if [ -z "$DEEPSEEK_KEY" ]; then
    echo -e "${YELLOW}⚠️  DeepSeek API key not set. Export DEEPSEEK_API_KEY in your .bashrc${NC}"
    return 1
  fi
  curl -s "$DEEPSEEK_API" \
    -H "Authorization: Bearer $DEEPSEEK_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"deepseek-chat\",\"messages\":[{\"role\":\"user\",\"content\":\"$PROMPT\"}],\"max_tokens\":150}" \
    2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['choices'][0]['message']['content'])" 2>/dev/null
}

wiki_summary() {
  local TOPIC="$1"
  echo -e "${BLUE}📚 Wikipedia: $TOPIC${NC}"
  curl -s "$WIKIPEDIA_API/$(echo $TOPIC | sed 's/ /_/g')" 2>/dev/null | \
    python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('extract','?')[:300])" 2>/dev/null
}

check_claim() {
  local CLAIM_ID="$1"
  echo -e "${CYAN}🔍 Claim: $CLAIM_ID${NC}"
  RESPONSE=$(curl -sL "https://algora.io/claims/$CLAIM_ID" 2>/dev/null)
  TITLE=$(echo "$RESPONSE" | grep -oP '<title[^>]*>\K[^<]+' | head -1)
  if echo "$TITLE" | grep -q "404\|Not Found" || [ -z "$TITLE" ]; then
    echo -e "   ${RED}❌ Not found${NC}"
    return 1
  else
    echo -e "   ${GREEN}✅ $TITLE${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M')] ✅ $CLAIM_ID — $TITLE" >> "$HISTORY_FILE"
    return 0
  fi
}

check_all_claims() {
  echo -e "${CYAN}🔍 CHECKING ${#@} CLAIMS${NC}\n"
  for claim in "$@"; do
    check_claim "$claim"
    echo ""
  done
}

list_bounties() {
  echo -e "${BLUE}📊 ALGORA BOUNTIES:${NC}"
  curl -s "$ALGORA_API/bounties" 2>/dev/null | python3 -c "
import sys,json
try:
  data = json.load(sys.stdin)
  if isinstance(data, list):
    for b in data[:10]:
      print(f\"  🏆 {b.get('title','?')[:60]}\")
      print(f\"     💰 \${b.get('amount','?')} | 📦 {b.get('repo','?')}\")
except:
  print('  ❌ API unreadable')
" 2>/dev/null
}

check_repo() {
  local REPO="$1"
  echo -e "${BLUE}📦 Repo: $REPO${NC}"
  gh api "repos/$REPO" --jq '"\n  ⭐ \(.stargazers_count) | 🍴 \(.forks_count) | 📋 \(.open_issues_count) issues\n  📅 Updated: \(.updated_at[0:10])\n  🌐 \(.html_url)"' 2>/dev/null
  LAST=$(gh api "repos/$REPO/commits?per_page=1" --jq '.[0].commit.author.date[0:10]' 2>/dev/null)
  echo -e "  📅 Last commit: ${GREEN}$LAST${NC}"
}

check_contributor() {
  local USER="$1"
  echo -e "${BLUE}👤 @$USER${NC}"
  PR_COUNT=$(gh search prs "author:$USER is:open" --limit 1 --json totalCount --jq '.totalCount' 2>/dev/null)
  echo -e "  📊 Open PRs: ${GREEN}$PR_COUNT${NC}"
  gh api "users/$USER" --jq '"  📝 \(.bio[0:80])\n  📦 Public repos: \(.public_repos)\n  🌐 \(.html_url)"' 2>/dev/null
}

watch_claim() {
  local CLAIM_ID="$1"
  echo -e "${YELLOW}👁️  Watch mode activated for $CLAIM_ID${NC}"
  echo -e "${YELLOW}   Checking every 30 minutes. Ctrl+C to stop.${NC}\n"
  while true; do
    echo -e "${CYAN}[$(date '+%H:%M:%S')]${NC} Checking..."
    STATUS=$(check_claim "$CLAIM_ID" 2>&1)
    echo "$STATUS"
    if echo "$STATUS" | grep -q "✅"; then
      echo -e "${GREEN}   → Claim found!${NC}"
    fi
    sleep 1800
  done
}

export_csv() {
  local FILE="${1:-algoba_bounties_$(date +%Y%m%d_%H%M%S).csv}"
  echo "Claim ID,Status,Check Date" > "$FILE"
  if [ -f "$HISTORY_FILE" ]; then
    grep "✅" "$HISTORY_FILE" | while read line; do
      CLAIM_ID=$(echo "$line" | grep -oP '[a-zA-Z0-9]{16,}')
      DATE=$(echo "$line" | cut -d']' -f1 | tr -d '[')
      echo "$CLAIM_ID,Active,$DATE" >> "$FILE"
    done
  fi
  echo -e "${GREEN}✅ Exported to $FILE${NC}"
}

generate_report() {
  local REPORT_FILE="${1:-algoba_report_$(date +%Y%m%d_%H%M%S).md}"
  echo "# 📊 Algora Report — $(date '+%d %B %Y')" > "$REPORT_FILE"
  echo "" >> "$REPORT_FILE"
  echo "## 👤 Contributor: @Bakomebandias" >> "$REPORT_FILE"
  echo "" >> "$REPORT_FILE"
  echo "## 📋 Verified Claims:" >> "$REPORT_FILE"
  if [ -f "$HISTORY_FILE" ]; then
    grep "✅" "$HISTORY_FILE" | while read line; do
      echo "- $line" >> "$REPORT_FILE"
    done
  fi
  echo "" >> "$REPORT_FILE"
  echo "---" >> "$REPORT_FILE"
  echo "*Generated by Algora Bounty Sentinel v4.0*" >> "$REPORT_FILE"
  echo -e "${GREEN}✅ Report generated: $REPORT_FILE${NC}"
}

dashboard() {
  clear
  banner
  echo -e "${CYAN}╔══════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║   DASHBOARD                         ║${NC}"
  echo -e "${CYAN}╚══════════════════════════════════════╝${NC}"
  echo ""
  echo -e "${GREEN}📊 STATISTICS:${NC}"
  TOTAL=$(grep -c "✅" "$HISTORY_FILE" 2>/dev/null || echo 0)
  echo -e "   Claims verified today: ${YELLOW}$TOTAL${NC}"
  echo ""
  echo -e "${BLUE}📋 LATEST CHECKS:${NC}"
  tail -5 "$HISTORY_FILE" 2>/dev/null
  echo ""
  echo -e "${PURPLE}🌐 QUICK LINKS:${NC}"
  echo -e "   Algora  : ${CYAN}https://algora.io${NC}"
  echo -e "   GitHub  : ${CYAN}https://github.com/Bakomebandias${NC}"
  echo ""
}

# ═══ MENU ═══
show_menu() {
  banner
  echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║   MAIN MENU                           ║${NC}"
  echo -e "${GREEN}╠════════════════════════════════════════╣${NC}"
  echo -e "${GREEN}║${NC} 1  • Check ONE claim                ${GREEN}║${NC}"
  echo -e "${GREEN}║${NC} 2  • Check MULTIPLE claims          ${GREEN}║${NC}"
  echo -e "${GREEN}║${NC} 3  • List Algora bounties           ${GREEN}║${NC}"
  echo -e "${GREEN}║${NC} 4  • GitHub repo info               ${GREEN}║${NC}"
  echo -e "${GREEN}║${NC} 5  • Contributor info               ${GREEN}║${NC}"
  echo -e "${GREEN}║${NC} 6  • Dashboard                      ${GREEN}║${NC}"
  echo -e "${GREEN}║${NC} 7  • Watch mode (monitor claim)     ${GREEN}║${NC}"
  echo -e "${GREEN}║${NC} 8  • Export CSV                     ${GREEN}║${NC}"
  echo -e "${GREEN}║${NC} 9  • Generate Markdown report       ${GREEN}║${NC}"
  echo -e "${GREEN}║${NC} 10 • Wikipedia search               ${GREEN}║${NC}"
  echo -e "${GREEN}║${NC} 11 • DeepSeek AI advice             ${GREEN}║${NC}"
  echo -e "${GREEN}║${NC} 12 • Help                           ${GREEN}║${NC}"
  echo -e "${GREEN}║${NC} 0  • Exit                           ${GREEN}║${NC}"
  echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
  echo ""
}

# ═══ MAIN ═══
if [ $# -eq 0 ]; then
  while true; do
    show_menu
    printf "👉 Choose an option (0-12): "
    read CHOICE
    case $CHOICE in
      1) printf "   Claim ID: "; read CID; check_claim "$CID"; printf "Press Enter to continue..."; read _ ;;
      2) printf "   Claims (space-separated): "; read -a CLAIMS; check_all_claims "${CLAIMS[@]}"; printf "Press Enter to continue..."; read _ ;;
      3) list_bounties; printf "Press Enter to continue..."; read _ ;;
      4) printf "   Repo (owner/name): "; read REPO; check_repo "$REPO"; printf "Press Enter to continue..."; read _ ;;
      5) printf "   GitHub user: "; read USER; check_contributor "$USER"; printf "Press Enter to continue..."; read _ ;;
      6) dashboard; printf "Press Enter to continue..."; read _ ;;
      7) printf "   Claim ID to watch: "; read CID; watch_claim "$CID" ;;
      8) export_csv; printf "Press Enter to continue..."; read _ ;;
      9) generate_report; printf "Press Enter to continue..."; read _ ;;
      10) printf "   Wikipedia topic: "; read TOPIC; wiki_summary "$TOPIC"; printf "Press Enter to continue..."; read _ ;;
      11) printf "   Question for DeepSeek AI: "; read QUESTION; ask_ai "$QUESTION"; printf "Press Enter to continue..."; read _ ;;
      12) echo -e "${CYAN}Help: github.com/BAKOME-hub/algora-bounty-sentinel${NC}"; printf "Press Enter to continue..."; read _ ;;
      0) echo -e "${RED}Goodbye!${NC}"; exit 0 ;;
      *) echo -e "${RED}Invalid option${NC}"; printf "Press Enter to continue..."; read _ ;;
    esac
  done
else
  case "$1" in
    check) check_claim "$2" ;;
    all) shift; check_all_claims "$@" ;;
    list) list_bounties ;;
    repo) check_repo "$2" ;;
    user) check_contributor "$2" ;;
    watch) watch_claim "$2" ;;
    export) export_csv "$2" ;;
    report) generate_report "$2" ;;
    dashboard) dashboard ;;
    wiki) wiki_summary "$2" ;;
    ai) ask_ai "$2" ;;
    *) check_claim "$1" ;;
  esac
fi
