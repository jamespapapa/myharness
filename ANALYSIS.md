클라우드 — 오전 8:552026년 3월 13일 금요일 오전 8:55
openclaw는 전체 코드량이 얼마나 되?
:100:
클릭해서 반응
:laughing:
클릭해서 반응
:raised_hands:
클릭해서 반응
반응 추가하기
수정
전달
기타

티파
앱
 — 오전 8:572026년 3월 13일 금요일 오전 8:57
잠깐 소스 기준으로 대략치 뽑아볼게. 번들(dist) 말고 upstream repo 기준이 더 맞아서 그쪽으로 계산해보는 중.
:100:
클릭해서 반응
:laughing:
클릭해서 반응
:raised_hands:
클릭해서 반응
반응 추가하기
답장
전달
기타
[오전 8:57]2026년 3월 13일 금요일 오전 8:57
대충 엄청 큰 편이야.

내가 방금 upstream openclaw/openclaw repo 기준으로 대략 세어봤는데:

코드성 파일만 기준,
(.ts .js .swift .kt .sh .py .css .html .go 등)
약 1,329,587줄,
빈 줄 제외하면 약 1,208,365줄,

문서/설정까지 포함한 텍스트 전체 기준,
약 1,576,361줄,

체감 오게 주요 언어만 보면:
TypeScript: 약 117만 줄,
Swift: 약 9.7만 줄,
Kotlin: 약 2.3만 줄,
그 외 shell/python/css/js/go 등이 조금씩,
:100:
클릭해서 반응
:laughing:
클릭해서 반응
:raised_hands:
클릭해서 반응
반응 추가하기
답장
전달
기타
[오전 8:57]2026년 3월 13일 금요일 오전 8:57
디렉토리로 보면 대충:
src : 약 95만 줄,
extensions : 약 15.4만 줄,
apps : 약 12만 줄,
ui : 약 5.8만 줄,

한 줄 요약하면:

OpenClaw는 지금 대략 “코드성 파일 기준 130만 줄짜리 꽤 큰 모노레포” 라고 보면 돼.

참고로 이 숫자는:
Git tracked 파일 기준,
바이너리/이미지는 제외,
테스트/스크립트/일부 vendor는 포함,
그래서 cloc 공식 수치랑은 조금 다를 수 있음,

원하면 내가 다음엔
:100:
클릭해서 반응
:laughing:
클릭해서 반응
:raised_hands:
클릭해서 반응
반응 추가하기
답장
전달
기타
[오전 8:57]2026년 3월 13일 금요일 오전 8:57
“코어 런타임만 몇 줄인지”,
“Claude Code/Codex 같은 도구랑 비교하면 어느 정도 규모인지”,
“어느 폴더부터 읽어야 덜 고통스러운지”,
이렇게 이어서 정리해줄게.
:100:
클릭해서 반응
:laughing:
클릭해서 반응
:raised_hands:
클릭해서 반응
반응 추가하기
답장
전달
기타

클라우드 — 오전 8:582026년 3월 13일 금요일 오전 8:58
ㅋㅋㅋㅋ 오픈클로 개발자 아저씨 하루에 커밋 3천개씩 하는데, 후... 우리도 어떻게 하면 저 아저씨처럼 생산성을 늘릴 수 있을까?? 저 아저씨 생산성 비결이 모야??
:100:
클릭해서 반응
:laughing:
클릭해서 반응
:raised_hands:
클릭해서 반응
반응 추가하기
수정
전달
기타

티파
앱
 — 오전 8:592026년 3월 13일 금요일 오전 8:59
ㅋㅋ 내 생각에 비결은 “손이 빠르다”보다 “시스템이 빠르다” 쪽이야.

방금 repo 쪽 숫자까지 조금 봤는데, 이건 거의 개인 1명의 타자 속도라기보다 사람 + 에이전트 + 커뮤니티 + 자동화가 합쳐진 생산성에 가까워 보여.

대충 이런 그림이야:

최근 4주 커밋 합계가 약 8,359,
최근 1주만 해도 약 854,
GitHub stats 기준 기여자도 100명+ 잡힘,

그래서 “저 아저씨 혼자 하루 3천 커밋”처럼 보여도 실제 비결은 보통 이거임:

일을 엄청 잘게 쪼갬,
,
큰 기능 하나를
스키마,
UI,
문서,
:100:
클릭해서 반응
:laughing:
클릭해서 반응
:raised_hands:
클릭해서 반응
반응 추가하기
답장
전달
기타
[오전 8:59]2026년 3월 13일 금요일 오전 8:59
리팩터,
테스트,
릴리즈 노트,
이렇게 잘라서 계속 넣음.

즉 큰 천재 점프보다 작은 완료를 미친 듯이 많이 쌓는 방식.

자동화를 사람처럼 안 쓰고, 사람 위에 얹어 씀,
,
OpenClaw 쪽은 구조상 봐도
subagents,
ACP,
browser / exec / sessions,
skills,
docs,
이런 게 다 있어서, 반복 작업을 도구화하기 좋거든.

이런 팀은 보통:
[오전 8:59]2026년 3월 13일 금요일 오전 8:59
조사 에이전트,
구현 에이전트,
문서 에이전트,
리뷰/테스트 에이전트,
를 동시에 굴려.

그래서 생산성이 “한 명이 빠름”이 아니라
병렬 처리량이 큼.

문서가 그냥 문서가 아니라 운영도구임,
,
OpenClaw 보면 docs, skills, config, CLI 레퍼런스가 엄청 촘촘하잖아.

이런 팀은 같은 질문/같은 설정/같은 설치를
매번 머리로 안 하고
문서화,
스크립트화,
명령화,
[오전 8:59]2026년 3월 13일 금요일 오전 8:59
해버림.

즉 한 번 고생한 건 두 번 안 함.

모노레포라서 왕복비용이 적음,
,
repo 구조 보면
src,
apps,
extensions,
ui,
docs,
가 한 덩어리라서

“코드 고치고 → 문서 고치고 → UI 맞추고 → 릴리즈”가 한 흐름으로 가기 쉬워.
이게 진짜 큼.

완벽주의보다 배포 속도를 우선함,
,
[오전 8:59]2026년 3월 13일 금요일 오전 8:59
릴리즈 노트 보면 기능 추가 + 버그 수정 + 문서 업데이트가 엄청 자주 같이 굴러가.
이런 팀은 대개
완벽한 큰 배포 1번,
보다
쓸만한 작은 배포 20번,
을 더 선호함.

이게 누적되면 겉보기 생산성이 미쳐 보임.

---

그래서 우리도 생산성 늘리려면?,
내 기준 핵심은 이 5개야.

A. “큰 일”을 바로 하지 말고 30분짜리로 쪼개기,
예:
“대시보드 만들기” X,
[오전 8:59]2026년 3월 13일 금요일 오전 8:59
“sessions list API 먼저” O,
“subagent 카드 UI만 먼저” O,
“상태 pill만 먼저” O,

B. 반복 작업은 바로 스크립트/템플릿화,
한 번 이상 반복되면:
명령어로 만들고,
README/AGENTS/SKILL에 박고,
다음엔 복붙이 아니라 실행,

C. 에이전트는 보조가 아니라 병렬 워커로 쓰기,
예:
하나는 탐색,
하나는 구현,
하나는 테스트/문서,
이렇게 분업.
[오전 9:00]2026년 3월 13일 금요일 오전 9:00
D. “커밋 수”보다 “리드타임” 줄이기,
진짜 중요한 건
아이디어 → 첫 동작까지 시간,
수정 → 확인까지 시간,
버그 발견 → 배포까지 시간,
이거 줄이는 거야.

E. 매일 조금씩 ship하기,
생산성 높은 사람들 보면 공통점이
계속 완료 상태를 만든다는 거임.
미완성 큰 덩어리보다
작게라도 완료된 게 계속 나옴.

---

한 줄 요약,
저 아저씨 비결 = 초인적인 코딩 손속도라기보다,
:100:
클릭해서 반응
:laughing:
클릭해서 반응
:raised_hands:
클릭해서 반응
반응 추가하기
답장
전달
기타
[오전 9:00]2026년 3월 13일 금요일 오전 9:00
작게 쪼개고 / 자동화하고 / 병렬화하고 / 자주 배포하는 시스템 같아.

그리고 솔직히 제일 중요한 말 하나 하면:

생산성 괴물처럼 보이는 사람들은 보통 “열심히 더 많이”가 아니라 “마찰이 없게” 일함.

원하면 내가 다음엔
“클라우드가 OpenClaw 탐색할 때 바로 써먹을 생산성 세팅 10개” 식으로 실전 버전으로 정리해줄게.

클라우드 — 오전 9:102026년 3월 13일 금요일 오전 9:10
응 저 아저씨는 자기가 코드 안 보고 배포한데. 에이전트를 엄청 굴려. 작업할 때 보면, 맥북하고 맥미니 여러개쓰면서 모니터 여러개, 그 안에 터미널 엄청 많이 

이렇게 열어서 하거든?? 그렇게 할 수 있는 비결이 뭔지 찾아봐. 저 아저씨 깃 레포랑, 이슈구성, 문서 구성 등 루틴 역으로 추적해서 알아봐
:100:
클릭해서 반응
:laughing:
클릭해서 반응
:raised_hands:
클릭해서 반응
반응 추가하기
수정
전달
기타

티파
앱
 — 오전 9:202026년 3월 13일 금요일 오전 9:20
짧게 구조/루틴 신호부터 긁어볼게. 공개된 repo/이슈/문서/워크플로우 기준으로 “어떻게 저렇게 굴리는지” 역추적해보는 식으로 볼 거야.
[오전 9:20]2026년 3월 13일 금요일 오전 9:20
깊은 히스토리가 얕게 받아져서(commit 1개만 보임) 커밋 패턴은 더 fetch해서 확인할게. 이슈/라벨 구조는 이미 꽤 신호가 많네.
[오전 9:20]2026년 3월 13일 금요일 오전 9:20
공개 레포 신호만으로도 꽤 그림이 보이는데, 혹시 진짜 본인이 어디선가 workflow를 말했는지도 한 번만 웹에서 더 확인해볼게.

클라우드 — 오전 9:292026년 3월 13일 금요일 오전 9:29
ㅎㅎㅎㅎㅎㅎ 좋아. 찾을 수 있는거 다 찾아봐
:100:
클릭해서 반응
:laughing:
클릭해서 반응
:raised_hands:
클릭해서 반응
반응 추가하기
수정
전달
기타

티파
앱
 — 오전 9:322026년 3월 13일 금요일 오전 9:32
오케이, 이번엔 진짜 “루틴 추적 리포트” 느낌으로 더 깊게 긁어볼게. GitHub backlog 운영, PR 파이프라인, 릴리즈/문서/CI 자동화 쪽까지 묶어서 보자.
:100:
클릭해서 반응
:laughing:
클릭해서 반응
:raised_hands:
클릭해서 반응
반응 추가하기
답장
전달
기타
[오전 9:32]2026년 3월 13일 금요일 오전 9:32
오케이, 공개 신호 기준으로 꽤 많이 보였어 ㅋㅋ
결론부터 말하면:

저 아저씨 생산성 비결은 “코딩을 엄청 빨리 한다”보다, “코드를 직접 매번 안 읽어도 되는 운영 시스템”을 만들어놨다는 쪽이야.

네가 본
맥북 + 맥미니 여러 대,
모니터 여러 개,
터미널 엄청 많이,
에이전트 엄청 돌림,

이건 원인이라기보다 결과 같아.
진짜 핵심은 아래 구조였음.

---

1) 이 사람은 “개발자”라기보다 관제사 / 운영자에 가까움,
:100:
클릭해서 반응
:laughing:
클릭해서 반응
:raised_hands:
클릭해서 반응
반응 추가하기
답장
전달
기타
[오전 9:32]2026년 3월 13일 금요일 오전 9:32
공개 repo만 봐도 규모가 이미 수작업으로 못 버티는 수준이야.

내가 확인한 공개 수치:
open PR: 5,591,
open issue: 7,110,
labels: 104개,
default branch commit history (최근 한 달 남짓 범위 기준): 8,912,
docs 텍스트 파일도 수백 개 수준,

이 정도면 사람이 일일이
PR 읽고,
이슈 분류하고,
리뷰하고,
라벨 붙이고,
stale 정리하고,
release 확인하고,
하는 건 불가능해.
[오전 9:32]2026년 3월 13일 금요일 오전 9:32
그래서 이 사람은 “직접 다 본다”가 아니라
흐름을 통제하는 시스템을 만든 거야.

---

2) 입력부터 기계가 먹기 좋게 강제함,
이게 진짜 큼.

버그 이슈 폼이 엄청 구조적이야,
버그 리포트에 대충 “안 돼요”가 아니라 이런 걸 강제해:
bug type,
summary,
repro steps,
expected / actual,
version,
OS,
[오전 9:32]2026년 3월 13일 금요일 오전 9:32
install method,
model,
provider/routing chain,
config location,
logs/screenshots,
impact/severity,

즉, 이슈가 들어오는 순간부터 agent가 읽기 좋게 정규화돼 있음.

기능 요청도 구조화됨,
summary,
problem to solve,
proposed solution,
alternatives,
impact,
evidence/examples,
[오전 9:32]2026년 3월 13일 금요일 오전 9:32
PR 템플릿도 구조적,
PR도 그냥 “fix stuff”가 아니라:
problem,
why it matters,
what changed,
what did NOT change,
security impact,
repro + verification,
evidence,
human verification,
failure recovery,
risks and mitigations,

즉, 이 사람은 자유서술형 개발 문화가 아니라
증거/구조/체크리스트 기반 문화를 깔아둔 거야.

---
[오전 9:32]2026년 3월 13일 금요일 오전 9:32
3) 이슈/PR 분류도 자동화해놨음,
여기서 “사람 손”이 빠지는 게 엄청 많아.

경로 기반 자동 라벨링,
.github/labeler.yml 보면 파일 경로만 보고 자동으로 라벨 붙어:
channel: discord,
app: macos,
gateway,
docs,
agents,
extensions: ...,

즉 PR이 열리면
뭘 건드렸는지 바로 분류됨.

크기 라벨도 자동,
[오전 9:32]2026년 3월 13일 금요일 오전 9:32
PR size 기준도 자동 계산함:
< 50 changed lines → size: XS,
< 200 → size: S,
< 500 → size: M,
< 1000 → size: L,
그 이상 → XL,

이게 왜 중요하냐면
작은 PR 위주로 처리하는 문화를 시스템으로 강제한다는 뜻이야.

실제로 내가 본 오픈 PR 200개 샘플에서:
XS 92,
S 58,
M 22,
L 11,
XL 17,
:100:
클릭해서 반응
:laughing:
클릭해서 반응
:raised_hands:
클릭해서 반응
반응 추가하기
답장
전달
기타
[오전 9:32]2026년 3월 13일 금요일 오전 9:32
즉 200개 중 150개가 XS/S야.
이건 “큰 거 한 방”보다 작은 완료를 쏟아내는 문화라는 강력한 신호임.

AI로 이슈/PR 분류하는 스크립트도 있음,
scripts/label-open-issues.ts 보면:
open issues / open PRs를 GraphQL로 긁고,
배치 500개씩,
gpt-5.2-codex로 분류해서,
bug / enhancement / support / skill-only 라벨 붙임,

이거 보고 진짜 딱 느꼈어:

이 사람은 “AI를 코딩 보조”로 쓰는 게 아니라
backlog 운영 인력으로도 쓰고 있음.

---
[오전 9:32]2026년 3월 13일 금요일 오전 9:32
4) 작업 단위 격리가 엄청 철저함,
네가 본 “터미널 엄청 많이”의 핵심 이유가 이거 같아.

PR마다 별도 worktree,
scripts/pr에서 PR마다 아예:
.worktrees/pr-<번호>,

이런 식으로 분리해버려.

즉,
main checkout 하나,
PR review용 checkout 하나,
prepare용 checkout 하나,
다른 이슈 fix용 checkout 하나,

이렇게 각 작업이 물리적으로 분리됨.
:100:
클릭해서 반응
:laughing:
클릭해서 반응
:raised_hands:
클릭해서 반응
반응 추가하기
답장
전달
기타
[오전 9:32]2026년 3월 13일 금요일 오전 9:32
이러면 여러 에이전트를 동시에 돌려도:
브랜치 꼬임 줄고,
스테이징 사고 줄고,
“누가 뭘 건드렸는지” 명확해짐,

공개된 steipete 쪽 coding-agent 문서도 딱 이 패턴,
거기 공개 문서에 거의 대놓고 이런 철학이 나와:
background-first,
workdir isolation,
batch PR reviews,
git worktrees + tmux,
one agent per task,
live repo에서 branch 막 갈아타지 말 것,

이건 네가 본 “멀티터미널 swarm”이 우연이 아니라
명시된 운영 패턴이라는 뜻이야.
[오전 9:32]2026년 3월 13일 금요일 오전 9:32
---

5) “코드 안 보고 배포”의 진짜 뜻: 눈 대신 gate를 믿음,
이 부분이 제일 중요함.

겉으로 보면
“자기는 코드 안 보고 배포한대”,
같이 들리는데,

공개 스크립트 기준으로 보면 그건
아무 검증 없이 던진다가 아니라
검증을 사람 눈 대신 파이프라인으로 옮겼다에 가까워.

PR 파이프라인이 3단계로 쪼개져 있음,
scripts/pr 기준으로:
review-*,
:100:
클릭해서 반응
:laughing:
클릭해서 반응
:raised_hands:
클릭해서 반응
반응 추가하기
답장
전달
기타
[오전 9:32]2026년 3월 13일 금요일 오전 9:32
prepare-*,
merge-*,

즉, merge가 그냥 버튼이 아니라
리뷰 → 준비 → 병합 파이프라인임.

review 단계에서 요구하는 것,
review.json / review.md 구조를 보면:
recommendation,
findings,
nit sweep,
behavioral sweep,
issue validation,
tests,
docs,
changelog,
:100:
클릭해서 반응
:laughing:
클릭해서 반응
:raised_hands:
클릭해서 반응
반응 추가하기
답장
전달
기타
[오전 9:32]2026년 3월 13일 금요일 오전 9:32
심지어 runtime file이 바뀌면
behavioral sweep 상태,
branch-level behavior evidence,
같은 것도 강제됨.

즉 “좋아 보여요”가 아니라
기계가 검증 가능한 리뷰 아티팩트를 남기게 함.

bug-fix PR은 더 빡셈,
repo 가이드에 아예 이런 취지 규칙이 있어:
issue text만 보고 merge 금지,
AI rationale만 보고 merge 금지,
symptom evidence 필요,
root cause in code 필요,
fix touches implicated path 필요,
regression test 또는 manual proof 필요,
[오전 9:32]2026년 3월 13일 금요일 오전 9:32
즉,
“AI가 맞다고 했으니까 머지”는 금지
증거가 있어야 머지

prepare 단계,
prepare_gates가 강제하는 것:
changelog 업데이트 필수,
pnpm build,
pnpm check,
pnpm test,
docs-only면 test skip 가능,

merge 단계,
merge_verify가 확인하는 것:
draft 아님,
PR head SHA 안 바뀜,
required checks green,
[오전 9:32]2026년 3월 13일 금요일 오전 9:32
mainline drift가 관련 있으면 sync 강제,

즉 이 사람은 코드를 안 보는 게 아니라,
“merge 가능한 상태”를 훨씬 더 형식적으로 정의해둔 거야.

그래서 자기 eyeballing을 덜 해도 되는 거지.

---

6) CI도 “빠르게 대충”이 아니라 scope-aware 최적화,
생산성 높은 사람들 보면 CI를 두 가지로 다룸:
하나: 품질 장치,
둘: 속도 최적화 대상,

여기도 딱 그래.
[오전 9:32]2026년 3월 13일 금요일 오전 9:32
docs-only 탐지,
docs만 바뀌면 무거운 job 안 돌게 함.

changed-scope 탐지,
바뀐 범위 기준으로:
node,
macOS,
android,
windows,
skills_python,

같은 lane을 선택적으로 돌림.

build artifact 재사용,
한 번 build한 dist를 artifact로 올려서
다른 job들이 재사용함.
[오전 9:32]2026년 3월 13일 금요일 오전 9:32
runner 자체도 센 편,
여러 workflow가 blacksmith-16vcpu 같은 걸 씀.

즉 이 사람 생산성은
에이전트 수만이 아니라
CI 낭비를 줄여서 피드백 루프를 짧게 만든 것도 큼.

---

7) backlog를 무자비하게 정리함,
이게 엄청 중요함.
생산성 괴물처럼 보이는 사람들 공통점이
받아주는 양이 많아서가 아니라, 버리는 기준도 명확함 이거든.

auto-response로 자동 닫음,
라벨 붙으면 자동으로:
[오전 9:32]2026년 3월 13일 금요일 오전 9:32
skill-only면 close,
support면 Discord로 유도,
no-ci-pr면 close,
too-many-prs면 close,
spam/invalid면 close/lock,

active PR limit까지 있음,
자동 응답 규칙에 작성자 active PR 10개 제한이 들어 있음.

이건 진짜 핵심 신호야.

“많이 기여해도 좋지만, maintainer가 처리 가능한 형태로 가져와라”

즉 무작정 많이 받는 게 아니라
처리 가능성을 기준으로 큐를 관리함.

stale 정책도 공격적,
:100:
클릭해서 반응
:laughing:
클릭해서 반응
:raised_hands:
클릭해서 반응
반응 추가하기
답장
전달
기타
[오전 9:32]2026년 3월 13일 금요일 오전 9:32
issue: 7일 stale, 5일 후 close,
PR: 5일 stale, 3일 후 close,
closed issue는 48시간 뒤 lock,

이 정도면 backlog를 “기념품”처럼 보관 안 함.
살아있는 것만 남김.

---

8) 문서가 단순 참고서가 아니라 운영 매뉴얼,
문서 구조도 신호가 많아.

내가 본 대략:
docs 텍스트 파일 수백 개,
channel docs 29,
CLI docs 47,
:100:
클릭해서 반응
:laughing:
클릭해서 반응
:raised_hands:
클릭해서 반응
반응 추가하기
답장
전달
기타
[오전 9:33]2026년 3월 13일 금요일 오전 9:33
gateway docs 33,

중요한 건 양보다 방식이야.

release도 문서로 표준화,
docs/reference/RELEASING.md 보면:
versioning 규칙,
build artifact 확인,
changelog,
validation,
npm publish,
GitHub release,
appcast,

이런 게 체크리스트화돼 있어.

즉 배포가 “감”이 아니라
:100:
클릭해서 반응
:laughing:
클릭해서 반응
:raised_hands:
클릭해서 반응
반응 추가하기
답장
전달
기타
[오전 9:33]2026년 3월 13일 금요일 오전 9:33
반복 가능한 절차임.

testing도 문서화,
docs/reference/test.md, docs/help/testing.md 보면
어떤 suite를 언제 돌리는지,
e2e/live 테스트를 언제 쓰는지,
provider/model smoke는 어떻게 보는지,
다 정리돼 있음.

결론:
문서를 읽는 순간, 사람/에이전트가 같은 방식으로 움직일 수 있게 해놨다.

---

9) multi-agent 환경에 맞춘 guardrail이 많음,
이건 진짜 실전 냄새가 남.
[오전 9:33]2026년 3월 13일 금요일 오전 9:33
scripts/committer,
이 스크립트가 하는 걸 보면:
git add . 같은 거 못 하게 막고,
파일 목록을 명시적으로 지정,
node_modules staging 금지,
먼저 staged 다 비우고,
지정한 파일만 커밋,

이건 agent 여러 개 돌릴 때 진짜 중요함.
“전체 스테이징 사고”를 시스템 차원에서 줄임.

큰 파일도 싫어함,
scripts/check-ts-max-loc.ts 기본값이 500줄이야.

즉 큰 파일 방치보다
쪼개기,
분리하기,
:100:
클릭해서 반응
:laughing:
클릭해서 반응
:raised_hands:
클릭해서 반응
반응 추가하기
답장
전달
기타
[오전 9:33]2026년 3월 13일 금요일 오전 9:33
이해 가능한 단위 유지,
를 문화로 굳힘.

AGENTS 규칙도 multi-agent 전제,
repo 가이드에도:
남의 worktree 건드리지 말기,
stash 막 쓰지 말기,
branch 함부로 바꾸지 말기,
agent마다 자기 session 가져라,

같은 식의 multi-agent 안전장치가 있음.

즉 이 사람은 이미
“한 사람이 혼자 repo를 만지는 세상”을 전제로 안 함.

---
[오전 9:33]2026년 3월 13일 금요일 오전 9:33
10) 커밋 패턴도 “작고 빠른 유지보수” 중심,
내가 긁은 최근 main 쪽 샘플에서도 제목 prefix가 대충:
fix,
refactor,
docs,
test,
build,
ci,

이런 게 많았어.

이건 큰 신호야.

즉 생산성의 정체가:
거대한 feature를 한 번에 쓰는 사람,
이 아니라
:100:
클릭해서 반응
:laughing:
클릭해서 반응
:raised_hands:
클릭해서 반응
반응 추가하기
답장
전달
기타
[오전 9:33]2026년 3월 13일 금요일 오전 9:33
작은 변화들을 엄청 빠르게 흘리는 사람,
에 가까움.

---

내가 역으로 재구성한 “저 아저씨 루틴”,
대충 이런 식일 가능성이 높아 보여:

입력 수집,
,
이슈/PR 들어옴,
auto-labeler가 component/size 분류,
auto-response가 support/spam/invalid 정리,
필요하면 AI가 backlog 분류 보조,

큐 정리,
,
작은 PR 우선,
:100:
클릭해서 반응
:laughing:
클릭해서 반응
:raised_hands:
클릭해서 반응
반응 추가하기
답장
전달
기타
[오전 9:33]2026년 3월 13일 금요일 오전 9:33
명확한 것 우선,
support성/잡음은 밖으로 보냄,
contributor active PR too many면 컷,

에이전트 투입,
,
PR/이슈마다 worktree 분리,
tmux/background session으로 agent 여러 개 띄움,
one task, one terminal/session,

사람은 직접 코딩보다 “검증 포맷” 확인,
,
review artifact,
failing/passing evidence,
behavior sweep,
changelog,
required checks,

prepare / merge,
,
:100:
클릭해서 반응
:laughing:
클릭해서 반응
:raised_hands:
클릭해서 반응
반응 추가하기
답장
전달
기타
[오전 9:33]2026년 3월 13일 금요일 오전 9:33
rebase,
gates,
required checks green,
SHA mismatch 없을 때 merge,

release,
,
checklist 따라 publish,
smoke test,
notes/changelog 업데이트,

즉 사람 손이 가는 곳은
raw coding,
보다
triage,
exceptions,
merge decision,
시스템 개선,
:100:
클릭해서 반응
:laughing:
클릭해서 반응
:raised_hands:
클릭해서 반응
반응 추가하기
답장
전달
기타
[오전 9:33]2026년 3월 13일 금요일 오전 9:33
쪽임.

---

네가 본 “멀티 맥 + 멀티 모니터 + 터미널 떼창”이 가능한 이유,
내 추정으론 이거야:

각 터미널이 레포가 아니라 “작업 슬롯”,
각 슬롯은 worktree/session으로 격리,
각 agent는 명확한 목표 + 격리된 context,
결과물은 PR/아티팩트/로그로 표준화,
사람은 terminal을 “직접 타자치는 창”보다 큐 모니터처럼 씀,

그래서 모니터가 많을수록 유리한 이유도
“한 번에 더 많이 코딩”이 아니라,
여러 agent 상태 보기,
[오전 9:33]2026년 3월 13일 금요일 오전 9:33
CI 보기,
로그 보기,
PR 큐 보기,
review/prep/merge 상태 보기,
쪽일 가능성이 큼.

즉 개발 데스크가 아니라 관제실이 되는 거지.

---

진짜 비결만 6줄로 줄이면,
입력을 구조화한다,
작업을 격리한다,
작은 PR만 빠르게 흘린다,
눈대중 대신 증거 기반 gate를 쓴다,
CI를 scope-aware로 최적화한다,
[오전 9:33]2026년 3월 13일 금요일 오전 9:33
백로그를 무자비하게 쳐낸다,

---

우리도 따라하려면 뭐부터 베끼면 되냐,
내 기준 우선순위는 이거야:

1단계: worktree 문화,
작업/PR/이슈마다 분리,
agent 하나당 작업 디렉토리 하나,

2단계: 작은 PR 강제,
size label 도입,
50줄/200줄 단위로 쪼개기,

3단계: PR 템플릿 강화,
[오전 9:33]2026년 3월 13일 금요일 오전 9:33
repro,
expected/actual,
what changed / not changed,
human verification,
rollback,
이거 필수화

4단계: review -> prepare -> merge 분리,
그냥 머지 금지,
review 아티팩트 남기기,
prepare gates 통과 후 merge,

5단계: docs-only / changed-scope CI,
안 바뀐 영역 테스트까지 다 돌리지 않기,

6단계: auto-triage / stale / close 정책,
support는 support로,
[오전 9:33]2026년 3월 13일 금요일 오전 9:33
spam/invalid는 자동 정리,
active PR 상한 두기,

7단계: explicit commit helper,
git add . 금지,
파일 단위 커밋 습관,

---

제일 중요한 해석,
네가 말한 “자기는 코드 안 보고 배포한다”는 걸
내가 공개 신호로 해석하면 이거야:

그 사람은 코드 리뷰를 포기한 게 아니라,
코드 리뷰를 사람이 즉흥적으로 하는 행위에서
구조화된 증거 수집/검증 파이프라인으로 바꿔버린 거야.
[오전 9:33]2026년 3월 13일 금요일 오전 9:33
그래서 생산성이 이상하게 높은 거고,
멀티 맥/멀티 터미널도 그 시스템 위에서 돌아가는 거야.

---

원하면 다음엔 내가 바로 이어서
“우리도 OpenClaw/에이전트 기반으로 이 스타일 흉내 내는 최소 운영 세트”
딱 현실적으로 10개 항목으로 짜줄게.

참고로 이번 분석에 본 공개 근거는 대충 이쪽이야:
openclaw/openclaw/.github/ISSUE_TEMPLATE/*,
openclaw/openclaw/.github/pull_request_template.md,
openclaw/openclaw/.github/labeler.yml,
openclaw/openclaw/.github/workflows/{labeler,auto-response,stale,ci}.yml,
openclaw/openclaw/scripts/{pr,committer,label-open-issues.ts,check-ts-max-loc.ts},
openclaw/openclaw/docs/reference/{RELEASING,test}.md,
openclaw/openclaw/docs/help/testing.md,
:100:
클릭해서 반응
:laughing:
클릭해서 반응
:raised_hands:
클릭해서 반응
반응 추가하기
답장
전달
기타
[오전 9:33]2026년 3월 13일 금요일 오전 9:33
openclaw/skills의 공개 steipete/coding-agent 문서,

클라우드 — 오전 10:012026년 3월 13일 금요일 오전 10:01
openclaw의 모든것을 다 복제한다. 코드 말고 일 하는 방법. 즉 하네스를 복제하는 작업을 시작한다. 
전략 세워봐.

티파
앱
 — 오전 10:042026년 3월 13일 금요일 오전 10:04
좋아. 근데 먼저 전제 하나 박고 갈게.

OpenClaw를 “통째로” 베끼면 망해.
베껴야 하는 건 코드도, 겉 UI도, 모니터 많은 셋업도 아니고,

일이 들어와서 → 분류되고 → 격리 실행되고 → 증거가 쌓이고 → 안전하게 merge/release 되는 운영 하네스

이거야.

내 추천은 “Kernel-first 복제 전략”이야.
겉모습 말고 운영체계의 핵심 커널부터 복제하는 방식.

---

우리가 실제로 복제할 대상,
,
복제 대상은 4개 층이야.
:100:
클릭해서 반응
:laughing:
클릭해서 반응
:raised_hands:
클릭해서 반응
반응 추가하기
답장
전달
기타
[오전 10:04]2026년 3월 13일 금요일 오전 10:04
1) Control Plane,
일이 어디로 들어오고, 어떻게 라우팅되는지
이슈/PR 템플릿,
라벨 체계,
triage rules,
queue rules,

2) Execution Plane,
에이전트가 어떻게 안전하게 병렬 실행되는지
worktree/task isolation,
session naming,
one task = one agent context,
local/remote executor,

3) Trust Plane,
“코드 안 봐도 된다”를 가능하게 만드는 검증 체계
review artifacts,
[오전 10:04]2026년 3월 13일 금요일 오전 10:04
prepare gates,
CI scope filtering,
merge invariants,

4) Memory / Ritual Plane,
사람과 에이전트가 같은 방식으로 움직이게 하는 문서
AGENTS.md,
release checklist,
testing guide,
prompt contracts,
failure recovery playbook,

---

전략 옵션 3개,
,
옵션 A. Surface clone,
[오전 10:04]2026년 3월 13일 금요일 오전 10:04
보이는 것부터 따라함
여러 맥,
여러 모니터,
터미널 많이,
대시보드,
agent 여러 개,

비추천.
이건 결과물이지 원인이 아님.

옵션 B. Tool clone,
스크립트/라벨러/CI부터 따라함
labeler,
stale,
committer,
review scripts,
[오전 10:04]2026년 3월 13일 금요일 오전 10:04
이건 나쁘지 않은데,
원칙 없이 툴만 복제하면 금방 진흙탕 돼.

옵션 C. Operating-system clone,
원칙 + 역할 + 아티팩트 + 툴 + CI + 문서를 같이 만든다

이걸 추천.
OpenClaw 스타일은 결국 이거임.

---

우리가 채택할 북극성,
,
이 하네스의 목표는 “많이 돌린다”가 아니라:

작은 작업을 빠르게 흘린다,
병렬 실행해도 안 꼬인다,
[오전 10:04]2026년 3월 13일 금요일 오전 10:04
사람이 모든 코드를 직접 보지 않아도 된다,
merge 전 증거가 남는다,
저품질 입력은 자동으로 밀어낸다,

한 줄로:

throughput를 높이되, trust를 잃지 않는 운영체계

---

복제 우선순위,
,
내 기준 우선순위는 이 순서가 맞아.

1순위: 작업 단위 격리,
이거 없으면 agent 많이 돌리는 순간 바로 사고남.
[오전 10:04]2026년 3월 13일 금요일 오전 10:04
반드시 만들 것:
task/PR/issue마다 독립 worktree,
agent마다 독립 세션,
main checkout에서 직접 branch 왔다갔다 금지,
git add . 금지,
scoped commit만 허용,

2순위: intake schema,
입력이 정리되지 않으면 agent가 헛소리하기 쉬움.

필수:
bug report template,
feature request template,
PR template,
size labels,
component labels,
[오전 10:04]2026년 3월 13일 금요일 오전 10:04
3순위: review → prepare → land 파이프라인,
이게 trust core임.

필수 단계:
review: 문제/근거/행동변화/테스트 검증,
prepare: rebase + build/check/test + changelog/gates,
land: SHA 일치 + required checks + merge metadata,

4순위: janitor automation,
백로그는 방치하면 끝장남.

필수:
stale,
spam/support redirect,
invalid/duplicate handling,
active PR limit 또는 최소한 soft limit,
[오전 10:04]2026년 3월 13일 금요일 오전 10:04
5순위: release/testing rituals,
사람 기억에 의존하면 재현 안 됨.

필수:
testing guide,
release checklist,
rollback playbook,
smoke tests,

6순위: multi-machine,
이건 제일 나중.
한 대에서 안 되는 걸 여러 대로 키우면 더 망함.

---

내가 제안하는 복제 로드맵,
,
[오전 10:04]2026년 3월 13일 금요일 오전 10:04
Phase 1 — Harness Kernel (1~2주),
목표: 한 repo에서, 한 명이, agent 몇 개를 안전하게 돌릴 수 있게

만들 것:
AGENTS.md,
작업 원칙,
branch/worktree rules,
review/merge rules,
.github/ISSUE_TEMPLATE/bug_report.yml,
.github/ISSUE_TEMPLATE/feature_request.yml,
.github/pull_request_template.md,
.github/labeler.yml,
scripts/committer,
scripts/task-review,
scripts/task-prepare,
scripts/task-land,
[오전 10:04]2026년 3월 13일 금요일 오전 10:04
핵심 규칙:
one task, one worktree,
one agent, one session,
모든 역할은 채팅 답변이 아니라 artifact를 남김,
merge는 오직 task-land를 통해서만,

이 단계에서 성공 기준:
agent 2~3개 병렬로 돌려도 repo 안 꼬임,
PR landing이 수동 ad-hoc git보다 더 안전함,
작은 작업은 30분 안에 첫 결과물이 나옴,

---

Phase 2 — Evidence Harness (2~3주),
목표: “코드 안 보고도 되는 정도”의 검증 구조 만들기

만들 것:
:100:
클릭해서 반응
:laughing:
클릭해서 반응
:raised_hands:
클릭해서 반응
반응 추가하기
답장
전달
기타
[오전 10:04]2026년 3월 13일 금요일 오전 10:04
artifacts/reviews/<id>/review.md,
artifacts/reviews/<id>/review.json,
artifacts/prep/<id>/prep.md,
artifacts/prep/<id>/gates.json,

review artifact 필수 필드:
problem statement,
evidence,
root cause hypothesis,
touched paths,
behavioral risk,
tests run / gaps,
docs impact,
recommendation,

prepare gate 필수 항목:
build pass,
[오전 10:04]2026년 3월 13일 금요일 오전 10:04
lint/typecheck pass,
tests pass,
changelog updated 여부,
docs-only skip 규칙,
head SHA lock,

이 단계의 핵심은:
사람의 감을 검증 가능한 파일로 바꾸는 것

---

Phase 3 — Queue & Janitor (2주),
목표: 입력량이 늘어도 사람 손이 질식하지 않게

만들 것:
auto labeler,
size labeler,
[오전 10:04]2026년 3월 13일 금요일 오전 10:04
support redirect,
stale workflow,
duplicate/invalid rules,
triage script,

이 단계에서 중요한 철학:
모든 걸 받아주지 않는다,
저품질 입력은 자동으로 밀어낸다,
작은 PR을 우대한다,

추천 라벨 초기 세트:
bug,
enhancement,
docs,
infra,
agent,
gateway,
[오전 10:04]2026년 3월 13일 금요일 오전 10:04
ui,
size: XS/S/M/L/XL,
support,
invalid,
duplicate,
stale,

중요:
처음부터 OpenClaw처럼 100개 넘는 라벨 만들지 마.
초반엔 10~15개면 충분해.

---

Phase 4 — Runner Orchestration (2~4주),
목표: 에이전트를 병렬 workforce처럼 쓰기

역할을 분리해:
[오전 10:04]2026년 3월 13일 금요일 오전 10:04
Triage Agent: 입력 분류,
Reviewer Agent: diff 읽고 review artifact 생성,
Preparer Agent: prep branch / gates 수행,
Merger Agent: merge invariant 확인 후 landing,
Janitor Agent: stale/support/duplicate 정리,
Release Agent: release checklist 실행,
Docs Agent: 변경사항 문서 반영,

여기서 핵심은:
역할별 prompt 분리,
역할별 output schema 고정,
역할별 실패 조건 명시,

즉 “만능 agent”를 믿지 말고
좁은 역할 + 좁은 입출력으로 쪼개.

---
[오전 10:04]2026년 3월 13일 금요일 오전 10:04
Phase 5 — CI/Observability (2주),
목표: 피드백 루프를 빠르게

필수:
docs-only detection,
changed-scope detection,
build artifact reuse,
required checks 정리,
queue metrics,
merge latency metrics,
PR size metrics,
stale close rate,
review artifact completeness,

대시보드는 이 단계부터.
그전엔 굳이 안 해도 됨.
[오전 10:04]2026년 3월 13일 금요일 오전 10:04
내 의견:
관측할 데이터가 없는데 대시보드부터 만들면 코스프레야.

---

Phase 6 — Multi-machine / Control Room (나중),
목표: 네가 본 “맥북 + 맥미니 + 모니터 여러 개” 세계

조건:
single-machine에서 이미 stable,
role separation이 됨,
artifacts가 잘 남음,
failures가 recoverable,
queue routing이 있음,

그 다음에만:
맥미니 = background executors,
[오전 10:04]2026년 3월 13일 금요일 오전 10:04
맥북 = operator console,
모니터 1 = queue,
모니터 2 = worktrees/sessions,
모니터 3 = CI/logs,
모니터 4 = PR/review board,

즉 멀티머신은 출력 증폭기지, 문제 해결기가 아님.

---

“OpenClaw 방식 복제”의 핵심 산출물,
,
내가 너라면 처음에 이 파일/명령부터 만든다.

문서,
AGENTS.md,
ops/TAXONOMY.md,
[오전 10:04]2026년 3월 13일 금요일 오전 10:04
ops/REVIEW_POLICY.md,
ops/RELEASE.md,
ops/TESTING.md,
ops/FAILURE_RECOVERY.md,

GitHub,
.github/ISSUE_TEMPLATE/bug_report.yml,
.github/ISSUE_TEMPLATE/feature_request.yml,
.github/pull_request_template.md,
.github/labeler.yml,
.github/workflows/labeler.yml,
.github/workflows/stale.yml,
.github/workflows/auto-response.yml,

스크립트,
scripts/committer,
scripts/task-review,
[오전 10:04]2026년 3월 13일 금요일 오전 10:04
scripts/task-prepare,
scripts/task-land,
scripts/triage-open-items,
scripts/size-label,
scripts/check-max-loc,
scripts/release-check,

아티팩트 폴더,
artifacts/reviews/,
artifacts/prep/,
artifacts/releases/,
artifacts/incidents/,

---

하네스 성공 기준,
,
[오전 10:04]2026년 3월 13일 금요일 오전 10:04
이건 꼭 숫자로 잡아야 해.

내 추천 KPI:

80%+ 작업이 구조화된 입력으로 들어옴,
90%+ merge가 review -> prepare -> land 경유,
median PR size 200 changed lines 이하,
모든 active agent가 고유 worktree/session 가짐,
task 시작 후 30분 내 첫 artifact,
stale/support/noise 항목의 대부분 자동 정리,
ad-hoc git landing 비율 10% 이하,

---

절대 하지 말아야 할 실수,
,
1) UI부터 만들기,
[오전 10:04]2026년 3월 13일 금요일 오전 10:04
제일 흔한 실패.
대시보드 있어도 underlying ritual 없으면 무용지물.

2) agent를 만능 노동자로 보기,
좁은 역할로 쪼개지 않으면 품질 흔들림.

3) 처음부터 대규모 taxonomy 만들기,
라벨 100개는 스케일 뒤에 오는 것.
처음엔 작게.

4) 증거 없는 merge 허용,
“agent가 그렇다던데요” 금지.
artifact, logs, tests가 있어야 함.

5) worktree/session 격리 없이 병렬화,
이건 그냥 폭탄 돌리기.
:100:
클릭해서 반응
:laughing:
클릭해서 반응
:raised_hands:
클릭해서 반응
반응 추가하기
답장
전달
기타
[오전 10:04]2026년 3월 13일 금요일 오전 10:04
6) multi-machine 너무 빨리 들어가기,
한 대에서 repeatable하지 않으면 두 대는 chaos 두 배.

---

내가 추천하는 실제 시작 순서,
,
진짜로 시작한다면 이 순서가 제일 좋음:

Week 1,
원칙 문서 작성,
issue/PR template 만들기,
최소 라벨 체계 만들기,
committer 만들기,

Week 2,
review / prepare / land 스크립트 만들기,
[오전 10:04]2026년 3월 13일 금요일 오전 10:04
review/prep artifact schema 정의,
required checks 정리,

Week 3,
worktree-per-task 실행기 만들기,
session naming 규칙,
agent role 분리,

Week 4,
stale/auto-response/triage 자동화,
size label 도입,
PR queue 운영 시작,

Week 5+,
changed-scope CI,
release/test playbook 정교화,
observability,
[오전 10:04]2026년 3월 13일 금요일 오전 10:04
그 다음에야 dashboard / multi-machine,

---

내 최종 추천 한 줄,
,
OpenClaw의 “일하는 방식”을 복제하려면,
에이전트를 많이 띄우는 게 아니라
“입력 계약 + 작업 격리 + 증거 아티팩트 + merge gate + backlog janitor”를 먼저 복제해야 해.

이 5개가 커널이야.

---

원하면 내가 다음 답에서 바로 이어서
“Harness Clone v0.1 설계안” 형태로
[오전 10:04]2026년 3월 13일 금요일 오전 10:04
폴더 구조,
파일 목록,
스크립트 이름,
각 역할 prompt contract,
2주 실행 체크리스트,

까지 바로 짜줄게.

딱 하나만 먼저 정하자:
이 하네스를 1차로 적용할 대상이 “repo 하나”야, 아니면 “여러 프로젝트 운영 체계”야?

클라우드 — 오전 10:292026년 3월 13일 금요일 오전 10:29
장기적으론 여러 프로젝트지 ㅇㅇ
오픈클로의 일하는 방식을 복제해야지. harness만

티파
앱
 — 오전 10:332026년 3월 13일 금요일 오전 10:33
전략안을 파일로도 남겨둘게. 나중에 이걸 베이스로 v0.1 설계/실행으로 이어가기 편하게.
[오전 10:33]2026년 3월 13일 금요일 오전 10:33
좋아, 그럼 방향이 완전 명확해졌어.

우리가 복제할 건 OpenClaw 제품이 아니라
OpenClaw식 작업 운영체계(harness) 야.

한 줄로 정의하면:

여러 프로젝트 위에 얹히는, 에이전트 중심 개발 운영 OS
= 입력 정리 + 작업 격리 + 증거 아티팩트 + 안전한 merge/release + backlog janitor

그리고 이건 각 repo 안에서 따로 노는 스크립트 모음으로 만들면 안 되고,
공용 harness-core + 프로젝트별 얇은 overlay 구조로 가야 해.

파일로도 저장해뒀어:
.omx/plans/harness-clone-strategy.md,

---
[오전 10:33]2026년 3월 13일 금요일 오전 10:33
우리가 만들 대상,
1) 복제할 것,
structured intake,
triage/queue 운영,
one task = one isolated workspace,
review → prepare → land 파이프라인,
artifact-first 검증,
stale/support/spam janitor,
release/testing ritual,
역할 분리된 agent 운영,

2) 복제하지 않을 것,
OpenClaw 제품 코드,
exact label 100개 세트,
대시보드/그래픽 UI 우선주의,
“모니터 많고 터미널 많음” 같은 겉모습,
[오전 10:33]2026년 3월 13일 금요일 오전 10:33
만능 agent 하나로 다 때우는 방식,

---

핵심 전략,
A. 구조는 무조건 “중앙 코어 + 얇은 프로젝트 어댑터”,
이게 제일 중요해.

harness-core,
공용 운영체계 저장소/패키지:
role contracts,
scripts,
schemas,
GitHub templates,
CI workflow templates,
janitor rules,
[오전 10:33]2026년 3월 13일 금요일 오전 10:33
release/test playbooks,
project manifest schema,

각 프로젝트 repo,
얇은 overlay만 둠:
.harness/project.yaml,
이슈/PR 템플릿,
labeler/stale wiring,
local workflow glue,
repo-specific commands,

즉,
운영 원칙은 중앙화
빌드/테스트/릴리즈 커맨드는 repo별 선언화
이렇게 가야 여러 프로젝트로 확장 가능해.

---
[오전 10:33]2026년 3월 13일 금요일 오전 10:33
B. 작업 흐름은 7단계로 고정,
내 추천 canonical flow는 이거야:

Intake,
issue / task / PR 입력 정규화,
Triage,
bug / feature / docs / support / invalid / size / risk 분류,
Task Package,
task id 발급,
repo/base/manifest 바인딩,
isolated workspace 생성,
Review,
review artifact 생성,
Prepare,
rebase/sync + build/check/test + policy gates,
Land,
SHA/CI/artifact invariant 검증 후 merge,
[오전 10:33]2026년 3월 13일 금요일 오전 10:33
Release / Janitor,
release checklist, stale, support redirect, duplicate 처리,

핵심은:
각 단계는 상태 전이만 하는 게 아니라 artifact를 남겨야 함

---

C. 가장 먼저 복제해야 할 커널 5개,
이 5개가 진짜 OpenClaw식 핵심이야.

Task isolation,
,
one task = one worktree/workspace,
one agent = one session,
shared checkout에서 branch 왔다갔다 금지,
broad staging 금지 (git add . 금지급),
[오전 10:33]2026년 3월 13일 금요일 오전 10:33
Structured intake,
,
bug report template,
feature request template,
PR template,
최소 라벨 taxonomy,
size/risk/component 분류,

Artifact-first trust,
,
review/prep/land는 말로 하지 말고 파일/JSON으로 남김:
review.md / review.json,
prep.md / gates.json,
land metadata,

Scripted merge path,
,
merge는 인간 감으로 하지 않고:
review artifact 존재,
prepare artifact 존재,
[오전 10:33]2026년 3월 13일 금요일 오전 10:33
head SHA 일치,
required checks pass,
risky drift 검증,
이후에만 land

Janitor automation,
,
stale,
support redirect,
invalid/spam/duplicate handling,
active queue pressure 관리,

---

D. 역할은 만능 agent 말고 좁게 쪼갬,
이건 거의 필수야.

추천 역할:
:100:
클릭해서 반응
:laughing:
클릭해서 반응
:raised_hands:
클릭해서 반응
반응 추가하기
답장
전달
기타
[오전 10:33]2026년 3월 13일 금요일 오전 10:33
Triage Agent,
Planner Agent,
Implementer Agent,
Reviewer Agent,
Preparer Agent,
Lander Agent,
Janitor Agent,
Release Agent,
Human Operator,

핵심:
역할별 입력/출력 계약을 좁게 만들수록 품질이 올라감

예를 들면:
Reviewer는 코드 수정 거의 안 함, review artifact만 강하게 남김,
Preparer는 feature 사고보다 gates 실행이 중심,
Lander는 merge 판단만 함,
[오전 10:33]2026년 3월 13일 금요일 오전 10:33
---

E. 멀티프로젝트 확장을 위해 “manifest 기반”으로 가야 함,
각 프로젝트가 다른 건 원칙이 아니라 명령어/경로잖아.

그래서 repo마다 이런 manifest만 있으면 돼:
install command,
build command,
check command,
test command,
docs check command,
release smoke command,
changelog policy,
risky path rules,

이렇게 하면 harness-core는 그대로 두고,
repo별로는 선언만 바꾸면 됨.
[오전 10:33]2026년 3월 13일 금요일 오전 10:33
---

권장 아키텍처,
내 기준으로는 이 4층 구조가 좋아.

Control Plane,
,
queue,
task registry,
repo registry,
policies,
label taxonomy,
agent role contracts,

Execution Plane,
,
workspace/worktree allocator,
session launcher,
[오전 10:33]2026년 3월 13일 금요일 오전 10:33
agent runner,
logs/status collection,

Trust Plane,
,
review schemas,
prepare gates,
land invariants,
CI required checks,
release checklist,

Memory / Ritual Plane,
,
AGENTS.md,
playbooks,
testing guide,
release guide,
failure recovery,
janitor policy,
:100:
클릭해서 반응
:laughing:
클릭해서 반응
:raised_hands:
클릭해서 반응
반응 추가하기
답장
전달
기타
[오전 10:33]2026년 3월 13일 금요일 오전 10:33
---

로드맵,
Phase 0 — Spec,
지금 해야 할 것:
무엇을 복제하고 무엇을 복제하지 않는지 명시,
상태 전이 정의,
artifact schema 정의,
역할 정의,
최소 taxonomy 정의,

산출물:
AGENTS.md,
ops/PRINCIPLES.md,
ops/REVIEW_POLICY.md,
ops/TESTING.md,
[오전 10:33]2026년 3월 13일 금요일 오전 10:33
ops/RELEASE.md,
ops/JANITOR.md,

---

Phase 1 — Kernel,
한 repo에서 돌아가는 최소 운영체계 제작

필수 파일/스크립트:
bug/feature/PR template,
.github/labeler.yml,
stale/auto-response workflows,
scripts/committer,
scripts/task-create,
scripts/task-review,
scripts/task-prepare,
scripts/task-land,
[오전 10:33]2026년 3월 13일 금요일 오전 10:33
성공 조건:
agent 2~3개 병렬로 돌려도 안 꼬임,
수동 merge보다 scripted land가 더 안전하고 빠름,

---

Phase 2 — Trust hardening,
“코드 안 보고도 되는 정도”의 검증을 시스템화

필수 artifact:
review artifact,
prepare artifact,
land metadata,

필수 invariant:
reviewed head와 prepared head 일치,
CI green,
[오전 10:33]2026년 3월 13일 금요일 오전 10:33
docs/changelog policy 통과,
risky change는 더 강한 evidence 요구,

성공 조건:
merge가 사람 감보다 artifact/CI에 더 많이 의존하게 됨,

---

Phase 3 — Shared harness-core,
이제 공용화

해야 할 것:
공용 repo/package 분리,
per-project manifest 설계,
repo bootstrap/sync 메커니즘,
adapter interface 설계,
[오전 10:33]2026년 3월 13일 금요일 오전 10:33
성공 조건:
두 번째 repo 붙일 때 스크립트 복붙이 아니라,
manifest + overlay만 추가하면 됨

---

Phase 4 — Multi-project rollout,
repo registry,
project archetype별 adapter,
공용 queue rules,
cross-repo janitor,
cross-repo metrics,

이 단계부터 진짜 “OpenClaw식 운영” 느낌이 살아.

---
[오전 10:33]2026년 3월 13일 금요일 오전 10:33
Phase 5 — Control room / observability,
이건 나중.

그때 만들 것:
queue dashboard,
review/prep/land status board,
artifact completeness metrics,
PR size / lead time / stale rate,
failure pattern board,

중요:
데이터와 ritual이 먼저고 대시보드는 나중.

---

처음부터 꼭 박아야 할 규칙,
[오전 10:33]2026년 3월 13일 금요일 오전 10:33
one task, one workspace,
one agent, one session,
broad staging 금지,
no evidence, no land,
작은 PR 우대,
support/spam/noise는 자동으로 밖으로 밀기,
bypass path는 예외로만 허용,
사람이 직접 diff 다 읽는 구조를 목표로 하지 않기,

---

KPI도 처음부터 잡자,
이건 진짜 중요해.

초기 목표 예시:
80% 이상 structured intake,
90% 이상 scripted land path 경유,
:100:
클릭해서 반응
:laughing:
클릭해서 반응
:raised_hands:
클릭해서 반응
반응 추가하기
답장
전달
기타
[오전 10:33]2026년 3월 13일 금요일 오전 10:33
median PR size 200 changed lines 이하,
task 시작 후 30분 내 첫 artifact,
stale/support/noise 자동 처리 비중 증가,
second repo onboarding 시간 급감,

---

내가 보는 최종 형태,
장기적으로 이 harness는 이런 모습이 돼야 해:

공용 harness-core,
프로젝트별 manifest,
역할별 agent contract,
artifact-first workflow,
merge/release safety gates,
cross-project queue 운영,
operator는 코더보다 관제사에 가까운 역할,
[오전 10:33]2026년 3월 13일 금요일 오전 10:33
즉,
여러 프로젝트를 에이전트로 굴릴 수 있게 만드는 “운영 하네스” 자체를 만드는 거야.

---

내 추천 결론,
지금부터는 이렇게 가면 돼:

OpenClaw-style Harness v0.1 명세 작성,
pilot repo 하나에서 kernel 검증,
artifact/review/land pipeline 고정,
그다음 shared harness-core로 분리,
마지막에 여러 프로젝트로 확장,

---

다음으로는 한 단계 더 내려가서
