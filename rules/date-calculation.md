# Date & Time Calculation (CRITICAL)

## Absolute Rule

NEVER calculate dates/times mentally. ALWAYS use system tools.

LLMs frequently make errors in date arithmetic. Use Bash or Python for ALL date calculations: day-of-week, durations, D-day, leap years, month-end, etc.

## Required Patterns

### Current Date/Time
```bash
date '+%Y-%m-%d %A %H:%M:%S %Z'
```

### Day of Week (macOS)
```bash
date -j -f '%Y-%m-%d' '2026-03-15' '+%A'
```

### Day of Week (Linux)
```bash
date -d '2026-03-15' '+%A'
```

### N Days From Now (macOS)
```bash
date -j -v+30d '+%Y-%m-%d %A'    # 30 days later
date -j -v-7d '+%Y-%m-%d %A'     # 7 days ago
```

### N Days From Now (Linux)
```bash
date -d '+30 days' '+%Y-%m-%d %A'    # 30 days later
date -d '-7 days' '+%Y-%m-%d %A'     # 7 days ago
```

### Complex Date Calculations (Python)
```bash
python3 -c "
from datetime import datetime, timedelta
# Days between two dates
d1 = datetime(2026, 2, 6)
d2 = datetime(2026, 12, 31)
print(f'{(d2-d1).days} days')
"
```

## Forbidden

- Mental arithmetic for dates
- Guessing day-of-week
- Manual business day calculations

## Required

- Always use `date` command or `python3`
