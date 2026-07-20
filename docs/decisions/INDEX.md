# Decision log — index

One line per decision. Open a page ONLY when tuning that knob or
questioning that choice — never load all pages by default.

- [D1](D1-caps-and-breaker.md) — breaker=3, turn cap=80, iter cap=25; read BEFORE changing any cap
- [D2](D2-criteria-edit-kill.md) — agent edits frozen criteria → kill whole loop; read before softening
- [D3](D3-json-machine-md-human.md) — prd.json for machine, PRD.md for human; read before format changes
- [D4](D4-speed-first.md) — optimize speed-to-done over token shaving; read before adding token tricks
- [D5](D5-resume-baton.md) — mid-story continuity via git + notes baton; read before touching resume/commit rules
- [D6](D6-skills-harvest.md) — skills: harvest phase, staged approval, project-only, high bar; read before touching learning pipeline
- [D7](D7-verify-protection.md) — verify.sh snapshot + checksum tripwire, gated self-improvement; read before touching verify machinery
- [D8](D8-team-adoption.md) — team adoption = design constraint; never hard-assume tracked .loop/; read before adding git assumptions
- [D9](D9-per-feature-folders.md) — .loop/features/<slug>/ per feature; shared verify/learnings at root; sequential multi-feature, lockfile, auto-migration; read before touching layout/paths
- [D10](D10-git-invisible-default.md) — .loop/ gitignored by default, LOOP_GIT_MODE=tracked opts in; read before touching init gitignore or sweep-commit
- [D11](D11-cross-repo-workspace.md) — cross-repo = assembled workspace (one repo, inner .git stripped); conditional DESIGN.md gate (spec precision ∝ blast radius); intelligence in prompts not bash, future extraction to skill-builder repo; read before any multi-repo work
- [D12](D12-repo-knowledge-cooperation.md) — cooperate with repo knowledge via CLAUDE.md (auto-loaded, seeded at init, never clobbered); tests conform to code — no refactor-for-test, no platform branching in ship code, untested-honest OK; CI is the reproducibility oracle for verify.sh; read before touching init auto-fill or build-agent test rules
