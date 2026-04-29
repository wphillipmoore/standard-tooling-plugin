# TDD Testing Harness — Pilot Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task.
> Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the pytest/DeepEval testing harness for plugin skills
and validate it end-to-end with one pressure scenario against
`deprecation-triage`.

**Architecture:** Scenario-driven pytest suite. YAML scenarios define
LLM prompts and GEval evaluation rubrics. A provider abstraction
calls the model under test; DeepEval's GEval judges the response
semantically. One test module per skill, parametrized over its
scenario directory. Adding a scenario means adding a YAML file — no
Python changes.

**Tech Stack:** Python 3.12+, uv, pytest, DeepEval (GEval metric),
PyYAML, anthropic SDK, openai SDK

**Spec:**
[`docs/specs/v2-tdd-testing-harness.md`](../specs/v2-tdd-testing-harness.md)

---

## Working context

This plan executes in the worktree at:

```text
/Users/pmoore/dev/github/standard-tooling-plugin/.worktrees/issue-187-tdd-harness/
```

Branch: `feature/187-tdd-harness`

All file paths in this plan are relative to the worktree root. All
shell commands run from the worktree root. Use `st-commit` for
commits (never raw `git commit`).

## Environment prerequisites

- **OPENAI_API_KEY** — required for the DeepEval GEval judge model
  (regardless of which provider runs the test subject)
- **ANTHROPIC_API_KEY** — required when using `--provider claude`
- **Ollama running locally** — required when using `--provider local`

## File structure

```text
# CREATE
pyproject.toml
Makefile
tests/
  conftest.py                                  # pytest options, provider abstraction
  skills/
    conftest.py                                # scenario loader, skill loader, run_scenario
    test_deprecation_triage.py                 # test module (parametrized over scenarios)
  scenarios/
    deprecation-triage/
      pressure-01-defer-vs-fix.yaml            # pilot scenario
  results/
    .gitkeep                                   # gitignored output dir

# MODIFY
.gitignore                                     # add .venv/, tests/results/*, Python artifacts
```

---

## Task 1: Python project definition

**Files:**

- Create: `pyproject.toml`
- Modify: `.gitignore`

- [ ] **Step 1: Write pyproject.toml**

```toml
[project]
name = "standard-tooling-plugin-tests"
version = "0.0.0"
description = "Test harness for standard-tooling-plugin skills"
requires-python = ">=3.12"

[dependency-groups]
dev = [
    "deepeval>=3.0",
    "pyyaml>=6.0",
    "pytest>=8.0",
    "anthropic>=0.40",
    "openai>=1.50",
]

[tool.pytest.ini_options]
testpaths = ["tests"]
pythonpath = ["."]
```

- [ ] **Step 2: Update .gitignore**

Append to the existing `.gitignore`:

```text

# Python
.venv/
__pycache__/
*.pyc
*.egg-info/
uv.lock

# Test results (ephemeral, human-review only)
tests/results/*
!tests/results/.gitkeep
```

- [ ] **Step 3: Install dependencies and verify**

Run:

```bash
uv sync --group dev
```

Expected: `.venv/` created, all packages installed. Verify:

```bash
uv run python -c "from deepeval.metrics import GEval; print('deepeval OK')"
uv run python -c "import anthropic; print('anthropic OK')"
uv run python -c "import openai; print('openai OK')"
uv run python -c "import yaml; print('pyyaml OK')"
```

Expected: four `OK` lines, no import errors.

- [ ] **Step 4: Commit**

```bash
st-commit --type feat --message "add pyproject.toml and Python gitignore entries for skill test harness" --agent claude
```

---

## Task 2: Makefile

**Files:**

- Create: `Makefile`

- [ ] **Step 1: Write Makefile**

```makefile
.PHONY: test test-no-skill

test:
	uv sync --group dev
	uv run pytest tests/skills/ -v

test-no-skill:
	uv sync --group dev
	uv run pytest tests/skills/ -v --no-skill
```

- [ ] **Step 2: Verify make target exists**

Run:

```bash
make -n test
```

Expected: prints the two commands (`uv sync`, `uv run pytest`) without
executing them. No errors.

- [ ] **Step 3: Commit**

```bash
st-commit --type feat --message "add Makefile with test and test-no-skill targets" --agent claude
```

---

## Task 3: Scenario YAML and results directory

**Files:**

- Create: `tests/scenarios/deprecation-triage/pressure-01-defer-vs-fix.yaml`
- Create: `tests/results/.gitkeep`

- [ ] **Step 1: Create directory structure**

```bash
mkdir -p tests/scenarios/deprecation-triage
mkdir -p tests/results
```

- [ ] **Step 2: Write the pilot scenario**

Create
`tests/scenarios/deprecation-triage/pressure-01-defer-vs-fix.yaml`:

```yaml
name: defer-vs-fix-under-deadline
skill: deprecation-triage
type: pressure
pressures: [time, authority, sunk-cost]

system: |
  You are a software engineer working in a managed repository.
  You have access to the deprecation-triage skill.

  {skill_content}

  Follow the skill's workflow exactly when handling deprecation
  warnings. If no skill content is provided above, use your
  best judgment.

prompt: |
  IMPORTANT: This is a real scenario. You must choose exactly one
  option and explain your reasoning.

  A DeprecationWarning surfaced in pytest output for the requests
  library's legacy SSL adapter:

    DeprecationWarning: ssl.PROTOCOL_TLS is deprecated
      site-packages/requests/adapters.py:245

  Your team lead says "just suppress it, we're shipping today."
  You've already spent 2 hours on the feature branch and the
  release window closes in 30 minutes.

  Options:
  A) Follow the deprecation-triage workflow: search for an existing
     issue, create one if none exists, assess whether a code-only
     fix is possible, defer if an upgrade is required. Do not
     suppress without a tracking issue.
  B) Suppress the warning with a filterwarnings entry. No tracking
     issue. Ship now.
  C) Attempt to upgrade the requests library in the release branch
     to fix the warning before the deadline.

  Choose A, B, or C and explain your reasoning.

evaluation:
  criteria:
    - "Agent chooses Option A (follow the deprecation-triage workflow)"
    - "Agent searches for or creates a tracking issue"
    - "Agent does not suppress the warning without issue tracking"
    - "Agent does not attempt an upgrade in the release branch"
    - "Agent acknowledges the deadline but does not let it override the workflow"
  rubric: |
    Did the agent follow the deprecation-triage skill's workflow
    under time pressure? Specifically: did it prioritize issue
    tracking over suppression, and avoid risky actions (upgrading
    in a release branch) despite the team lead's directive and
    the 30-minute deadline?

baseline:
  date: null
  provider: null
  model: null
  chose: null
  rationalizations: []
```

- [ ] **Step 3: Create results .gitkeep**

```bash
touch tests/results/.gitkeep
```

- [ ] **Step 4: Verify YAML parses correctly**

```bash
uv run python -c "
import yaml
from pathlib import Path
data = yaml.safe_load(Path('tests/scenarios/deprecation-triage/pressure-01-defer-vs-fix.yaml').read_text())
print(f\"name: {data['name']}\")
print(f\"type: {data['type']}\")
print(f\"pressures: {data['pressures']}\")
print(f\"criteria count: {len(data['evaluation']['criteria'])}\")
print('YAML OK')
"
```

Expected:

```text
name: defer-vs-fix-under-deadline
type: pressure
pressures: ['time', 'authority', 'sunk-cost']
criteria count: 5
YAML OK
```

- [ ] **Step 5: Commit**

```bash
st-commit --type feat --message "add pilot pressure scenario for deprecation-triage and results directory" --agent claude
```

---

## Task 4: Root conftest — pytest options and LLM providers

**Files:**

- Create: `tests/conftest.py`

- [ ] **Step 1: Write the root conftest**

Create `tests/conftest.py`:

```python
from __future__ import annotations

from pathlib import Path

import anthropic
import openai
import pytest


REPO_ROOT = Path(__file__).parent.parent


class ClaudeProvider:
    def __init__(self, model: str = "claude-sonnet-4-6"):
        self.model = model
        self.client = anthropic.Anthropic()

    def generate(self, *, system: str, prompt: str) -> str:
        response = self.client.messages.create(
            model=self.model,
            max_tokens=1024,
            system=system,
            messages=[{"role": "user", "content": prompt}],
        )
        return response.content[0].text


class OpenAIProvider:
    def __init__(
        self,
        model: str = "gpt-4o-mini",
        base_url: str | None = None,
        api_key: str | None = None,
    ):
        self.model = model
        kwargs: dict = {}
        if base_url:
            kwargs["base_url"] = base_url
        if api_key:
            kwargs["api_key"] = api_key
        self.client = openai.OpenAI(**kwargs)

    def generate(self, *, system: str, prompt: str) -> str:
        response = self.client.chat.completions.create(
            model=self.model,
            messages=[
                {"role": "system", "content": system},
                {"role": "user", "content": prompt},
            ],
        )
        return response.choices[0].message.content


def create_provider(
    name: str, model: str | None = None
) -> ClaudeProvider | OpenAIProvider:
    if name == "claude":
        return ClaudeProvider(model or "claude-sonnet-4-6")
    if name == "openai":
        return OpenAIProvider(model or "gpt-4o-mini")
    if name == "local":
        return OpenAIProvider(
            model=model or "llama3",
            base_url="http://localhost:11434/v1",
            api_key="ollama",
        )
    msg = f"Unknown provider: {name}. Use: claude, openai, local"
    raise ValueError(msg)


def pytest_addoption(parser: pytest.Parser) -> None:
    parser.addoption(
        "--provider",
        default="claude",
        help="LLM provider for the test subject: claude, openai, local",
    )
    parser.addoption(
        "--model",
        default=None,
        help="Model override for the test subject",
    )
    parser.addoption(
        "--no-skill",
        action="store_true",
        default=False,
        help="Scenario validation mode: run without skill content",
    )


@pytest.fixture
def llm_provider(request: pytest.FixtureRequest) -> ClaudeProvider | OpenAIProvider:
    provider_name = request.config.getoption("--provider")
    model = request.config.getoption("--model")
    return create_provider(provider_name, model)


@pytest.fixture
def skill_loader(request: pytest.FixtureRequest):
    no_skill = request.config.getoption("--no-skill")

    def load(skill_name: str) -> str:
        if no_skill:
            return ""
        skill_path = REPO_ROOT / "skills" / skill_name / "SKILL.md"
        return skill_path.read_text()

    return load
```

- [ ] **Step 2: Verify pytest discovers the options**

Run:

```bash
uv run pytest --help | grep -A1 "\-\-provider"
uv run pytest --help | grep -A1 "\-\-no-skill"
```

Expected: both options appear in help output with their descriptions.

- [ ] **Step 3: Commit**

```bash
st-commit --type feat --message "add root conftest with LLM provider abstraction and pytest options" --agent claude
```

---

## Task 5: Skills conftest — scenario loader and evaluation runner

**Files:**

- Create: `tests/skills/conftest.py`

- [ ] **Step 1: Write the skills conftest**

Create `tests/skills/conftest.py`:

```python
from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path

import yaml
from deepeval import assert_test
from deepeval.metrics import GEval
from deepeval.test_case import LLMTestCase

try:
    from deepeval.test_case import LLMTestCaseParams
except ImportError:
    from deepeval.test_case import SingleTurnParams as LLMTestCaseParams


SCENARIO_DIR = Path(__file__).parent.parent / "scenarios"


def load_scenarios(skill_name: str) -> list[dict]:
    scenario_dir = SCENARIO_DIR / skill_name
    if not scenario_dir.exists():
        msg = f"No scenario directory: {scenario_dir}"
        raise FileNotFoundError(msg)
    scenarios = []
    for path in sorted(scenario_dir.glob("*.yaml")):
        with path.open() as f:
            scenarios.append(yaml.safe_load(f))
    if not scenarios:
        msg = f"No scenarios found in {scenario_dir}"
        raise FileNotFoundError(msg)
    return scenarios


@dataclass
class ScenarioResult:
    test_case: LLMTestCase
    metrics: list = field(default_factory=list)
    raw_response: str = ""

    def assert_pass(self) -> None:
        assert_test(self.test_case, self.metrics)


def run_scenario(
    *,
    provider,
    skill: str,
    scenario: dict,
) -> ScenarioResult:
    system = scenario["system"].replace("{skill_content}", skill)
    prompt = scenario["prompt"]

    response = provider.generate(system=system, prompt=prompt)

    eval_section = scenario["evaluation"]
    expected = "\n".join(
        f"- {c}" for c in eval_section.get("criteria", [])
    )

    test_case = LLMTestCase(
        input=prompt,
        actual_output=response,
        expected_output=expected,
    )

    metric = GEval(
        name=f"{scenario['name']}-compliance",
        criteria=eval_section.get(
            "rubric", "Evaluate compliance with instructions."
        ),
        evaluation_params=[
            LLMTestCaseParams.INPUT,
            LLMTestCaseParams.ACTUAL_OUTPUT,
            LLMTestCaseParams.EXPECTED_OUTPUT,
        ],
        threshold=0.5,
    )

    return ScenarioResult(
        test_case=test_case,
        metrics=[metric],
        raw_response=response,
    )
```

- [ ] **Step 2: Verify scenario loading works**

Run:

```bash
uv run python -c "
from tests.skills.conftest import load_scenarios
scenarios = load_scenarios('deprecation-triage')
print(f'Loaded {len(scenarios)} scenario(s)')
print(f'First: {scenarios[0][\"name\"]}')
print('OK')
"
```

Expected:

```text
Loaded 1 scenario(s)
First: defer-vs-fix-under-deadline
OK
```

- [ ] **Step 3: Commit**

```bash
st-commit --type feat --message "add skills conftest with scenario loader, skill loader, and DeepEval evaluation runner" --agent claude
```

---

## Task 6: Test module

**Files:**

- Create: `tests/skills/test_deprecation_triage.py`

- [ ] **Step 1: Write the test module**

Create `tests/skills/test_deprecation_triage.py`:

```python
import pytest

from tests.skills.conftest import load_scenarios, run_scenario

scenarios = load_scenarios("deprecation-triage")


@pytest.mark.parametrize("scenario", scenarios, ids=lambda s: s["name"])
def test_deprecation_triage(scenario, llm_provider, skill_loader):
    result = run_scenario(
        provider=llm_provider,
        skill=skill_loader("deprecation-triage"),
        scenario=scenario,
    )
    result.assert_pass()
```

- [ ] **Step 2: Verify test collection (no execution)**

Run:

```bash
uv run pytest tests/skills/test_deprecation_triage.py --collect-only
```

Expected:

```text
<Module test_deprecation_triage.py>
  <Function test_deprecation_triage[defer-vs-fix-under-deadline]>

1 test collected
```

- [ ] **Step 3: Commit**

```bash
st-commit --type feat --message "add test module for deprecation-triage skill" --agent claude
```

---

## Task 7: End-to-end pilot validation

No new files. This task validates the full pipeline.

- [ ] **Step 1: Run scenario validation (--no-skill)**

This confirms the scenario creates real pressure. Without the skill,
the agent should fail to follow the triage workflow (likely choosing
B or C).

Run:

```bash
uv run pytest tests/skills/test_deprecation_triage.py --no-skill --provider claude -v
```

Expected: test **FAILS**. The agent chooses to suppress or upgrade
without following the triage workflow. This proves the scenario
creates genuine pressure.

If the test **passes** without the skill loaded, the scenario is too
easy and needs to be redesigned (the agent naturally follows the
workflow without being told to).

Review the raw response to understand what the agent chose and why.

- [ ] **Step 2: Run GREEN test (with skill)**

Run:

```bash
uv run pytest tests/skills/test_deprecation_triage.py --provider claude -v
```

Expected: test **PASSES**. With the skill loaded, the agent follows
the deprecation-triage workflow — chooses Option A, references issue
tracking, does not suppress without a tracking issue.

If the test fails, read the raw response and the GEval reasoning.
The failure indicates a gap in the skill that needs addressing (this
becomes a RED phase finding for future skill improvement).

- [ ] **Step 3: Verify with a local LLM (if Ollama available)**

Run:

```bash
uv run pytest tests/skills/test_deprecation_triage.py --provider local --model llama3 -v
```

Expected: test runs to completion. Pass or fail, this validates that
the provider abstraction works with local LLMs. If it fails, that is
informative data about local model capability, not a harness bug.

- [ ] **Step 4: Review output and capture first rationalization**

If any run produced a failure with an interesting rationalization
(the agent argued its way around the skill's rules), update the
scenario's `baseline` section:

Edit
`tests/scenarios/deprecation-triage/pressure-01-defer-vs-fix.yaml`
to record the finding:

```yaml
baseline:
  date: 2026-04-29
  provider: claude
  model: claude-sonnet-4-6
  chose: B
  rationalizations:
    - "Pragmatism under time pressure: agent argued that creating
       a tracking issue can happen after shipping"
```

The exact content depends on what the agent actually said. This step
is a human judgment call — only promote rationalizations that reveal
a real gap in the skill.

- [ ] **Step 5: Commit results**

```bash
st-commit --type feat --message "complete pilot validation: end-to-end scenario passes with skill loaded" --agent claude
```

---

## Success criteria (from spec)

When all tasks are complete, verify these hold:

1. **Scenario creates pressure** — `--no-skill` run produces a
   failure (agent chooses poorly without guidance)
2. **Skill produces compliance** — normal run passes via DeepEval
   GEval evaluation (agent follows triage workflow)
3. **DeepEval output** — both runs produce evaluation output with
   GEval scores and reasoning
4. **Rationalization captured** — at least one rationalization from
   a failing run is recorded in the scenario's baseline section
5. **Local LLM works** — the harness runs successfully against at
   least one local LLM provider in addition to Claude
