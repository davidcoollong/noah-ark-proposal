# 노아&아크 제품제안서 프로젝트 — Claude 작업 규칙

## 프로젝트 개요
- **레포**: davidcoollong/noah-ark-proposal
- **라이브 URL**: https://davidcoollong.github.io/noah-ark-proposal/
- **관리자**: https://davidcoollong.github.io/noah-ark-proposal/admin.html
- **데이터 소스**: `data.json` (3개 IP: pororo/coraline/catandsoup)

---

## 🔴 절대 규칙 (반복 오류 방지)

### 1. git push 후 반드시 GitHub 반영 검증
```bash
# push 후 항상 GitHub API로 확인
curl -s "https://api.github.com/repos/davidcoollong/noah-ark-proposal/contents/data.json" \
  | python3 -c "import json,sys,base64; d=json.load(sys.stdin); c=base64.b64decode(d['content'].replace('\n','')).decode(); print([(ip['id'],len(ip['products'])) for ip in json.loads(c)['ips']])"
```
- 로컬 IP 수 ≠ GitHub IP 수 → **즉시 재push 필요**
- `.claude/settings.json` 훅이 자동으로 검증하고 경고함

### 2. data.json 충돌 시 `--theirs` / `--ours` 절대 금지
```bash
# ❌ 금지
git checkout --theirs data.json
git checkout --ours data.json

# ✅ 올바른 방법: Python으로 두 버전 병합
python3 -c "
import json, subprocess
# 로컬 버전
local = json.loads(subprocess.run(['git','show','HEAD:data.json'],capture_output=True,text=True).stdout)
# 원격 버전  
remote = json.loads(subprocess.run(['git','show','MERGE_HEAD:data.json'],capture_output=True,text=True).stdout)
# IPs 합치기 (remote 기준, 로컬만 있는 IP 추가)
remote_ids = {ip['id'] for ip in remote['ips']}
for ip in local['ips']:
    if ip['id'] not in remote_ids:
        remote['ips'].append(ip)
with open('data.json','w') as f: json.dump(remote,f,ensure_ascii=False,indent=2)
print('병합 완료')
"
git add data.json
git rebase --continue
```

### 3. 이미지/데이터 URL 규칙
- `raw.githubusercontent.com` → **금지** (CDN 캐시 5분 지연)
- 대신 GitHub Pages URL 사용: `https://davidcoollong.github.io/noah-ark-proposal/`
- 외부 이미지 (Naver CDN `shop-phinf.pstatic.net`) → `resolveImg()`가 직접 처리

### 4. 항상 GitHub 최신 데이터 자동갱신
모든 페이지(admin.html, proposal-full.html)의 init 코드는 반드시:
1. localStorage 데이터 즉시 표시 (빠른 렌더)
2. **항상** GitHub Pages에서 `data.json?v=Date.now()` fetch
3. 최신 데이터로 localStorage 갱신 + 재렌더

```javascript
// ✅ 올바른 패턴
try {
  const local = JSON.parse(localStorage.getItem('noa_admin_data'));
  if (local?.ips) applyData(local); // 즉시 표시
} catch {}
// 항상 GitHub 최신 버전으로 갱신
fetch('data.json?v=' + Date.now())
  .then(r => r.json())
  .then(d => { localStorage.setItem('noa_admin_data', JSON.stringify(d)); applyData(d); })
  .catch(() => {});
```

---

## 프로젝트 구조
```
noah-ark-proposal/
├── proposal-full.html    ← 클라이언트용 제안서
├── admin.html            ← 관리자 페이지
├── data.json             ← 단일 데이터 소스 (IP별 제품 48개)
├── images/               ← 로컬 이미지 (Naver CDN URL 우선 사용)
├── pororo/index.html     ← 단축 URL 리다이렉트
├── coraline/index.html
├── catandsoup/index.html
├── scripts/
│   └── verify-push.sh    ← git push 후 자동 검증
└── .claude/
    └── settings.json     ← 훅 설정
```

## IP 목록
| ID | 이름 | 제품 수 | 단축 URL |
|----|------|---------|---------|
| pororo | 극장판 뽀로로 & 뽀송포비 | 13개 | `/pororo/` |
| coraline | 코렐라인 | 20개 | `/coraline/` |
| catandsoup | 고양이와 스프 | 15개 | `/catandsoup/` |
