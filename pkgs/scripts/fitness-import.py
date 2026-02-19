"""Convert Hevy CSV export to log.jsonl + exercises.yaml"""
import csv
import json
import re
from collections import defaultdict, OrderedDict
from datetime import datetime

rows = []
with open('/home/simonwjackson/fitness/import.csv', 'r') as f:
    reader = csv.DictReader(f)
    for row in reader:
        rows.append(row)

# Group by workout session (start_time)
sessions = defaultdict(list)
for row in rows:
    key = row['start_time']
    sessions[key].append(row)

# Build log entries
log_entries = []
exercise_latest = {}  # track latest weight per exercise

def parse_date(s):
    try:
        return datetime.strptime(s, "%d %b %Y, %H:%M")
    except:
        return datetime.min

for start_time, sets in sorted(sessions.items(), key=lambda x: parse_date(x[0])):
    # Parse date
    try:
        dt = datetime.strptime(start_time, "%d %b %Y, %H:%M")
    except:
        continue
    
    date_str = dt.strftime("%Y-%m-%d")
    
    # Group sets by exercise within this session
    exercises_in_session = OrderedDict()
    for s in sets:
        ex_name = s['exercise_title']
        if ex_name not in exercises_in_session:
            exercises_in_session[ex_name] = {
                'warmup': [],
                'working': [],
                'notes': s.get('exercise_notes', '').strip()
            }
        
        set_type = s['set_type']
        weight = float(s['weight_lbs']) if s['weight_lbs'] else None
        reps = int(s['reps']) if s['reps'] else None
        failed = set_type == 'failure'
        
        set_entry = {'reps': reps}
        if weight is not None:
            set_entry['weight'] = weight
        if failed:
            set_entry['failed'] = True
        
        if set_type == 'warmup':
            exercises_in_session[ex_name]['warmup'].append(set_entry)
        else:
            exercises_in_session[ex_name]['working'].append(set_entry)
    
    # Build exercise entries
    exercise_list = []
    for ex_name, data in exercises_in_session.items():
        # Normalize exercise name to id
        ex_id = re.sub(r'[^a-z0-9]+', '-', ex_name.lower()).strip('-')
        
        entry = {'id': ex_id, 'name': ex_name}
        if data['warmup']:
            entry['warmup'] = data['warmup']
        if data['working']:
            entry['sets'] = data['working']
        if data['notes']:
            entry['notes'] = data['notes']
        
        exercise_list.append(entry)
        
        # Track latest working weight
        for s in data['working']:
            if 'weight' in s and s['weight']:
                exercise_latest[ex_id] = {
                    'name': ex_name,
                    'lastWeight': s['weight'],
                    'lastDate': date_str,
                }
    
    # Session description/notes
    title = sets[0].get('title', '')
    desc = sets[0].get('description', '').strip()
    
    log_entry = {
        'date': date_str,
        'start': dt.strftime("%H:%M"),
        'exercises': exercise_list,
    }
    if title:
        log_entry['title'] = title
    if desc:
        log_entry['notes'] = desc
    
    log_entries.append(log_entry)

# Write log.jsonl (chronological)
with open('/home/simonwjackson/fitness/log.jsonl', 'w') as f:
    for entry in log_entries:
        f.write(json.dumps(entry, separators=(',', ':')) + '\n')

print(f"Wrote {len(log_entries)} sessions to log.jsonl")

# Build exercises.yaml from latest data (most recent 2025-2026 sessions)
# Focus on exercises used in recent months
recent_exercises = {k: v for k, v in exercise_latest.items() 
                    if v['lastDate'] >= '2025-01-01'}

print(f"\nRecent exercises ({len(recent_exercises)}):")
for eid, info in sorted(recent_exercises.items(), key=lambda x: x[1]['lastDate'], reverse=True):
    print(f"  {info['name']}: {info['lastWeight']}lb (last: {info['lastDate']})")
