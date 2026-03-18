# ontlab: 코드베이스용 온톨로지 런타임 하네스

이 번들은 **“커지는 온톨로지 저장소”** 가 아니라,  
**“어떤 코드베이스든 넣으면 그 코드베이스의 ontology instance를 생성하고,  
그 인스턴스로 질문에 답하며, 답변 실패를 이용해 생성 능력을 계속 개선하는 시스템”** 을 위한 하네스다.

## 이 번들의 핵심 정의

- `seed repo` = 온톨로지 **생성 능력**을 개선하기 위한 테스트/회귀 코퍼스
- `target repo` = 실제 ontology instance를 생성하고 질문에 답할 대상
- `core ontology` = 작고 안정적인 공통 스키마
- `pack` = 언어/프레임워크/인프라 해석기
- `instance` = 특정 target repo에 대해 생성된 그래프/색인/질문셋/보고서

## 가장 중요한 원칙

1. seed repo 사실을 target repo 사실과 섞지 않는다.
2. 커지는 것은 core ontology가 아니라 **pack과 평가 능력**이다.
3. 답변은 항상 target repo에서 추출된 evidence 기반이어야 한다.
4. 실패한 답변은 “어떤 pack/추출/질문/근거가 약한지”로 환원되어야 한다.
5. 한 번에 하나의 작은 개선만 승격한다.

## 구조

- `ARCHITECTURE.ko.md` — 전체 구조와 루프
- `AGENTS.md` — Codex 운영 규칙
- `.codex/config.toml` — 프로젝트 전용 Codex 멀티에이전트 설정
- `.codex/agents/*.toml` — 프로젝트 전용 서브에이전트 정의
- `.codex/README.md` — project-local config 로딩 주의사항
- `cycle_runs/` — cycle별 파일 기반 상태, trace, outputs
- `skills/` — 반복 워크플로
- `ontology/core/` — 작은 공통 스키마
- `evaluator/` — 질문셋, 루브릭, 시나리오
- `scripts/` — 사이클 운영 보조 스크립트
- `instances/` — target repo별 생성물 저장 위치

## 권장 시작 순서

1. 이 repo를 Codex 작업공간으로 연다.
2. `AGENTS.md`, `.codex/config.toml`, `.codex/agents/` 구성을 읽는다.
   만약 현재 Codex build가 project-local `.codex/config.toml` 을 자동 로드하지 않으면, `.codex/README.md` 지침대로 `~/.codex/config.toml` 에 agent 블록을 병합한다.
3. 새 target repo를 골라 `scripts/bootstrap_target_instance.py` 로 인스턴스 디렉터리를 만든다.
4. cycle을 시작할 때 `scripts/init_cycle_run.py` 로 `cycle_runs/<cycle-id>/` 상태 디렉터리를 만든다.
5. 실제 격리가 필요하면 `scripts/create_cycle_worktree.py` 로 `cycle.json` 의 worktree / branch 계획을 물리 worktree로 만든다.
6. Codex에 `prompts/codex_mission_prompt_ko.md`, `prompts/cycle_runner_prompt_ko.md`, `prompts/promoter_prompt_ko.md` 중 필요한 것을 준다.
7. 단계 전환과 실행 흔적은 `scripts/log_cycle_event.py` 로 `cycle_runs/<cycle-id>/trace/events.jsonl` 에 남긴다.
8. 먼저 “답변 실패 분류 → 가장 작은 pack 수정 → 재평가” 사이클만 반복한다.
9. 병렬 batch가 필요하면 `scripts/plan_cycle_batch.py` 와 `scripts/fanin_cycle_results.py` 로 fan-out / fan-in 을 관리한다.
10. seed 회귀는 `seed_regression_runner` 또는 기존 평가 스크립트로 분리 검증한다.

## 포함된 보조 스크립트

- `scripts/bootstrap_target_instance.py`
- `scripts/plan_next_cycle.py`
- `scripts/summarize_eval_failures.py`
- `scripts/init_cycle_run.py`
- `scripts/create_cycle_worktree.py`
- `scripts/log_cycle_event.py`
- `scripts/plan_cycle_batch.py`
- `scripts/fanin_cycle_results.py`

이 스크립트들은 완성된 오케스트레이터가 아니라, Codex가 작업하기 좋은 **정리된 입력물**을 만드는 보조 도구다.
