# Project conventions

- Use English for all repository documents, code, comments, commit messages, game text, and textual asset content.
- Conversation with the user may be in Chinese; do not infer repository language from conversation language.
- Read `docs/SPEC.md` for the agreed direction, baseline scope, and explicitly open design decisions.
- Keep specifications, research, planning documents, and credits under `docs/`. Keep the project entry point `README.md` and coding-assistant conventions `AGENTS.md` at the repository root.
- The specification describes planned features, not existing implementation. Report implementation and verification status accurately.

## Backend work

- Keep backend setup, interfaces, and development guidance in `docs/backend/BACKEND.md`; record generated examples separately in `docs/backend/GENERATED_EXAMPLES.md`. Read the guide before backend work.
- Keep each AI feature in its own folder under `backend/`; share the local `.venv` and ignored `.env`.
- Keep shared backend utilities, including local rendering, under `backend/utils/`.
- Keep backend documentation under `docs/backend/` and game documentation under `docs/3d_game/`. Keep the shared specification under `docs/`. Keep assistant conventions in this root file.
- Never print, stage, commit, or export API keys, local `.env` files, signed asset URLs, or generated job/profile data.
- Keep `.env.example` credential values blank. Preserve existing local keys when changing configuration.
- Run `backend/.venv/bin/python -m unittest discover -s backend/tests -v` after backend changes.
- Use offline tests and `--dry-run` by default. Make paid live calls only within the user's authorized testing scope.
- Before committing or pushing backend work, verify ignored files and scan the staged content for credentials without displaying their values.

## Issue tracking

- Deliver work through a feature branch and pull request linked to the relevant ticket(s), rather than direct commits to main. One PR may cover multiple related tickets.
- Use closing keywords for tickets fully resolved by the PR. After review approval, merge the PR and close the resolved tickets through that merge; do not close partially implemented tickets.
- When creating a ticket, also add it to the Four Otters project Kanban: https://github.com/users/AdeDeepFishing/projects/1 .
- Set its Status to match the work: To Do before starting, In progress while implementing, and In review when ready for user review. Do not mark unreviewed work Done.
- If the user requests a title-only ticket, leave its body empty.
