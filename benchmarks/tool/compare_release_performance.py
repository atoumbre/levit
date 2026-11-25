"""Run already-built native apps sequentially; retain every raw sample.

Usage: python3 benchmarks/tool/compare_release_performance.py REFERENCE_ROOT OUTPUT [BEFORE_ROOT]
Build both roots in profile and release with lib/release_performance.dart first.
The working repository is the candidate. No builds/tests should run concurrently.
"""

import hashlib
import json
import os
from pathlib import Path
import statistics
import subprocess
import sys


def main():
    candidate = Path(__file__).resolve().parents[2]
    reference = Path(sys.argv[1]).resolve()
    output = Path(sys.argv[2]).resolve()
    output.mkdir(parents=True, exist_ok=True)
    roots = {"reference": reference, "candidate": candidate}
    if len(sys.argv) > 3:
        roots["before"] = Path(sys.argv[3]).resolve()
    for root in roots.values():
        for mode in ["Profile", "Release"]:
            app = root / f"benchmarks/build/macos/Build/Products/{mode}/benchmarks.app/Contents/MacOS/benchmarks"
            if not app.is_file():
                raise RuntimeError(f"Build the {mode} executable before measurement: {app}")
    runs = []
    # Reverse reference/candidate order in the second pass to expose drift.
    for repeat in range(2):
        labels = ["reference", "before", "candidate"] if "before" in roots else ["reference", "candidate"]
        if repeat: labels.reverse()
        for mode in ["profile", "release"]:
            for diagnostics in (["off", "on"] if repeat == 0 else ["on", "off"]):
                for label in labels:
                    root = roots[label]
                    app = root / f"benchmarks/build/macos/Build/Products/{mode.title()}/benchmarks.app/Contents/MacOS/benchmarks"
                    stem = f"performance-{label}-{mode}-{diagnostics}-{repeat + 1}"
                    print(f"Measuring {stem}", flush=True)
                    result = subprocess.run([str(app)], capture_output=True, text=True, timeout=300,
                                            env=dict(os.environ, LEVIT_PERFORMANCE_RUN="1", LEVIT_DIAGNOSTICS=diagnostics))
                    (output / f"{stem}.log").write_text(result.stdout + result.stderr)
                    if result.returncode:
                        raise RuntimeError(f"{stem} exited {result.returncode}; inspect its log")
                    assert "LEVIT_PERFORMANCE_ACTIVITY_ACTIVE" in result.stderr
                    payloads = [line.split("LEVIT_PERFORMANCE_JSON:", 1)[1]
                                for line in result.stdout.splitlines() if "LEVIT_PERFORMANCE_JSON:" in line]
                    if len(payloads) != 1:
                        raise RuntimeError(f"{stem}: expected exactly one completed measurement")
                    data = json.loads(payloads[0])
                    assert data["mode"] == mode
                    assert data["reference"] == ("539f130" if label == "reference" else label)
                    assert data["activityGuard"] is True
                    assert data["diagnosticsMode"] == diagnostics
                    assert data["middlewareDetached"] is True
                    assert len(data["measurements"]) == 15
                    for row in data["measurements"]:
                        assert row["diagnostics"] == (diagnostics == "on")
                        assert len(row["samplesUs"]) == (60 if "frame" in row["workload"] else 30)
                        assert all(sample > 0 for sample in row["samplesUs"])
                        if "frame" in row["workload"]:
                            assert len(row["frameTimings"]) == 60
                        else:
                            assert row["warmups"] >= 5
                            assert row["minimumWarmupUs"] == 500000
                            assert row["warmupElapsedUs"] >= row["minimumWarmupUs"]
                            assert len(row["bodySamplesUs"]) == 30
                            assert all(0 < body <= total for body, total in zip(row["bodySamplesUs"], row["samplesUs"]))
                    data["repeat"] = repeat + 1
                    data["label"] = label
                    data["executableSha256"] = hashlib.sha256(app.read_bytes()).hexdigest()
                    aot = app.parents[1] / "Frameworks/App.framework/Versions/A/App"
                    data["aotSha256"] = hashlib.sha256(aot.read_bytes()).hexdigest()
                    (output / f"{stem}.json").write_text(json.dumps(data, indent=2) + "\n")
                    runs.append(data)
                    print(f"Passed {stem}", flush=True)

    layouts = {(tuple(run["physicalSize"]), run["pixelRatio"], run["displayId"], run["refreshRate"]) for run in runs}
    if len(layouts) != 1:
        raise RuntimeError(f"Inconsistent display geometry: {layouts}")
    summary = []
    for mode in ["profile", "release"]:
        for enabled in [False, True]:
            for workload in dict.fromkeys(row["workload"] for row in runs[0]["measurements"]):
                medians = {}
                for label in roots:
                    rows = [row for run in runs if run["mode"] == mode and run["label"] == label
                            for row in run["measurements"]
                            if row["workload"] == workload and row["diagnostics"] == enabled]
                    medians[label] = [statistics.median(row["samplesUs"]) for row in rows]
                before = statistics.median(medians["reference"])
                after = statistics.median(medians["candidate"])
                entry = {"mode": mode, "diagnostics": enabled, "workload": workload,
                                "roundMediansUs": medians, "referenceUs": before,
                                "candidateUs": after, "changePercent": (after / before - 1) * 100}
                if "frame" not in workload:
                    body_medians, wait_medians = {}, {}
                    for label in roots:
                        rows = [row for run in runs if run["mode"] == mode and run["label"] == label
                                for row in run["measurements"]
                                if row["workload"] == workload and row["diagnostics"] == enabled]
                        body_medians[label] = [statistics.median(row["bodySamplesUs"]) for row in rows]
                        wait_medians[label] = [statistics.median(total - body for total, body in
                                              zip(row["samplesUs"], row["bodySamplesUs"])) for row in rows]
                    body_before = statistics.median(body_medians["reference"])
                    body_after = statistics.median(body_medians["candidate"])
                    entry.update({"roundBodyMediansUs": body_medians, "roundEventLoopWaitMediansUs": wait_medians,
                                  "bodyReferenceUs": body_before, "bodyCandidateUs": body_after,
                                  "bodyChangePercent": (body_after / body_before - 1) * 100})
                summary.append(entry)
    (output / "performance-summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    if "before" in roots:
        for row in summary:
            before = statistics.median(row["roundMediansUs"]["before"])
            row["beforeOptimizationUs"] = before
            row["optimizationChangePercent"] = (row["candidateUs"] / before - 1) * 100
        (output / "performance-summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(f"All {len(runs)} isolated native measurement runs passed.", flush=True)


if __name__ == "__main__":
    main()
