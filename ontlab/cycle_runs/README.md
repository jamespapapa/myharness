# cycle_runs/

이 디렉터리는 ontlab의 **사이클 상태 외부화 레이어**다.

목표:
- 각 사이클의 입력, 실행 흔적, 산출물, 판정을 파일로 남긴다.
- 병렬 fan-out 시 서로 다른 cycle이 충돌 없이 작업하도록 격리 정보를 남긴다.
- fan-in 시 single-promoter가 promote / defer / rollback 을 근거 기반으로 결정할 수 있게 한다.

## 기본 구조

각 cycle은 다음 구조를 가진다.

```text
cycle_runs/
  <cycle-id>/
    cycle.json
    input/
      target_repo.txt
      selected_gap.json
      prompt.txt
    trace/
      commands.jsonl
      codex_trace.jsonl
      approvals.jsonl
      events.jsonl
    artifacts/
      before_eval.json
      after_eval.json
      seed_regression.json
      patch.diff
      files_changed.txt
    outputs/
      decision.json
      report.md
      next_cycle_brief.md
  templates/
```

## `cycle.json` 핵심 필드

- `cycle_id`
- `target`
- `status`
- `current_phase`
- `selected_gap`
- `before_score`
- `after_score`
- `seed_regression_pass`
- `worktree`
- `branch`
- `instance_tmp`
- `conflict_keys`
- `changed_files`
- `parent_cycle`

샘플 스키마는 `cycle_runs/templates/cycle.json` 을 본다.

## Fan-out 규칙

- 같은 batch에는 서로 충돌하지 않는 gap만 넣는다.
- 충돌 판단 기본 키:
  - `file:<path>`
  - `pack:<name>`
  - `resource:<name>`
  - `skill:<name>`
- 각 cycle은 아래를 독립적으로 가진다.
  - 별도 worktree
  - 별도 branch
  - 별도 `cycle_runs/<cycle-id>/`
  - 별도 `instances/<target>/tmp/<cycle-id>/`
- `seed_regression_runner` 는 각 cycle의 patch를 seed corpus에 대해 독립적으로 검증한다.

## Fan-in 규칙

- fan-in은 각 cycle의 결과만 모은다.
- 최소 취합 항목:
  - `changed_files`
  - target before / after score
  - seed regression pass 여부
  - promotion proposal
  - conflict keys
- integrated re-eval 없이 mainline 승격하지 않는다.

## Single-promoter 규칙

- mainline 승격 결정은 한 주체만 한다.
- `promoter` 서브에이전트나 부모 에이전트만 promote / defer / rollback 을 확정한다.
- non-conflicting winner만 fan-in 후 통합 평가를 다시 돌린다.

## Stop 조건

- target weighted score가 기준에 도달하면 pause
- evidence coverage가 기준에 도달하면 pause
- hallucination-grade failure가 0이면 pause
- 최근 5 cycle 개선폭이 임계치 미만이면 pause
- 같은 failure taxonomy가 3회 연속 개선되지 않으면 human review queue로 이동

## 관련 스크립트

- `scripts/init_cycle_run.py`
- `scripts/create_cycle_worktree.py`
- `scripts/log_cycle_event.py`
- `scripts/plan_cycle_batch.py`
- `scripts/fanin_cycle_results.py`
