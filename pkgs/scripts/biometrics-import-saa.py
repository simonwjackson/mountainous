
"""
Import Sleep as Android CSV export into biometrics JSONL format.
Output: ~/biometrics/data/saa_sleep.jsonl
"""

import csv
import json
import os
import re
import sys
from datetime import datetime, timezone

DATA_DIR = os.path.expanduser("~/biometrics/data")
os.makedirs(DATA_DIR, exist_ok=True)

def parse_saa_datetime(s, tz_name):
    """Parse SAA date format like '13. 01. 2026 3:02'"""
    s = s.strip()
    # DD. MM. YYYY H:MM or DD. MM. YYYY HH:MM
    m = re.match(r'(\d+)\.\s*(\d+)\.\s*(\d+)\s+(\d+):(\d+)', s)
    if not m:
        return None
    day, month, year, hour, minute = (int(x) for x in m.groups())
    return f"{year:04d}-{month:02d}-{day:02d}T{hour:02d}:{minute:02d}:00"

def parse_events(extra_cols):
    """Parse the trailing event columns (HR, sleep stages, alarms, etc.)"""
    heart_rate = []
    sleep_stages = []
    events = []
    actigraphy = []
    
    current_stage = None
    
    for val in extra_cols:
        val = val.strip()
        if not val:
            continue
        
        # Heart rate: HR-timestamp-value
        hr_match = re.match(r'HR-(\d+)-(\d+\.?\d*)', val)
        if hr_match:
            heart_rate.append({
                "timestamp_ms": int(hr_match.group(1)),
                "bpm": float(hr_match.group(2))
            })
            continue
        
        # Sleep stages
        for stage in ['LIGHT', 'DEEP', 'REM']:
            start_match = re.match(rf'{stage}_START-(\d+)', val)
            end_match = re.match(rf'{stage}_END-(\d+)', val)
            if start_match:
                current_stage = {"stage": stage.lower(), "start_ms": int(start_match.group(1))}
                continue
            if end_match:
                if current_stage and current_stage["stage"] == stage.lower():
                    current_stage["end_ms"] = int(end_match.group(1))
                    sleep_stages.append(current_stage)
                    current_stage = None
                continue
        
        # Alarms and other events
        for evt_type in ['ALARM_LATEST', 'ALARM_STARTED', 'ALARM_DISMISS', 'ALARM_SNOOZE', 'BROKEN_START', 'BROKEN_END']:
            evt_match = re.match(rf'{evt_type}-(\d+)', val)
            if evt_match:
                events.append({"type": evt_type.lower(), "timestamp_ms": int(evt_match.group(1))})
                break
        
        # Try as actigraphy float
        try:
            v = float(val)
            actigraphy.append(v)
        except ValueError:
            pass
    
    return heart_rate, sleep_stages, events, actigraphy

def main():
    if len(sys.argv) < 2:
        print("Usage: import-saa.py <sleep-export.csv>")
        sys.exit(1)
    
    csv_path = sys.argv[1]
    outfile = os.path.join(DATA_DIR, "saa_sleep.jsonl")
    
    records = []
    
    with open(csv_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    i = 0
    while i < len(lines):
        line = lines[i].strip()
        if line.startswith('Id,Tz,'):
            # Header line — next line is data
            # Parse header to get scheduled alarm time (last column name)
            header_parts = next(csv.reader([line]))
            
            if i + 1 < len(lines):
                i += 1
                data_line = lines[i].strip()
                if data_line and not data_line.startswith('Id,Tz,'):
                    row = next(csv.reader([data_line]))
                    
                    record = {
                        "source": "sleep_as_android",
                        "id": row[0] if len(row) > 0 else None,
                        "timezone": row[1] if len(row) > 1 else None,
                        "bedtime_start": parse_saa_datetime(row[2], row[1]) if len(row) > 2 else None,
                        "bedtime_end": parse_saa_datetime(row[3], row[1]) if len(row) > 3 else None,
                        "scheduled_alarm": parse_saa_datetime(row[4], row[1]) if len(row) > 4 else None,
                        "hours": float(row[5]) if len(row) > 5 and row[5] else None,
                        "rating": float(row[6]) if len(row) > 6 and row[6] else None,
                        "comment": row[7].strip() if len(row) > 7 else "",
                        "framerate": row[8] if len(row) > 8 else None,
                        "snore": int(row[9]) if len(row) > 9 and row[9] not in ('', '-1') else None,
                        "noise": float(row[10]) if len(row) > 10 and row[10] not in ('', '-1.0') else None,
                        "cycles": int(row[11]) if len(row) > 11 and row[11] not in ('', '-1') else None,
                        "deep_sleep_pct": float(row[12]) if len(row) > 12 and row[12] not in ('', '-2.0', '-1.0') else None,
                        "len_adjust": int(row[13]) if len(row) > 13 else 0,
                        "geo": row[14] if len(row) > 14 and row[14] else None,
                    }
                    
                    # Parse tags from comment
                    tags = re.findall(r'#(\w+)', record["comment"])
                    record["tags"] = tags
                    record["manually_added"] = "Manually added" in record.get("comment", "")
                    
                    # Extra columns (actigraphy + events) start at index 15
                    extra = row[15:] if len(row) > 15 else []
                    hr, stages, events, actigraphy = parse_events(extra)
                    
                    if hr:
                        record["heart_rate"] = hr
                    if stages:
                        record["sleep_stages"] = stages
                    if events:
                        record["events"] = events
                    if actigraphy and any(v != -0.001 for v in actigraphy):
                        record["actigraphy"] = [v for v in actigraphy]
                    
                    # Derive day (date the sleep ended)
                    if record["bedtime_end"]:
                        record["day"] = record["bedtime_end"][:10]
                    
                    records.append(record)
        i += 1
    
    # Sort by bedtime_start
    records.sort(key=lambda r: r.get("bedtime_start") or "")
    
    with open(outfile, 'w') as f:
        for r in records:
            f.write(json.dumps(r) + '\n')
    
    # Stats
    total = len(records)
    with_hr = sum(1 for r in records if "heart_rate" in r)
    with_stages = sum(1 for r in records if "sleep_stages" in r)
    manual = sum(1 for r in records if r.get("manually_added"))
    date_range = f"{records[0].get('day', '?')} to {records[-1].get('day', '?')}" if records else "none"
    
    print(f"Imported {total} sleep records to {outfile}")
    print(f"  Date range: {date_range}")
    print(f"  With HR data: {with_hr}")
    print(f"  With sleep stages: {with_stages}")
    print(f"  Manually added: {manual}")

if __name__ == "__main__":
    main()
