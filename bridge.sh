#!/usr/bin/env bash
# File: bridge.sh
# ==============================================================================

# Directory where your browser downloads files (e.g., Gemini or AI Studio exports)
WATCH_DIR="$HOME/Downloads"
PROJECT_DIR=$(pwd)

cd "$PROJECT_DIR" || exit 1

# Locate the aider-patcher binary
if command -v aider-patcher &>/dev/null; then
    PATCHER_BIN="aider-patcher"
elif [ -f "./aider-patcher" ]; then
    PATCHER_BIN="./aider-patcher"
elif [ -f "./target/release/aider-patcher" ]; then
    PATCHER_BIN="./target/release/aider-patcher"
else
    echo "❌ ERROR: 'aider-patcher' binary not found."
    echo "Please copy it to /usr/local/bin or place it in this project folder."
    exit 1
fi

echo "👀 Watching $WATCH_DIR for incoming patch payloads..."

# File watcher loop
if command -v inotifywait &>/dev/null; then
    # Linux (requires inotify-tools)
    inotifywait -m -e close_write -e moved_to --format '%f' "$WATCH_DIR" | while read -r FILE; do
        # Check for both .json and .txt files
        if [[ "$FILE" == *.json || "$FILE" == *.txt ]]; then
            sleep 0.2
            FULL_PATH="$WATCH_DIR/$FILE"
            if [ -f "$FULL_PATH" ]; then
                echo "----------------------------------------"
                echo "📂 Detected: $FILE"
                cp "$FULL_PATH" "current_response.json"

                echo "⚙️  Processing changes with Rust AiderPatcher..."

                # Execute patcher
                "$PATCHER_BIN" --patch "current_response.json" --cwd "$PROJECT_DIR" 2>&1 | tee /tmp/patcher_apply.log
                EXIT_CODE=${PIPESTATUS[0]}

                PATCHER_OUT=$(cat /tmp/patcher_apply.log)

                if [ $EXIT_CODE -eq 0 ]; then
                    SUMMARY=$(echo "$PATCHER_OUT" | grep "🤖 Summary:" | sed 's/🤖 Summary: //')

                    echo -e "\n🔍 Reviewing changes:"
                    git diff --color=always | sed 's/^/  /'
                    echo -e "\n"

                    git add .
                    git commit -m "${SUMMARY:-AI Code Update}"

                    echo "📜 Files Changed:"
                    git show --name-only --format="" HEAD | sed 's/^/  📄 /'
                    if command -v notify-send &>/dev/null; then
                        notify-send "Patcher Success" "All changes applied and committed."
                    fi
                else
                    echo "⛔ TRANSACTION FAILED: One or more blocks did not match."
                    if command -v notify-send &>/dev/null; then
                        notify-send -u critical "Patcher Failed" "Search blocks mismatch. No changes applied."
                    fi
                fi

                rm -f "current_response.json"
                rm -f "$FULL_PATH"
                echo "----------------------------------------"
            fi
        fi
    done
elif command -v fswatch &>/dev/null; then
    # macOS (requires fswatch)
    fswatch -0 "$WATCH_DIR" | while read -r -d "" FULL_PATH; do
        # Check for both .json and .txt files
        if [[ "$FULL_PATH" == *.json || "$FULL_PATH" == *.txt ]]; then
            FILE=$(basename "$FULL_PATH")
            sleep 0.2
            if [ -f "$FULL_PATH" ]; then
                echo "----------------------------------------"
                echo "📂 Detected: $FILE"
                cp "$FULL_PATH" "current_response.json"

                echo "⚙️  Processing changes with Rust AiderPatcher..."

                "$PATCHER_BIN" --patch "current_response.json" --cwd "$PROJECT_DIR" 2>&1 | tee /tmp/patcher_apply.log
                EXIT_CODE=${PIPESTATUS[0]}

                PATCHER_OUT=$(cat /tmp/patcher_apply.log)

                if [ $EXIT_CODE -eq 0 ]; then
                    SUMMARY=$(echo "$PATCHER_OUT" | grep "🤖 Summary:" | sed 's/🤖 Summary: //')

                    echo -e "\n🔍 Reviewing changes:"
                    git diff --color=always | sed 's/^/  /'
                    echo -e "\n"

                    git add .
                    git commit -m "${SUMMARY:-AI Code Update}"

                    echo "📜 Files Changed:"
                    git show --name-only --format="" HEAD | sed 's/^/  📄 /'
                    if command -v osascript &>/dev/null; then
                        osascript -e 'display notification "All changes applied and committed." with title "Patcher Success"'
                    fi
                else
                    echo "⛔ TRANSACTION FAILED: One or more blocks did not match."
                    if command -v osascript &>/dev/null; then
                        osascript -e 'display notification "Search blocks mismatch. No changes applied." with title "Patcher Failed"'
                    fi
                fi

                rm -f "current_response.json"
                rm -f "$FULL_PATH"
                echo "----------------------------------------"
            fi
        fi
    done
else
    echo "❌ ERROR: Neither 'inotifywait' nor 'fswatch' is installed."
    echo "Please install 'inotify-tools' (Linux) or 'fswatch' (macOS) to run this script."
    exit 1
fi
