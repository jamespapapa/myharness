---
name: promote-smallest-safe-change
description: Promote only small, measured improvements that help target-repo answer quality.
---

# 목적

작은 수정만 측정 기반으로 승격한다.

# 승격 조건

- target repo answer quality 개선
- seed regression 큰 악화 없음
- 근거 coverage 악화 없음
- false confidence 증가 없음
- rollback 가능

# 절차

1. cycle report를 읽는다.
2. `cycle_runs/<cycle-id>/outputs/decision.json` 또는 fan-in summary를 읽는다.
3. single-promoter 관점에서 non-conflicting cycle만 본다.
4. before/after를 비교한다.
5. promote / defer / rollback 중 하나를 정한다.
6. 이유를 5줄 이내로 요약한다.
