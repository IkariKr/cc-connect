# Fork / PR Plan

## Recommendation

Current recommendation:

1. Keep a long-lived personal fork branch for the Feishu + Codex workflow.
2. Upstream only the generic, reusable pieces in small PRs.
3. Do not split into a separate standalone project yet.

## Why

`cc-connect` already solves:

- Feishu inbound/outbound
- session management
- command/alias/config system
- attachment send-back
- startup and daemon flow

Your current additions are a mix of:

- generic Codex backend improvements
- Windows compatibility fixes
- Feishu observability improvements
- highly personal "local file -> send to me" workflow shortcuts

That mix is a strong sign that fork-first is the right move.

## Keep In Fork

These are tightly coupled to your own workflow and should stay in your fork first:

- direct local-send shortcut in `core/engine.go`
- helper-driven large-file/folder send flow
- 25 MB conservative split policy
- `AGENTS.md` local instructions
- fork-local `tools/send-local-item.ps1`
- private `codex_home` profile and local startup scripts
- any Chinese trigger heuristics aimed at your Feishu usage style

## Good PR Candidates

These are the best upstream candidates:

1. Codex app-server stdio backend
   Files:
   - `agent/codex/codex.go`
   - `agent/codex/appserver_session.go`

2. Windows custom command execution fix
   Files:
   - `core/engine.go`
   Scope:
   - use native shell on Windows
   - preserve `CC_PROJECT` / `CC_SESSION_KEY`

3. Attachment send-back robustness
   Files:
   - `core/engine.go`
   Scope:
   - allow proactive `SendToSessionWithAttachments` via reconstructed reply context

4. Feishu ingress observability
   Files:
   - `platform/feishu/feishu.go`

5. Optional slow-turn acknowledgment
   Files:
   - `core/engine.go`
   Note:
   - this one may need maintainer discussion because it changes user-visible behavior

## Branch Plan

Suggested local branch layout:

- `fork/main`
  Your stable long-lived branch.

- `feature/codex-feishu-control-plane`
  Your integration branch with all private workflow features.

- `pr/codex-app-server-stdio`
  Small clean PR branch for Codex app-server backend.

- `pr/windows-shell-command-fix`
  Small clean PR branch for Windows command execution.

- `pr/attachment-send-reconstruct-rctx`
  Small clean PR branch for proactive attachment send.

- `pr/feishu-ingress-logging`
  Small clean PR branch for inbound logging.

## Commit Plan

Suggested commit split:

1. `feat(codex): add app-server stdio backend`
2. `fix(engine): use powershell for custom exec commands on windows`
3. `fix(engine): allow proactive attachment send via reconstructed reply context`
4. `chore(feishu): promote inbound routing logs`
5. `feat(local): add direct local send shortcut for file delivery`
6. `feat(local): add helper for zipping and multi-part attachment send`

Commits 1-4 are the likely upstream set.
Commits 5-6 should stay in the fork for now.

## Decision Rule

Use this rule going forward:

- If the change helps any `cc-connect` user, consider PR.
- If the change depends on your local disk layout, your Feishu behavior, or your personal sending semantics, keep it in the fork.
- If more than half the value of a change comes from your own workflow assumptions, do not upstream it yet.

## Re-evaluate Standalone Project When

Consider a new standalone project only when:

- most new work is Codex-app-server-centric rather than `cc-connect`-centric
- you want first-class thread/task/file orchestration as the core product
- platform adapters start feeling like legacy baggage rather than leverage
- you are ready to own long-term platform maintenance yourself
