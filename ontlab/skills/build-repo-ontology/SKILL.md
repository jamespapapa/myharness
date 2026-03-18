---
name: build-repo-ontology
description: Build or refresh a target repository ontology instance without contaminating it with seed repo facts.
---

# 목적

특정 target repo에 대해 ontology instance를 생성한다.

# 반드시 지킬 것

- seed repo fact를 답변 근거로 사용하지 않는다.
- evidence를 남기지 못하는 사실은 낮은 confidence로 표시하거나 보류한다.
- 구조/흐름/인터페이스/설정/인프라 정보를 분리해 수집한다.

# 절차

1. target repo 범위를 정한다.
2. 현재 extractor / pack으로 instance를 생성한다.
3. 병렬 cycle이면 `instances/<repo>/tmp/<cycle-id>/` 아래 isolated output 경로를 사용한다.
4. 부족한 질문 영역을 기록한다.
5. `instances/<repo>/reports/build-report.md`에 남긴다.

# 출력물

- instance graph/index
- build report
- unresolved evidence list
