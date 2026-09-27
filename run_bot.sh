#!/bin/bash
# run_bot.sh - launch wrapper for fomo_trader.py.
#
# The bot kept dying with no traceback and no log line, which made the cause
# undiagnosable: `setsid nohup ... &` discards the process's exit status.
# This wrapper stays alive as the bot's parent, waits on it, and records the
# exit code in deaths.log so the NEXT death identifies itself:
#   137 = SIGKILL (killed from outside: infra policer, OOM killer, kill -9)
#   139 = segfault (native crash in the HTTP/TLS stack)
#   143 = SIGTERM (orderly shutdown: watchdog restart, manual kill)
#    42 = halt.flag kill-switch   0 = clean exit
#
# Launch detached: setsid nohup /home/hatch/workspace/fomo-trader/run_bot.sh \
#     >> /home/hatch/workspace/fomo-trader/runs/paper-1h/wrapper.log 2>&1 < /dev/null &
set -u
PROJ=/home/hatch/workspace/fomo-trader
RUN_DIR=$PROJ/runs/paper-1h
DEATHS=$RUN_DIR/deaths.log

prev=$(cat "$RUN_DIR/bot.pid" 2>/dev/null || true)
if [ -n "$prev" ]; then
    if kill -0 "$prev" 2>/dev/null && ps -p "$prev" -o args= 2>/dev/null | grep -q 'fomo_trader'; then
        echo "[$(date '+%F %T %Z')] refusing to start: bot pid $prev already alive" >> "$DEATHS"
        exit 0
    fi
    echo "[$(date '+%F %T %Z')] previous pidfile held dead PID $prev -> unclean death" >> "$DEATHS"
fi
# belt-and-braces: never start a second bot for this run dir, even if the
# pidfile is briefly absent (restart overlap). The [.] keeps pgrep from
# matching its own command line.
if pgrep -f "fomo_trader[.]py --config $RUN_DIR/config[.]json" >/dev/null 2>&1; then
    echo "[$(date '+%F %T %Z')] refusing to start: a bot for this run dir is already alive (pgrep)" >> "$DEATHS"
    exit 0
fi

"$PROJ/.venv/bin/python" "$PROJ/fomo_trader.py" \
    --config "$RUN_DIR/config.json" >> "$RUN_DIR/bot.log" 2>&1 < /dev/null &
BPID=$!
echo "$BPID" > "$RUN_DIR/bot.pid"
echo "[$(date '+%F %T %Z')] bot started pid $BPID" >> "$DEATHS"

wait "$BPID"
CODE=$?
echo "[$(date '+%F %T %Z')] bot pid $BPID exited with code $CODE" >> "$DEATHS"
exit "$CODE"
