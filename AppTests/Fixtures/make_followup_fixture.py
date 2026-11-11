"""Create an isolated fictional mentor follow-up evaluation fixture."""

import argparse
import json
import os
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("case", choices=("legacy", "live"))
    parser.add_argument("output", type=Path, help="New temporary fixture path")
    args = parser.parse_args()

    fixture_dir = Path(__file__).resolve().parent
    student = json.loads((fixture_dir / "student.json").read_text())
    manifest = json.loads((fixture_dir / "mentor-followup-evaluations.json").read_text())
    if student.get("mentorAnswers"):
        raise ValueError("The synthetic base fixture must not contain mentor answers")
    if args.case == "legacy":
        history = manifest["legacyOffer"]["history"]
        if len(history) != 1:
            raise ValueError("The legacy fixture requires exactly one historical turn")
        student["mentorAnswers"] = [{
            "id": "B9E60000-0000-4000-8000-000000000001",
            "createdAt": 815400000.0,
            "question": history[0]["student"],
            "engine": "contextualOffline",
            "sources": [],
            "instructionsSnapshot": "Fictional synthetic legacy fixture for testing. This is not an actual model output.",
            "promptSnapshot": "Fictional synthetic legacy fixture; no source snapshots.",
            "answer": history[0]["mentor"],
        }]
    descriptor = os.open(args.output, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(descriptor, "w", encoding="utf-8") as output:
        json.dump(student, output, ensure_ascii=False, indent=2)
        output.write("\n")


if __name__ == "__main__":
    main()
