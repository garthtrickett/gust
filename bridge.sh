#!/usr/bin/env bash
WATCH_DIR="$HOME/Downloads"
PROJECT_DIR=$(pwd)
cd "$PROJECT_DIR" || exit

echo "👀 Watching $WATCH_DIR for Gemini responses..."

inotifywait -m -e close_write -e moved_to --format '%f' "$WATCH_DIR" | while read -r FILE; do
    if [[ "$FILE" == *.json ]] || [[ "$FILE" == *.txt ]] || [[ "$FILE" == *.ts ]]; then
        sleep 0.2
        FULL_PATH="$WATCH_DIR/$FILE"

        if [ -f "$FULL_PATH" ]; then
            echo "----------------------------------------"
            echo "📂 Detected: $FILE"
            cp "$FULL_PATH" "current_response.json"

            echo "⚙️  Processing changes..."

            # Stream Python output directly to terminal AND capture it in a log file simultaneously
            python3 apply_changes.py "current_response.json" 2>&1 | tee /tmp/gemini_apply.log

            # Capture the exit code of the python script (not the tee command)
            EXIT_CODE=${PIPESTATUS[0]}

            # Read the output back from the log for our summary parsing
            PYTHON_OUT=$(cat /tmp/gemini_apply.log)

            if [ $EXIT_CODE -eq 0 ]; then
                # SUCCESS CASE
                SUMMARY=$(echo "$PYTHON_OUT" | grep "🤖 Summary:" | sed 's/🤖 Summary: //')

                echo -e "\n🔍 Reviewing changes:"
                git diff --color=always | sed 's/^/  /'
                echo -e "\n"

                rm "current_response.json"

                git add .
                git commit -m "${SUMMARY:-Gemini Update}"

                echo "📜 Files Changed:"
                git show --name-only --format="" HEAD | sed 's/^/  📄 /'
                notify-send "Gemini Success" "All changes applied and committed."
            else
                # FAILURE CASE
                echo "⛔ TRANSACTION FAILED: One or more blocks did not match."
                echo "No files were modified. Re-sync your codebase in Gemini and try again."
                notify-send -u critical "Gemini Failed" "Search blocks mismatch. No changes applied."
            fi

            rm "$FULL_PATH"
            echo "----------------------------------------"
        fi
    fi
done
