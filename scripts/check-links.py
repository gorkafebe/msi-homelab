"""Check relative links and #anchors in the repository's Markdown files.

usage: python3 -I scripts/check-links.py [repo-root]   (make lint)
"""
import re
import subprocess
import sys
from pathlib import Path

root = Path(sys.argv[1] if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent).resolve()
files = subprocess.run(["git", "-C", str(root), "ls-files", "-co", "--exclude-standard", "*.md"],
                       capture_output=True, text=True, check=True).stdout.split()


def anchors(path):
    out = set()
    in_code = False
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("```"):
            in_code = not in_code
            continue
        if in_code:
            continue
        m = re.match(r"^#{1,6}\s+(.*)$", line)
        if m:
            text = m.group(1).strip().lower()
            text = re.sub(r"[`*_]", "", text)
            text = re.sub(r"[^\w\- ]", "", text)
            out.add(text.replace(" ", "-"))
    return out


bad = 0
for f in files:
    p = root / f
    text = p.read_text(encoding="utf-8")
    text = re.sub(r"```.*?```", "", text, flags=re.S)
    for link in re.findall(r"\]\(([^)\s]+)\)", text):
        if re.match(r"^[a-z]+://", link) or link.startswith("mailto:"):
            continue
        target, _, frag = link.partition("#")
        tp = (p.parent / target).resolve() if target else p
        if not tp.exists():
            print(f"MISSING  {f}: {link}")
            bad += 1
            continue
        if frag and tp.suffix == ".md" and frag not in anchors(tp):
            print(f"ANCHOR   {f}: {link}")
            bad += 1
print(f"{len(files)} files checked, {bad} problem(s)")
sys.exit(1 if bad else 0)
