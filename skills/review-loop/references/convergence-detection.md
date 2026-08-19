# Convergence detection and strategy escalation

Convergence detection is not a device for giving up. It is a device for noticing that you are
repeating one approach, so you can change the approach instead of the wording.

## Signals

- `plateau`: the last two rounds each improved by less than a token amount (findings closed,
  severity dropped) relative to the effort spent.
- `repetitive`: the new findings overlap the previous round's findings by roughly 80% or more,
  once normalised for phrasing.
- `severity_static`: the ratio of CRITICAL/HIGH findings is not falling across rounds.
- `runtime_repeat`: the same failure signature keeps appearing under the same strategy.

## Transitions

| Observation | Move |
|---|---|
| New findings, or severity falling | Continue with the current strategy: maker fixes, fresh checker re-reviews |
| `plateau` + `repetitive` | Close the current strategy; re-plan the approach before writing more code |
| The same finding returns REQUEST_CHANGES twice in a row | Stop and surface it to the human, with both attempted fixes and the reproduction (`rules/adversarial-review.md`) |
| The same blocker survives three rounds across two strategies | Escalate: different maker, different runtime, or a narrower reproduction that isolates the defect |
| Blocked by something outside the loop (credentials, a third-party outage, a missing permission) | Report the blocker and the restart condition; a human resumes it |

Switching strategy does not reset the maker set or the total round count. Only the consecutive-round
counter inside the new strategy starts again at zero.

**Precedence.** When more than one row matches, the human-escalation row wins: the same finding
returning `REQUEST_CHANGES` twice in a row stops the loop even if a strategy switch is also
available, and switching strategy is not a way to keep going past it. Two rounds on one finding
means the loop has stopped learning about that finding, and a third attempt without a human is a
guess with a fresh coat of paint. Resume only once the human has ruled on it.

## What does not count as convergence

- Rewording the goal so the same implementation now "satisfies" it.
- Downgrading a finding's severity without evidence that the impact is smaller than reported.
- An `UNVERIFIED` round. It carries no judgement, so it is neither progress nor a plateau; retry it
  with a different checker or runtime before counting rounds.
- Reusing an earlier `APPROVE` from before the last edit.

After a finding is fixed, never reuse an earlier verdict: call a fresh checker against the current
bytes.
