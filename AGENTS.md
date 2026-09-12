# Project conventions

- Use English for all repository documents, code, comments, commit messages, game text, and textual asset content.
- Conversation with the user may be in Chinese; do not infer repository language from conversation language.
- Read `docs/SPEC.md` for the agreed direction, baseline scope, and explicitly open design decisions.
- Keep specifications, research, planning documents, and credits under `docs/`. Keep the project entry point `README.md` and coding-assistant conventions `AGENTS.md` at the repository root.
- The specification describes planned features, not existing implementation. Report implementation and verification status accurately.

## Backend work

- Read `docs/BACKEND.md` for feature layout, execution, API contracts, and review requirements.
- Keep each AI feature in its own folder under `backend/`; share the local `.venv` and ignored `.env`.
- Keep setup and developer documentation under `docs/`. Keep assistant conventions in this root file.
- Never print, stage, commit, or export API keys, local `.env` files, signed asset URLs, or generated job/profile data.
- Keep `.env.example` credential values blank. Preserve existing local keys when changing configuration.
- Run `backend/.venv/bin/python -m unittest discover -s backend/tests -v` after backend changes.
- Use offline tests and `--dry-run` by default. Make paid live calls only within the user's authorized testing scope.
- Before committing or pushing backend work, verify ignored files and scan the staged content for credentials without displaying their values.
