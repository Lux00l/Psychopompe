#!/bin/bash
# Email Monitor for luc@soulerin.net
export PATH="/root/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
# Each non-empty line of the email body is sent to Hermes as a task
# in a session named after the email subject. Results are emailed back.

set -euo pipefail

HIMALAYA="/root/.local/bin/himalaya"
HERMES="/root/.local/bin/hermes"
SENDER=<your@email.net>
PROCESSED_FOLDER="Archive"
LOG="/home/Hermes/logs/email_monitor.log"
HERMES_MAIL=<hermes@account.mail>

mkdir -p "$(dirname "$LOG")"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG"; }

sanitize_session() {
    echo "$1" | sed 's/[^a-zA-Z0-9_-]/_/g' | cut -c1-64
}

send_email() {
    local to="$1"
    local subject="$2"
    local body="$3"
    local body_file="/tmp/hermes_body_$$.txt"
    
    echo "$body" > "$body_file"
    
    python3 -c "
import smtplib
from email.mime.text import MIMEText

with open('${body_file}', encoding='utf-8') as f:
    body_text = f.read()

msg = MIMEText(body_text, 'plain', 'utf-8')
msg['From'] = '<hermes@account.mail>'
msg['To'] = '${to}'
msg['Subject'] = '${subject}'

server = smtplib.SMTP('fx.ynh.fr', 587)
server.starttls()
server.login('<hermes@account.mail>', '<hermes@mail_passord>')
server.send_message(msg)
server.quit()
print('Email sent to ${to}')
" 2>&1 || log "ERROR: Failed to send email to ${to}"
    
    rm -f "$body_file"
}

# Search for emails from the trusted sender
RESULTS=$($HIMALAYA envelope search --mailbox Inbox from "$SENDER" 2>&1 || true)

# Extract email IDs using Python
IDS=$(echo "$RESULTS" | python3 -c "
import sys
for line in sys.stdin:
    parts = line.split()
    if len(parts) >= 2 and parts[0] == '│' and parts[1] != 'ID':
        print(parts[1])
" | sort -u)

if [ -n "$IDS" ]; then
    for ID in $IDS; do
        log "Found email ID: $ID from $SENDER"
        
        EMAIL_FULL=$($HIMALAYA message read "$ID" 2>&1 || true)
        
        # Extract subject
        SUBJECT=$(echo "$EMAIL_FULL" | grep "^Subject:" | head -1 | sed 's/^Subject:[[:space:]]*//' | tr -d '\r')
        
        # Extract body text/plain
        BODY=$(echo "$EMAIL_FULL" | python3 -c "
import sys, re
text = sys.stdin.read()
m = re.search(r'\[(\d+)\] text/plain.*?\n\n(.*?)(?=\n\[|$)', text, re.DOTALL)
if m:
    body = m.group(2).strip()
    body = '\n'.join(l for l in body.split('\n') if not l.startswith('Content-') and not l.startswith('['))
    print(body.strip())
else:
    print('')
" 2>&1 || echo "")
        
        SESSION_NAME=$(sanitize_session "$SUBJECT")
        log "Email $ID | Subject: $SUBJECT | Session: $SESSION_NAME"
        log "Body: $BODY"
        
        RESULTS_BODY=""
        LINE_NUM=0
        
        while IFS= read -r line; do
            trimmed=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            [[ -z "$trimmed" || "$trimmed" =~ ^# || "$trimmed" =~ ^--- ]] && continue
            LINE_NUM=$((LINE_NUM + 1))
            
            log "Processing line $LINE_NUM in session '$SESSION_NAME': $trimmed"
            
            OUTPUT=$($HERMES chat -q "$trimmed" --oneshot --continue "$SESSION_NAME" --create-if-missing --format stream-json 2>&1 || true)
            
            # Collect ALL text chunks from stream-json
            RESPONSE=$(echo "$OUTPUT" | python3 -c "
import sys, json
parts = []
for line in sys.stdin:
    try:
        obj = json.loads(line.strip())
        if obj.get('type') == 'text':
            parts.append(obj.get('text', ''))
    except:
        pass
print(''.join(parts).strip())
" 2>&1)
            
            if [ -z "$RESPONSE" ]; then
                RESPONSE="(no response or error)"
                log "Warning: empty response for line $LINE_NUM"
            fi
            
            log "Response: ${RESPONSE:0:100}..."
            RESULTS_BODY="${RESULTS_BODY}${trimmed}
↳ ${RESPONSE}

"
        done <<< "$BODY"
        
        if [ -n "$RESULTS_BODY" ]; then
            log "Sending results back to $SENDER"
            send_email "$SENDER" "RE: $SUBJECT" "$RESULTS_BODY"
            log "Results emailed to $SENDER"
        fi
        
        $HIMALAYA flag add "$ID" --flag seen 2>&1 || true
        $HIMALAYA message move --to "$PROCESSED_FOLDER" "$ID" 2>&1 || true
        log "Email $ID processed and archived."
    done
else
    log "No new emails from $SENDER"
fi
