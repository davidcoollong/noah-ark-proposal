#!/bin/bash
# git push 후 GitHub에 data.json이 올바르게 반영됐는지 자동 검증
# 문제 발생 시 경고 메시지를 Claude에게 feedback

COMMAND=$(echo "$1" | cat)  # stdin에서 읽거나 인수로 받음

# stdin으로 받는 경우 (hook에서 호출)
if [ -z "$COMMAND" ]; then
  STDIN=$(cat)
  COMMAND=$(echo "$STDIN" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" 2>/dev/null)
fi

# git push 명령어가 아니면 종료
if ! echo "$COMMAND" | grep -q "git push"; then
  exit 0
fi

# 2초 대기 (GitHub API 반영 시간)
sleep 2

# GitHub API로 실제 data.json IP 수 확인
RESULT=$(curl -s --max-time 10 \
  "https://api.github.com/repos/davidcoollong/noah-ark-proposal/contents/data.json" \
  | python3 -c "
import json,sys,base64
try:
    d = json.load(sys.stdin)
    content = base64.b64decode(d['content'].replace('\n','')).decode()
    data = json.loads(content)
    ips = data.get('ips', [])
    ip_info = [(ip['id'], len(ip.get('products',[]))) for ip in ips]
    print(f'OK|{len(ips)}|' + ','.join(f'{i[0]}:{i[1]}' for i in ip_info))
except Exception as e:
    print(f'ERROR|{e}')
" 2>/dev/null)

STATUS=$(echo "$RESULT" | cut -d'|' -f1)
IP_COUNT=$(echo "$RESULT" | cut -d'|' -f2)
DETAILS=$(echo "$RESULT" | cut -d'|' -f3)

if [ "$STATUS" = "OK" ]; then
  # 로컬 data.json IP 수와 비교
  LOCAL_COUNT=$(python3 -c "
import json
try:
    with open('/Users/air/noah-ark-proposal/data.json') as f:
        d = json.load(f)
    print(len(d.get('ips',[])))
except:
    print(0)
" 2>/dev/null)

  if [ "$IP_COUNT" = "$LOCAL_COUNT" ]; then
    echo "{\"systemMessage\": \"✅ GitHub 검증 완료: data.json 정상 반영 (IP ${IP_COUNT}개: ${DETAILS})\"}"
  else
    echo "{\"systemMessage\": \"⚠️ GitHub data.json 불일치! 로컬 IP ${LOCAL_COUNT}개 ≠ GitHub IP ${IP_COUNT}개 (${DETAILS}). git pull --rebase가 데이터를 덮어썼을 수 있습니다. 즉시 data.json을 재푸시하세요.\", \"decision\": \"block\", \"reason\": \"GitHub data.json IP 수가 로컬과 다릅니다. 수동 확인 후 재푸시 필요.\"}"
  fi
else
  echo "{\"systemMessage\": \"⚠️ GitHub data.json 검증 실패 (${RESULT}). 네트워크 오류일 수 있습니다.\"}"
fi
