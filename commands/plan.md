---
description: AI가 구현 계획을 세워줍니다. 확인 후 코딩 시작.
allowed-tools: Agent, Read, Glob, Grep
---

# Plan Command

This command invokes the **planner** agent to create a comprehensive implementation plan before writing any code.

## What This Command Does

1. **Restate Requirements** - Clarify what needs to be built
2. **Identify Risks** - Surface potential issues and blockers
3. **Create Step Plan** - Break down implementation into phases
4. **Wait for Confirmation** - MUST receive user approval before proceeding

## When to Use

Use `/plan` when:
- Starting a new feature
- Making significant architectural changes
- Working on complex refactoring
- Multiple files/components will be affected
- Requirements are unclear or ambiguous

## How It Works

The planner agent will:

1. **Analyze the request** and restate requirements in clear terms
2. **Break down into phases** with specific, actionable steps
3. **Identify dependencies** between components
4. **Assess risks** and potential blockers
5. **Estimate complexity** (High/Medium/Low)
6. **Present the plan** and WAIT for your explicit confirmation

## Example Usage

```
User: /plan I need to add real-time notifications when markets resolve

Agent (planner):
# Implementation Plan: Real-Time Market Resolution Notifications

## Requirements Restatement
- Send notifications to users when markets they're watching resolve
- Support multiple notification channels (in-app, email, webhook)
- Ensure notifications are delivered reliably
- Include market outcome and user's position result

## Implementation Phases

### Phase 1: Database Schema
- Add notifications table with columns: id, user_id, market_id, type, status, created_at
- Add user_notification_preferences table for channel preferences
- Create indexes on user_id and market_id for performance

### Phase 2: Notification Service
- Create notification service in lib/notifications.ts
- Implement notification queue using BullMQ/Redis
- Add retry logic for failed deliveries
- Create notification templates

### Phase 3: Integration Points
- Hook into market resolution logic (when status changes to "resolved")
- Query all users with positions in market
- Enqueue notifications for each user

### Phase 4: Frontend Components
- Create NotificationBell component in header
- Add NotificationList modal
- Implement real-time updates via Supabase subscriptions
- Add notification preferences page

## Dependencies
- Redis (for queue)
- Email service (SendGrid/Resend)
- Supabase real-time subscriptions

## Risks
- HIGH: Email deliverability (SPF/DKIM required)
- MEDIUM: Performance with 1000+ users per market
- MEDIUM: Notification spam if markets resolve frequently
- LOW: Real-time subscription overhead

## Estimated Complexity: MEDIUM
- Backend: 4-6 hours
- Frontend: 3-4 hours
- Testing: 2-3 hours
- Total: 9-13 hours

**WAITING FOR CONFIRMATION**: Proceed with this plan? (yes/no/modify)
```

## Common Rationalizations — 계획 건너뛰기 합리화 차단

| 변명 | 현실 |
|------|------|
| "간단해서 계획 안 해도 돼" | 간단한 것도 3+ 파일 수정이면 계획 필요. "간단하다"는 착각이 가장 위험. |
| "이미 머릿속에 다 있어" | 머릿속 계획은 빠진 게 보이지 않는다. 문서화하면 빈 곳이 드러남. |
| "시간 없어서 바로 코딩" | 계획 없이 코딩 → 재작업 시간이 계획 시간의 3~5배. |
| "요구사항이 명확해서" | 명확한 요구사항도 구현 순서/의존성/리스크는 계획에서 드러남. |
| "프로토타입이니까" | 프로토타입이 프로덕션 되는 법. 최소한의 계획이라도 세워라. |
| "코드 보면서 파악할게" | 코드 읽기는 탐색이지 계획이 아니다. 방향 없는 탐색은 시간 낭비. |
| "이전에 비슷한 거 해봤으니까" | 비슷하다고 같지 않다. 차이점이 버그의 원인. |

## Red Flags — 즉시 /plan 실행

- 수정할 파일이 3개 이상인데 계획 없이 시작
- "일단 해보고 안 되면 고치자"
- 코드 작성 시작 후 "아, 이것도 바꿔야 하네" 연쇄 발생
- 30분 이상 코딩했는데 완료 기준이 불명확
- 팀원/사용자에게 "얼마나 걸려?" 질문에 답 못 함

## Important Notes

**CRITICAL**: The planner agent will **NOT** write any code until you explicitly confirm the plan with "yes" or "proceed" or similar affirmative response.

If you want changes, respond with:
- "modify: [your changes]"
- "different approach: [alternative]"
- "skip phase 2 and do phase 3 first"

## Integration with Other Commands

After planning:
- Use `/tdd` to implement with test-driven development
- Use `/build-and-fix` if build errors occur
- Use `/code-review` to review completed implementation

## Related Agents

This command invokes the `planner` agent located at:
`~/.claude/agents/planner.md`

---

## 다음 단계

계획이 확정되면:
- `/tdd`로 구현 시작
- `/auto`로 전체 자동 진행
