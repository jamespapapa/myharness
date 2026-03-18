# AGENTS.md

## Mission

이 repository의 목표는 **seed repo 사실을 축적하는 것**이 아니다.  
목표는 **target codebase를 ontology-backed QA runtime으로 변환하는 생성 시스템**을 만드는 것이다.

항상 아래를 기억하라.

- seed repo = regression / archetype / failure-driven improvement corpus
- target repo = ontology instance를 생성하고 질문에 답할 실제 대상
- 커지는 것은 core ontology가 아니라 pack, evaluator, answer quality이다.

## Non-goals

- seed repo 내용을 knowledge base처럼 답변에 사용하지 말 것
- target repo 사실과 seed repo 사실을 섞지 말 것
- core ontology를 자주 바꾸지 말 것
- 한 번에 큰 구조 개편을 하지 말 것
- “그럴듯한 답변”을 위해 근거 없는 추론을 하지 말 것

## What good work looks like

좋은 작업은 다음 순서를 따른다.

1. Plan
2. Build / patch the smallest safe change
3. Run tests / evals
4. Observe failures
5. Repair or rollback
6. Update docs / reports / cycle state files
7. Repeat

## Operating rules

### 1) Always work from a failure or explicit gap
다음 중 하나가 없으면 큰 변경을 시작하지 말 것.

- failed answer
- failed benchmark
- unresolved pattern
- missing edge class
- low-confidence retrieval pattern

### 2) Change one thing at a time
한 사이클에서 아래 중 하나만 바꿔라.

- one extractor/pack rule
- one evidence selection rule
- one question taxonomy rule
- one suppression/ignore rule
- one evaluation rubric rule

### 3) Preserve evidence discipline
답변/추론/보고서는 반드시 아래를 남겨라.

- file path
- symbol / route / config key / dependency name
- why this evidence supports the claim
- confidence
- what remains uncertain

### 4) Prefer abstention over hallucination
근거가 부족하면 “모르겠다 / 추가 근거 필요”를 선택하라.

### 5) Keep core ontology stable
core ontology 변경은 다음 조건을 모두 만족할 때만 제안하라.

- pack으로는 표현 불가
- 최소 2개 이상의 seed archetype에서 반복 재현
- target repo answer quality에 실측 개선
- migration plan 존재

### 6) Externalize cycle state
cycle 상태는 채팅이 아니라 파일로 남겨라.

- 각 cycle은 `cycle_runs/<cycle-id>/` 를 가진다.
- 최소 산출물:
  - `cycle_runs/<cycle-id>/cycle.json`
  - `cycle_runs/<cycle-id>/trace/events.jsonl`
  - `cycle_runs/<cycle-id>/outputs/decision.json`
  - `cycle_runs/<cycle-id>/outputs/report.md`
- stage가 바뀔 때마다 상태 파일을 갱신하라.
- 가능하면 `scripts/init_cycle_run.py` 와 `scripts/log_cycle_event.py` 를 사용하라.
- isolated worktree / branch / instance tmp dir 정보를 `cycle.json` 에 남겨라.

### 7) Parallel cycles require fan-out / fan-in discipline
병렬 cycle은 허용되지만 아래를 지켜라.

- fan-out: non-conflicting gap만 같은 batch에 넣는다.
- conflict key 기본 단위:
  - `file:<path>`
  - `pack:<name>`
  - `resource:<name>`
  - `skill:<name>`
- 각 cycle은 별도 worktree / branch / cycle dir / instance tmp dir 를 가진다.
- fan-in: patch diff, eval delta, seed regression, changed files, promotion proposal만 중앙에 모은다.
- single-promoter만 promote / defer / rollback 을 확정한다.

### 8) Stop conditions must be explicit
“완성도가 높아질 때까지”는 감이 아니라 규칙이어야 한다.

- target weighted score 임계치 도달 시 pause
- evidence coverage 임계치 도달 시 pause
- hallucination-grade failure가 0이면 pause
- 최근 5 cycle improvement가 임계치 미만이면 pause
- 같은 failure taxonomy가 3회 연속 개선되지 않으면 human review queue로 이동

## Subagent policy

### Exploration tasks
아래 서브에이전트를 병렬로 활용할 수 있다.

- `repo_sampler`
- `ontology_instance_builder`
- `qa_designer`
- `answer_gap_critic`
- `evaluator`
- `seed_regression_runner`
- `promoter`
- `pack_patcher`

### Write authority
- 탐험/분석용 서브에이전트는 read-only
- 실제 파일 수정은 `pack_patcher` 또는 부모 에이전트만 수행
- `pack_patcher`는 자기 isolated worktree 안에서만 write 가능
- `promoter`는 fan-in 산출물과 승격 메타데이터만 갱신할 수 있으며 pack code는 수정하지 않는다
- promotion report 없이 승격 금지

## Required outputs per cycle

각 사이클은 아래를 반드시 남겨야 한다.

1. `reports/cycle-<timestamp>.md`
2. `cycle_runs/<cycle-id>/cycle.json`
3. `cycle_runs/<cycle-id>/trace/events.jsonl`
4. `cycle_runs/<cycle-id>/outputs/decision.json`
5. `cycle_runs/<cycle-id>/outputs/report.md`
6. before / after metrics
7. changed files list
8. unresolved / answer failure delta
9. keep / rollback decision
10. next best small change

## Default cycle objective

기본 목적은 “새 ontology 개념 추가”가 아니라:
- target repo 질문 품질 향상
- evidence coverage 향상
- abstention 품질 향상
- false confidence 감소
