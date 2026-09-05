#!/usr/bin/env python3
"""Create and validate durable implement-spec run state."""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path


ALLOWED_TRANSITIONS = {
    "created": {"readiness", "rejected", "blocked"},
    "readiness": {"exploring", "rejected", "blocked"},
    "exploring": {"planned", "blocked"},
    "planned": {"awaiting_approval", "implementing", "blocked"},
    "awaiting_approval": {"implementing", "rejected", "blocked"},
    "implementing": {"validating", "blocked", "cap_hit"},
    "validating": {"reviewing", "implementing", "blocked", "cap_hit"},
    "reviewing": {"fixing", "complete", "blocked", "cap_hit"},
    "fixing": {"validating", "blocked", "cap_hit"},
    "blocked": {
        "readiness",
        "exploring",
        "planned",
        "implementing",
        "validating",
        "reviewing",
    },
    "rejected": set(),
    "cap_hit": set(),
    "complete": set(),
}


def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def slugify(value: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-")
    return slug[:48] or "spec"


def atomic_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(
        "w", dir=path.parent, delete=False, encoding="utf-8"
    ) as handle:
        json.dump(value, handle, indent=2, sort_keys=True)
        handle.write("\n")
        temporary = Path(handle.name)
    os.replace(temporary, path)


def load_json(path: Path) -> dict:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise ValueError(f"cannot read valid JSON from {path}: {error}") from error
    if not isinstance(value, dict):
        raise ValueError(f"expected a JSON object in {path}")
    return value


def resolve_run_dir(value: str) -> Path:
    run_dir = Path(value).expanduser().resolve()
    if not (run_dir / "run.json").is_file():
        raise ValueError(f"not an implement-spec run directory: {run_dir}")
    return run_dir


def init_run(args: argparse.Namespace) -> int:
    repo = Path(args.repo).expanduser().resolve()
    spec = Path(args.spec).expanduser()
    if not spec.is_absolute():
        spec = repo / spec
    spec = spec.resolve()
    if not repo.is_dir():
        raise ValueError(f"repository directory does not exist: {repo}")
    if not spec.is_file():
        raise ValueError(f"specification file does not exist: {spec}")

    root = Path(args.root)
    if not root.is_absolute():
        root = repo / root
    root = root.resolve()
    run_id = (
        args.run_id
        or f"{datetime.now().strftime('%Y%m%d-%H%M%S')}-{slugify(spec.stem)}"
    )
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]{0,95}", run_id):
        raise ValueError("run id must be 1-96 safe filename characters")

    run_dir = root / run_id
    if args.run_id is None:
        base = run_id
        suffix = 2
        while run_dir.exists():
            run_id = f"{base}-{suffix}"
            run_dir = root / run_id
            suffix += 1
    try:
        run_dir.mkdir(parents=True, exist_ok=False)
    except FileExistsError as error:
        raise ValueError(f"run already exists: {run_dir}") from error
    (run_dir / "exploration").mkdir()
    (run_dir / "reviews").mkdir()
    shutil.copyfile(spec, run_dir / "spec.snapshot.md")
    (run_dir / "decisions.md").write_text("# Decisions\n\n", encoding="utf-8")

    now = utc_now()
    state = {
        "schema_version": 1,
        "run_id": run_id,
        "repository": str(repo),
        "specification": str(spec),
        "spec_snapshot": "spec.snapshot.md",
        "state": "created",
        "created_at": now,
        "updated_at": now,
        "risk": None,
        "approval": {"required": False, "approved": False, "approved_at": None},
        "writer": None,
        "review_round": 0,
        "events": [
            {"at": now, "from": None, "to": "created", "note": "run initialized"}
        ],
    }
    atomic_json(run_dir / "run.json", state)
    print(run_dir)
    return 0


def transition(args: argparse.Namespace) -> int:
    run_dir = resolve_run_dir(args.run_dir)
    path = run_dir / "run.json"
    state = load_json(path)
    current = state.get("state")
    target = args.state
    if current not in ALLOWED_TRANSITIONS:
        raise ValueError(f"run has unknown current state: {current!r}")
    if target not in ALLOWED_TRANSITIONS[current]:
        raise ValueError(f"invalid transition: {current} -> {target}")
    if (
        target == "implementing"
        and state.get("risk") == "high"
        and not state.get("approval", {}).get("approved")
    ):
        raise ValueError(
            "high-risk run cannot enter implementation without explicit approval"
        )
    if target == "complete":
        errors = completion_errors(run_dir, state)
        if errors:
            raise ValueError("completion gates failed: " + "; ".join(errors))
    now = utc_now()
    state["state"] = target
    state["updated_at"] = now
    state.setdefault("events", []).append(
        {"at": now, "from": current, "to": target, "note": args.note or ""}
    )
    atomic_json(path, state)
    print(f"{current} -> {target}")
    return 0


def set_fields(args: argparse.Namespace) -> int:
    run_dir = resolve_run_dir(args.run_dir)
    path = run_dir / "run.json"
    state = load_json(path)
    if args.risk is not None:
        levels = {None: 0, "low": 1, "medium": 2, "high": 3}
        if levels.get(args.risk, 0) < levels.get(state.get("risk"), 0):
            raise ValueError("risk cannot be downgraded within an active run")
        state["risk"] = args.risk
        state["approval"]["required"] = args.risk == "high"
    if args.writer is not None:
        if state.get("writer") and state["writer"] != args.writer:
            raise ValueError(f"writer already assigned to {state['writer']!r}")
        state["writer"] = args.writer
    if args.approve:
        if state.get("state") != "awaiting_approval" or state.get("risk") != "high":
            raise ValueError(
                "approval is only valid at a high-risk awaiting_approval gate"
            )
        state["approval"]["approved"] = True
        state["approval"]["approved_at"] = utc_now()
    if args.review_round is not None:
        if args.review_round < int(state.get("review_round", 0)):
            raise ValueError("review round cannot decrease")
        state["review_round"] = args.review_round
    state["updated_at"] = utc_now()
    atomic_json(path, state)
    print(path)
    return 0


def validate_ready(value: dict, errors: list[str]) -> None:
    if value.get("status") != "ready":
        errors.append("readiness.json status is not ready")
    if not value.get("goal"):
        errors.append("readiness.json has no goal")
    if not value.get("acceptance_criteria"):
        errors.append("readiness.json has no acceptance criteria")
    if not value.get("validation_strategy"):
        errors.append("readiness.json has no validation strategy")
    if value.get("intent_ambiguities"):
        errors.append("readiness.json retains intent ambiguities")
    if value.get("blocking_questions"):
        errors.append("readiness.json retains blocking questions")


def validate_goal(value: dict, errors: list[str]) -> None:
    criteria = value.get("acceptance_criteria")
    if value.get("goal_satisfied") is not True:
        errors.append("validation.json does not mark the goal satisfied")
    if not isinstance(criteria, list) or not criteria:
        errors.append("validation.json has no acceptance criteria")
    elif any(
        not isinstance(item, dict) or item.get("status") != "passed"
        for item in criteria
    ):
        errors.append("not every acceptance criterion passed")
    checks = value.get("deterministic_checks")
    if not isinstance(checks, list) or not checks:
        errors.append("validation.json has no deterministic checks")
    elif any(
        not isinstance(item, dict) or item.get("status") != "passed" for item in checks
    ):
        errors.append("not every deterministic check passed")
    if value.get("regressions"):
        errors.append("validation.json reports regressions")


def validate_reviews(run_dir: Path, errors: list[str]) -> None:
    reviews = sorted((run_dir / "reviews").glob("*.json"))
    if not reviews:
        errors.append("no independent review JSON exists")
        return
    for path in reviews:
        review = load_json(path)
        if review.get("approved") is not True or review.get("blocking"):
            errors.append(f"review is not approved: {path.name}")


def criterion_ids(items: object) -> list[str]:
    if not isinstance(items, list):
        return []
    return [
        str(item.get("id"))
        for item in items
        if isinstance(item, dict) and item.get("id")
    ]


def completion_errors(run_dir: Path, state: dict) -> list[str]:
    errors: list[str] = []
    for name in (
        "readiness.json",
        "implementation-plan.md",
        "validation.json",
        "final-summary.md",
    ):
        path = run_dir / name
        if not path.is_file() or path.stat().st_size == 0:
            errors.append(f"missing or empty {name}")

    readiness: dict | None = None
    validation: dict | None = None
    if (run_dir / "readiness.json").is_file():
        readiness = load_json(run_dir / "readiness.json")
        validate_ready(readiness, errors)
    if (run_dir / "validation.json").is_file():
        validation = load_json(run_dir / "validation.json")
        validate_goal(validation, errors)
    validate_reviews(run_dir, errors)

    if readiness is not None and validation is not None:
        expected = criterion_ids(readiness.get("acceptance_criteria"))
        actual = criterion_ids(validation.get("acceptance_criteria"))
        if len(expected) != len(set(expected)):
            errors.append("readiness.json contains duplicate criterion ids")
        if sorted(expected) != sorted(actual):
            errors.append("validation criteria do not exactly match readiness criteria")

    if state.get("risk") is None:
        errors.append("run has no post-exploration risk classification")
    if state.get("risk") == "high" and not state.get("approval", {}).get("approved"):
        errors.append("high-risk run lacks explicit approval")
    if not state.get("writer"):
        errors.append("run has no designated writer")
    return errors


def validate_run(args: argparse.Namespace) -> int:
    run_dir = resolve_run_dir(args.run_dir)
    state = load_json(run_dir / "run.json")
    errors = completion_errors(run_dir, state)

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1
    print("run artifacts satisfy completion gates")
    return 0


def show_status(args: argparse.Namespace) -> int:
    run_dir = resolve_run_dir(args.run_dir)
    print(json.dumps(load_json(run_dir / "run.json"), indent=2, sort_keys=True))
    return 0


def parser() -> argparse.ArgumentParser:
    root = argparse.ArgumentParser(description=__doc__)
    commands = root.add_subparsers(dest="command", required=True)

    init = commands.add_parser("init", help="initialize a run directory")
    init.add_argument("--spec", required=True)
    init.add_argument("--repo", default=".")
    init.add_argument("--root", default=".agent-runs")
    init.add_argument("--run-id")
    init.set_defaults(handler=init_run)

    move = commands.add_parser("transition", help="transition workflow state")
    move.add_argument("run_dir")
    move.add_argument("state", choices=sorted(ALLOWED_TRANSITIONS))
    move.add_argument("--note")
    move.set_defaults(handler=transition)

    update = commands.add_parser("set", help="set guarded run metadata")
    update.add_argument("run_dir")
    update.add_argument("--risk", choices=["low", "medium", "high"])
    update.add_argument("--writer")
    update.add_argument("--approve", action="store_true")
    update.add_argument("--review-round", type=int)
    update.set_defaults(handler=set_fields)

    validate = commands.add_parser("validate", help="validate completion artifacts")
    validate.add_argument("run_dir")
    validate.set_defaults(handler=validate_run)

    status = commands.add_parser("status", help="print run state")
    status.add_argument("run_dir")
    status.set_defaults(handler=show_status)
    return root


def main() -> int:
    try:
        args = parser().parse_args()
        return args.handler(args)
    except ValueError as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
