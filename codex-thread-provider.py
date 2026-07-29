#!/usr/bin/env python3
import argparse
import os
import shutil
import sqlite3
import sys
import tempfile
from datetime import datetime
from pathlib import Path


def default_db_path() -> Path:
    sqlite_home = os.environ.get("CODEX_SQLITE_HOME")
    codex_home = os.environ.get("CODEX_HOME")

    if sqlite_home:
        return Path(sqlite_home).expanduser() / "state_5.sqlite"

    if codex_home:
        return Path(codex_home).expanduser() / "state_5.sqlite"

    return Path.home() / ".codex" / "state_5.sqlite"


def default_codex_home() -> Path:
    codex_home = os.environ.get("CODEX_HOME")

    if codex_home:
        return Path(codex_home).expanduser()

    return Path.home() / ".codex"


def ensure_threads_schema(con: sqlite3.Connection) -> None:
    table = con.execute(
        "select name from sqlite_master where type = 'table' and name = 'threads'"
    ).fetchone()

    if table is None:
        raise RuntimeError("missing threads table")

    columns = {row[1] for row in con.execute("pragma table_info(threads)")}

    if "model_provider" not in columns:
        raise RuntimeError("threads.model_provider column is missing")


def print_counts(con: sqlite3.Connection) -> None:
    rows = con.execute(
        """
        select model_provider, count(*)
        from threads
        group by model_provider
        order by model_provider
        """
    ).fetchall()

    if not rows:
        print("no threads")
        return

    for provider, count in rows:
        print(f"{provider}: {count}")


def matching_threads(
    con: sqlite3.Connection,
    provider: str,
) -> list[tuple[str, str, str]]:
    return con.execute(
        """
        select id, cwd, rollout_path
        from threads
        where model_provider = ?
        order by updated_at desc
        """,
        (provider,),
    ).fetchall()


def print_matches(
    provider: str,
    threads: list[tuple[str, str, str]],
    rollouts: list[tuple[Path, int]],
) -> None:
    print(f"provider {provider!r} matches:")

    if threads:
        print("DB threads:")

        for thread_id, cwd, rollout_path in threads:
            print(f"  thread:  {thread_id}")
            print(f"  cwd:     {cwd}")
            print(f"  rollout: {rollout_path}")
    else:
        print("DB threads: none")

    if rollouts:
        print("Rollout metadata:")

        for path, count in rollouts:
            print(f"  {path} ({count} occurrence(s))")
    else:
        print("Rollout metadata: none")


def backup_db(db_path: Path) -> Path:
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    backup_path = db_path.with_name(f"{db_path.name}.bak-{stamp}")

    src = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
    dst = sqlite3.connect(backup_path)

    try:
        src.backup(dst)
    finally:
        src.close()
        dst.close()

    return backup_path


def update_provider(con: sqlite3.Connection, old: str, new: str, apply: bool) -> int:
    count = con.execute(
        "select count(*) from threads where model_provider = ?",
        (old,),
    ).fetchone()[0]

    if not apply:
        return count

    con.execute(
        "update threads set model_provider = ? where model_provider = ?",
        (new, old),
    )
    con.commit()

    return count


def rollout_paths(codex_home: Path) -> list[Path]:
    sessions_dir = codex_home / "sessions"

    if not sessions_dir.exists():
        return []

    return sorted(sessions_dir.rglob("rollout-*.jsonl"))


def provider_tokens(provider: str) -> tuple[bytes, bytes]:
    return (
        f'"model_provider":"{provider}"'.encode(),
        f'"model_provider_id":"{provider}"'.encode(),
    )


def count_rollout_provider(path: Path, provider: str) -> int:
    tokens = provider_tokens(provider)
    count = 0

    with path.open("rb") as file:
        for line in file:
            count += sum(line.count(token) for token in tokens)

    return count


def rewrite_rollout_provider(path: Path, old: str, new: str) -> int:
    old_tokens = provider_tokens(old)
    new_tokens = provider_tokens(new)
    temp_path = None
    count = 0

    try:
        with path.open("rb") as source:
            with tempfile.NamedTemporaryFile(
                mode="wb",
                dir=path.parent,
                prefix=f".{path.name}.",
                delete=False,
            ) as destination:
                temp_path = Path(destination.name)

                for line in source:
                    for old_token, new_token in zip(old_tokens, new_tokens):
                        occurrences = line.count(old_token)

                        if occurrences:
                            line = line.replace(old_token, new_token)
                            count += occurrences

                    destination.write(line)

        shutil.copystat(path, temp_path)
        os.replace(temp_path, path)
    finally:
        if temp_path is not None and temp_path.exists():
            temp_path.unlink()

    return count


def matching_rollouts(codex_home: Path, provider: str) -> list[tuple[Path, int]]:
    matches = []

    for path in rollout_paths(codex_home):
        count = count_rollout_provider(path, provider)

        if count:
            matches.append((path, count))

    return matches


def update_rollouts(
    rollouts: list[tuple[Path, int]],
    old: str,
    new: str,
) -> int:
    total = 0

    for path, expected_count in rollouts:
        actual_count = rewrite_rollout_provider(path, old, new)

        if actual_count != expected_count:
            raise RuntimeError(
                f"{path}: expected {expected_count} provider occurrence(s), "
                f"updated {actual_count}"
            )

        total += actual_count

    return total


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Change Codex saved thread provider IDs.",
    )
    parser.add_argument(
        "--db",
        type=Path,
        default=default_db_path(),
        help="Path to state_5.sqlite. Defaults to CODEX_SQLITE_HOME/CODEX_HOME.",
    )
    parser.add_argument(
        "--codex-home",
        type=Path,
        default=default_codex_home(),
        help="Path to CODEX_HOME. Defaults to CODEX_HOME or ~/.codex.",
    )
    parser.add_argument("--from", dest="old", help="Existing provider ID.")
    parser.add_argument("--to", dest="new", help="New provider ID.")
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Write changes. Without this flag the script only previews.",
    )

    return parser.parse_args()


def main() -> int:
    args = parse_args()
    db_path = args.db.expanduser()
    codex_home = args.codex_home.expanduser()

    if not db_path.exists():
        print(f"database not found: {db_path}", file=sys.stderr)
        return 1

    con = sqlite3.connect(db_path)

    try:
        ensure_threads_schema(con)

        if not args.old and not args.new:
            print_counts(con)
            return 0

        if not args.old or not args.new:
            print("--from and --to must be provided together", file=sys.stderr)
            return 1

        threads = matching_threads(con, args.old)
        rollouts = matching_rollouts(codex_home, args.old)
        db_count = len(threads)
        rollout_count = len(rollouts)
        rollout_occurrences = sum(count for _, count in rollouts)

        if db_count == 0 and rollout_count == 0:
            print(f"no threads or rollout metadata with provider {args.old!r}")
            return 0

        print_matches(args.old, threads, rollouts)

        if not args.apply:
            print(
                f"dry-run: would update {db_count} DB row(s) and "
                f"{rollout_occurrences} metadata occurrence(s) in "
                f"{rollout_count} rollout file(s): {args.old} -> {args.new}"
            )
            return 0

        backup_path = backup_db(db_path)
        update_provider(con, args.old, args.new, apply=True)
        updated_occurrences = update_rollouts(rollouts, args.old, args.new)

        print(
            f"updated {db_count} DB row(s) and {updated_occurrences} metadata "
            f"occurrence(s) in {rollout_count} rollout file(s): "
            f"{args.old} -> {args.new}"
        )
        print(f"backup: {backup_path}")
        return 0
    except Exception as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    finally:
        con.close()


if __name__ == "__main__":
    raise SystemExit(main())
