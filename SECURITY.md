# Slim City — Security Posture (verified)

_Last verified: 2026-11-05. Re-run the checks below if the setup changes._

This records how the KiroCrew agent working on this repo is confined, how the
dashboard is reached from a phone, and what is NOT fenced. It was verified by
direct inspection, not assumed.

## The setup in one line

Kiro Crew runs as a plain macOS app on a real Mac (`stevens-mac-mini`). The
agent is confined by the **strict** OS sandbox. The dashboard is loopback-only
and reached from the phone over **Tailscale Serve** (tailnet-only HTTPS).

## What IS fenced (verified)

| Protection | State | How it was verified |
|---|---|---|
| Agent file sandbox | `agent.sandbox = strict` | `kirocrew config get agent.sandbox` → `strict` |
| `~/.aws` hidden from agent | yes | `ls ~/.aws` → `Operation not permitted` |
| `~/.ssh` write blocked | yes | write to `~/.ssh/sbtest` → `operation not permitted` |
| `~/.kube` write blocked | yes | write to `~/.kube/sbtest` → blocked |
| Agent can't change its own cage | yes | `kirocrew config set agent.sandbox …` refused from inside the sandbox |
| Gateway not exposed to the network | yes | listens on `127.0.0.1:5476` + `::1:5476` only (loopback) |
| Build/test still works under sandbox | yes | `./SlimCityCore/scripts/test.sh` → 41 tests pass |
| Tailscale dashboard scope | tailnet only | `tailscale serve status` → "(tailnet only)"; Funnel is OFF |

## What is NOT fenced (know these)

- **Network egress.** The strict sandbox fences files, not the network. The
  agent can still make outbound connections. The command deny-list blocks the
  obvious `curl -d @file` exfil shape, but a wrapped command can slip past it
  (KiroCrew docs call that layer "friction, not a boundary").
- **Writes to non-secret parts of `$HOME`.** Strict hides credential dirs, not
  all of home. `~/.zshrc`, `~/.gitconfig` (incl. `core.hooksPath`),
  `~/Library/LaunchAgents` are still writable — and code written there runs
  later, outside the sandbox. Watch these if that matters.
- **Reads of most of the Mac.** Strict hides the secret dirs, not the rest of
  the filesystem.

## How the phone reaches the dashboard

```
iphone171 → https://stevens-mac-mini.tail82947b.ts.net → Tailscale Serve → 127.0.0.1:5476
```

- The gateway binds to **loopback only**. It never opens a network port itself.
- **Tailscale Serve** proxies that loopback port onto the tailnet over HTTPS.
- Scope is **tailnet only** — reachable from your own devices, not the public
  internet.

### The one edge to watch

`tailscale serve` and `tailscale funnel` share plumbing. **Funnel** exposes a
service to the *entire public internet*. It is currently OFF (status reads
"tailnet only"). Do not run `tailscale funnel` on this service — it would throw
the dashboard open to the world. Keep it on Serve (tailnet only).

## Build limits (not security, but related)

- App targets (iOS/watch, SceneKit, HealthKit) need Xcode + a simulator and
  must build on this Mac. They cannot build in a Linux container, and macOS
  cannot be containerized — so a Docker-isolated gateway would LOSE Xcode. That
  is why the agent runs on the real Mac, not in a box.
- The pure-Swift package (`SlimCityCore`) builds/tests headlessly via
  `./SlimCityCore/scripts/test.sh` (which passes `--disable-sandbox` so
  SwiftPM's own nested sandbox is skipped while the outer fence still holds).

## Rejected approaches (and why)

- **Custom `~/.kiro/settings/sandbox.json` + `kiro-global.sb`** — the `.sb` file
  is read by nobody; KiroCrew builds its own seatbelt profile from
  `agent.sandbox`. That file and `sandbox.json` are inert here; safe to delete.
- **Linux Docker container for the gateway** — closes the network/blast-radius
  gap, but loses Xcode (Apple frameworks are macOS-only). Not worth it for a
  Mac-native app.

## Re-verify

```bash
kirocrew config get agent.sandbox            # expect: strict
ls ~/.aws                                     # expect: Operation not permitted
netstat -an | grep 5476                       # expect: 127.0.0.1 / ::1 only
tailscale serve status                        # expect: "(tailnet only)"
tailscale funnel status                       # expect: NOT publicly exposed
./SlimCityCore/scripts/test.sh                # expect: tests pass
```
