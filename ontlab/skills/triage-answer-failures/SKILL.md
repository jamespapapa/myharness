---
name: triage-answer-failures
description: Turn weak answers into a categorized, fixable backlog for the next cycle.
---

# 목적

나쁜 답변을 “어떤 종류의 시스템 결핍인지”로 바꾼다.

# 실패 버킷

- missing evidence
- missing edge / flow link
- missing framework rule
- retrieval failure
- should abstain
- rubric mismatch

# 절차

1. failed answer를 읽는다.
2. expected evidence가 무엇이었는지 쓴다.
3. 현재 시스템이 왜 그 evidence를 못 잡았는지 쓴다.
4. 가장 작은 개선 1개만 고른다.
5. `reports/next-cycle-brief.md`에 기록한다.
6. cycle이 열려 있다면 `cycle_runs/<cycle-id>/input/selected_gap.json`에도 같은 gap 요약을 남긴다.
