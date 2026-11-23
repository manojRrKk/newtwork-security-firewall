# Test Cases

Formal test cases for the Network Security Lab. Each was executed against the running system;
the security-critical validation is additionally covered by automated tests
(`backend/tests`, run with `npm test`).

| ID | Title | Precondition | Steps | Expected result | Status |
|----|-------|--------------|-------|-----------------|--------|
| **TC-001** | Baseline connectivity | Demo Mode; mitigation rule disabled | Run *Test 01 · Baseline* against 192.168.10.10 | Victim reachable; ~100% availability, ~0% loss, low latency | Pass |
| **TC-002** | Blocked traffic | Mitigation rule **enabled** | Run *Test 03 · Mitigation* | Unauthorized flood dropped by pfSense; victim availability stays high; block counters rise | Pass |
| **TC-003** | Controlled high-rate traffic | Mitigation rule disabled | Run *Test 02 · High-Rate* (TCP, 3000 pps, 15 s) | Traffic rises **within** the configured caps; victim degrades; HIGH alert raised | Pass |
| **TC-004** | Firewall mitigation | Baseline + high-rate captured | Enable mitigation rule, repeat high-rate | Matching traffic blocked; availability recovers; before/after comparison populated | Pass |
| **TC-005** | Emergency stop | A test is running | Click **STOP TEST** | Test terminates immediately; status `stopped`; event recorded in audit log | Pass |
| **TC-006** | Invalid public target | Signed in as ADMIN | Start a test with target `8.8.8.8` | Backend rejects with `422 OUT_OF_SCOPE` / `PUBLIC_IP`; no test starts | Pass |
| **TC-007** | Unauthorized user | Signed in as VIEWER | Attempt to start a test | Backend rejects with `403 FORBIDDEN`; read-only pages still load | Pass |

| **TC-008** | Policy tester — first match | Mitigation rule disabled | Firewall → Policy tester: WAN, TCP, 10.10.10.10 → 192.168.10.10 port 80 | Verdict ALLOW by rule #101; trace shows #50 skipped (disabled) | Pass |
| **TC-009** | Policy tester — mitigation | Mitigation rule enabled | Repeat TC-008 | Verdict BLOCK by rule #50 | Pass |
| **TC-010** | Custom rule lifecycle | Signed in as ADMIN | Add a rule (#300 BLOCK TCP 10.10.10.99 → 192.168.10.10:8080), test it, delete it | Created with a "Custom" badge; tester matches #300; delete succeeds; audit log has RULE_CREATE / RULE_DELETE | Pass |
| **TC-011** | Built-in rule protection | Signed in as ADMIN | Try to delete a built-in rule via the API | `403 SYSTEM_RULE` (built-ins can only be disabled) | Pass |
| **TC-012** | Threshold detection | Default thresholds (1200 pps / 3 s) | Run *Test 02 · High-Rate* | `high-traffic-rate` alert + "Threshold exceeded" event within ~3 s; toast notification appears | Pass |
| **TC-013** | Threshold tuning | Signed in as ADMIN | Settings → set rate threshold to 5 | Rejected (`400`, minimum 50) | Pass |
| **TC-014** | Event search & export | Demo dataset loaded | Events → search `10.10.10.23`, then Export CSV | Only matching rows; CSV has a header row and the same filter | Pass |
| **TC-015** | Acknowledge all | Open alerts present; ANALYST | Alerts → Acknowledge all | All open alerts become acknowledged; VIEWER gets `403` | Pass |
| **TC-016** | Demo data reload | Demo Mode, ADMIN, no test running | Settings → Reload demo dataset | Fresh week of history; audit entry DEMO_DATA_RELOAD; refused while a test runs | Pass |
| **TC-017** | Project details | ADMIN | Settings → edit institution/team → Save | Cover block (Overview) and report cover update; VIEWER cannot edit | Pass |

## Additional guardrail checks (verified)

| Check | Input | Expected |
|-------|-------|----------|
| Out-of-scope private target | `192.168.99.5` | `422 OUT_OF_SCOPE` |
| Unconfirmed request | `confirmed:false` | `400 NOT_CONFIRMED` |
| Rate over cap | `maxPps: 99999` | `422 RATE_TOO_HIGH` |
| Duration over cap | `durationSeconds: 99999` | `422 DURATION_TOO_LONG` |
| Disallowed protocol | `GRE` | `422 PROTOCOL_NOT_ALLOWED` |
| VIEWER reads topology | GET /network/topology | `200 OK` (read-only allowed) |

## Automated coverage

`npm test` runs **81 automated tests** (Vitest): 71 backend + 10 frontend.

| File | Tests | Covers |
|------|------:|--------|
| `backend/tests/validation.test.ts` | 15 | IPv4/CIDR parsing, public/private/loopback, target allowlist, request caps & confirmation |
| `backend/tests/password.test.ts` | 4 | scrypt round-trip, wrong password, unique salts, malformed hash |
| `backend/tests/policy.test.ts` | 14 | address/port/protocol matching, first-match order, disabled rules, default & implicit deny, interface scoping, REJECT, rule input validation |
| `backend/tests/detection.test.ts` | 8 | sustained-threshold detection, severity escalation, spike filtering, drop-spike vs rate, threshold persistence & bounds |
| `backend/tests/demoData.test.ts` | 7 | deterministic PRNG, extended topology, rule #50 ordering, idempotent seeding, reproducible history, provenance, alert states |
| `backend/tests/api.test.ts` | 23 | HTTP end-to-end: login, 401/403/404, RBAC per role, test guardrails, custom rules, policy tester, event search/CSV/timeline, ack-all, 24 h traffic, project info, thresholds, demo reload |
| `frontend/tests/format.test.ts` | 6 | number / rate / byte / duration / relative-time formatting |
| `frontend/tests/quiz-nav.test.ts` | 4 | Lab Manual quiz integrity & scoring, chapter numbering |

Each backend test file uses its own throwaway SQLite database (`backend/tests/setup.ts`), so tests
never touch `backend/data/lab.sqlite`.

Destructive network tests are **not** automated; TC-001…005 are executed manually (Demo Mode)
or on the isolated lab (Lab Mode).
