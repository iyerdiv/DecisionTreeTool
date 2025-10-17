# DecisionTreeTool v2 - Daemon Watcher

Automatic file system event tracking daemon for decision tree workflows.

## Features

- **Real-time File Monitoring**: Tracks all file changes in your workspace
- **Automatic Event Logging**: Appends events to decision tree markdown files
- **Hybrid Memory + Disk Caching** 🚀: Optimized event storage with 500-event circular buffer + persistent JSONL logs
- **High-Performance Append-Only Logging**: 99% I/O reduction (5102 events/sec vs 43 events/sec)
- **Smart Categorization**: Auto-detects event types (code changes, prompts, documentation)
- **AI-Powered WHY Extraction** ✨: Infers decision-making reasoning from file changes (requires API key)
- **Automatic Section Placement**: Places events in appropriate decision tree categories
- **Daemon Mode**: Runs as background process with PID management
- **Unique Event IDs**: Collision-free IDs using timestamp + hash
- **Atomic Writes**: Corruption-proof file updates

## Quick Start

```bash
# Install
cd v2-daemon
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Start watcher (foreground)
./watcher.py start --watch-path /path/to/workspace --tree-path /path/to/tree.md

# Start as daemon (background)
./watcher.py start --watch-path /path/to/workspace --tree-path /path/to/tree.md --daemon

# Check status
./watcher.py status --watch-path /path/to/workspace

# Stop daemon
./watcher.py stop --watch-path /path/to/workspace
```

## Installation

```bash
cd v2-daemon
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

## Usage

### Basic Mode

```bash
./watcher.py start \
  --watch-path /path/to/your/workspace \
  --tree-path /path/to/decision_tree.md
```

Press `Ctrl+C` to stop.

### AI-Powered Mode ✨ (Recommended)

Enable intelligent WHY extraction with AI categorization:

```bash
# Set your API key
export ANTHROPIC_API_KEY=sk-ant-...

# Start with AI enabled
./watcher.py start \
  --watch-path /path/to/your/workspace \
  --tree-path /path/to/decision_tree.md \
  --enable-ai
```

**What AI Mode Does:**
- Infers **WHY** decisions were made from file changes
- Extracts **intent** and **reasoning** from context
- Automatically categorizes events into decision tree sections
- Captures **impact** and **implications**
- Generates searchable keywords

**Example AI Output:**
```markdown
🔹 **Decision: Switch to JWT-based authentication**
   - **What**: Implemented JWT token generation in auth.py
   - **Why**: Moving away from session-based auth to enable stateless API authentication for mobile clients
   - **Impact**: Enables horizontal scaling and better mobile app support. Will require client changes.
   - **Time**: 14:23:45
   - **Keywords**: authentication, jwt, stateless, mobile, api
```

### Daemon Mode

```bash
# Start as background daemon
./watcher.py start \
  --watch-path /path/to/your/workspace \
  --tree-path /path/to/decision_tree.md \
  --daemon \
  --enable-ai  # Optional: enable AI

# Check status
./watcher.py status --watch-path /path/to/your/workspace

# Stop
./watcher.py stop --watch-path /path/to/your/workspace
```

## Event Log Format

Events are logged in this format:

```markdown
- [HH:MM:SS] (id:YYYYMMDDTHHMMSS-[hash]) /path/to/file → event_type #tag1 #tag2
```

Example:
```markdown
- [14:23:45] (id:20251014T142345-a3b5c7d9) src/main.py → code_change #auto #workspace #source_code
- [14:24:12] (id:20251014T142412-e1f2g3h4) prompts/next.md → prompt_created #auto #claude_prompts
```

## Event Types

- `file_change` - General file modification
- `code_change` - Source code file (.py, .js, .java, etc.)
- `prompt_created` - AI prompt file created/modified
- `tree_update` - Decision tree markdown updated
- `doc_change` - Documentation file updated

## Automatic Hashtags

- `#auto` - All auto-generated events
- `#workspace` - Workspace events
- `#source_code` - Code file changes
- `#claude_prompts` - Prompt directory changes
- `#daily_trees` - Tree file updates
- `#created` - File creation events
- `#update` - File modification events

## Architecture

```
v2-daemon/
├── src/watcher/
│   ├── __init__.py       # Package init
│   ├── event.py          # Event data structures + hybrid caching (memory + disk)
│   ├── watcher.py        # File system monitoring
│   ├── logger.py         # Tree file logging (append-only optimized)
│   └── daemon.py         # Daemon process management
├── watcher.py            # Main CLI entry point
├── requirements.txt      # Python dependencies
└── README.md            # This file
```

## Performance Optimizations

### Hybrid Caching System
- **Memory Cache**: 500-event circular buffer (`deque` with `maxlen=500`)
- **Disk Persistence**: Append-only JSONL logs at `.opsbrain_cache/YYYY/events_YYYYMMDD.jsonl`
- **No Data Loss**: All events persisted to disk immediately
- **Fast Queries**: Recent events served from memory
- **Auto-Cleanup**: Circular buffer prevents memory bloat

### Append-Only Logging
- **99% I/O Reduction**: Simple append vs full file read/write
- **Performance**: 5102 events/sec (vs 43 events/sec with full file operations)
- **Single System Call**: `open(file, 'a')` + write + close
- **No Temp Files**: Direct append to tree markdown files
- **Atomic Operations**: Crash-safe logging

### Cache Directory Structure
```
workspace_root/
├── .opsbrain_cache/        # Git-ignored cache directory (local only)
│   └── YYYY/               # Year-based organization
│       ├── events_20251014.jsonl
│       ├── events_20251015.jsonl
│       └── events_20251016.jsonl
├── daily_trees/            # Git-ignored decision trees (auto-mirrored to OneDrive)
│   └── YYYY/
│       ├── OpsBrain_20251014_V01.md
│       └── OpsBrain_20251016_V04.md
└── .gitignore             # Excludes cache and trees from git
```

**Cloud Backup Strategy:**
- Cache files (`.opsbrain_cache/`) are **local only** - excluded from git and cloud sync
- Decision trees (`daily_trees/`) are **auto-mirrored to OneDrive** via rsync
- Keeps git history clean while maintaining cloud backup of important trees
- Use `rsync -av --update daily_trees/ /path/to/OneDrive/` to sync manually if needed

## Dependencies

- `watchdog` - File system monitoring
- `click` - CLI framework
- `pyyaml` - Configuration support
- `python-daemon` - Daemon process support

## Integration with Decision Trees

The watcher automatically creates and updates decision tree files with this structure:

```markdown
# Decision Tree - YYYY-MM-DD
## Auto-generated by Watcher v2

---

## 📋 Categories

### ✅ 1. Decisions Made
*Placeholder*

### 🔧 2. Actions Taken
*Placeholder*

[... more categories ...]

---

## 📝 Event Log

- [HH:MM:SS] (id:...) /path → event_type #tags
```

## Configuration

The watcher can be configured to:
- Ignore specific file patterns (default: `.git`, `__pycache__`, `.DS_Store`)
- Customize event categorization rules
- Adjust hashtag generation logic

See `src/watcher/watcher.py` for configuration options.

## Troubleshooting

**Daemon won't start:**
- Check if another instance is running: `ps aux | grep watcher.py`
- Remove stale PID file: `rm /path/to/workspace/.watcher.pid`

**Events not logging:**
- Verify tree file path is correct
- Check file permissions
- Ensure workspace path is absolute

**Import errors:**
- Activate virtual environment: `source venv/bin/activate`
- Reinstall dependencies: `pip install -r requirements.txt`

## License

Same as parent DecisionTreeTool repository.

## Version History

- **v2.0.0** - Initial daemon watcher release with automatic event tracking
