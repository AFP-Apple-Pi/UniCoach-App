"""Materialise one predeclared fictional Mentor evaluation fixture."""
import argparse
import json
from pathlib import Path


def main() -> None:
    fixture_dir = Path(__file__).resolve().parent
    manifest = json.loads((fixture_dir / "mentor-evaluations.json").read_text())
    cases = {case["name"]: case for case in manifest["cases"]}
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("case", choices=cases)
    parser.add_argument("output", type=Path, help="A temporary fixture path on the Mac")
    args = parser.parse_args()

    case = cases[args.case]
    source_case = cases[case.get("sourceCase", args.case)]
    fixture = json.loads((fixture_dir / manifest["baseFixture"]).read_text())
    assignment = next(
        item for item in fixture["assignments"]
        if item["id"].upper() == manifest["assignmentID"].upper()
    )
    assignment.update(source_case["assignmentOverrides"])
    args.output.write_text(json.dumps(fixture, ensure_ascii=False, indent=2) + "\n")


if __name__ == "__main__":
    main()
