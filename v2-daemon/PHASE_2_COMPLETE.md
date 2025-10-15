# Phase 2 Complete: AI-Powered WHY Extraction

## Status: ✅ COMPLETE

**Commit**: 5713e0b
**Branch**: v2-daemon-watcher
**Date**: 2025-10-15

---

## What Was Built

Phase 2 adds **AI-powered decision reconstruction** to DecisionTreeTool v2, transforming it from a simple file watcher into an intelligent system that captures **WHY decisions were made**, not just WHAT changed.

### Core Components

#### 1. **CategoryEngine** (`src/watcher/category_engine.py`)
AI-powered categorization engine that:
- Extracts WHY decisions were made from file system events
- Analyzes file content for context
- Categorizes events into 10 decision tree sections
- Uses Claude 3.5 Sonnet for intelligent extraction
- Gracefully falls back to rule-based categorization without API key

**10 Categories**:
1. Decisions Made
2. Actions Taken
3. Files Created/Modified
4. Issues Encountered
5. Insights & Learnings
6. Dependencies & Requirements
7. TODO Items Generated
8. Questions & Answers
9. Testing & Validation
10. Debugging Steps

**Key Features**:
- WHY-focused prompt engineering (4 detailed examples)
- Context enrichment (reads first 500 chars of modified files)
- Structured JSON output: `{what, why, impact, keywords}`
- Confidence scoring (0.0-1.0)
- Searchable keyword generation

#### 2. **IntelligentLogger** (`src/watcher/intelligent_logger.py`)
Enhanced TreeLogger that:
- Extends base TreeLogger (maintains backward compatibility)
- Dual logging: always logs to event log, optionally categorizes with AI
- Auto-placement in decision tree sections
- Atomic writes to prevent corruption
- Handles multiple category assignments
- Graceful degradation without API key

**Architecture**:
```python
class IntelligentLogger(TreeLogger):
    def __init__(self, tree_path: str, enable_ai: bool = True)
    def log_event(self, event: Event)  # Dual logging
    def _intelligent_log(self, event: Event)  # AI categorization
    def _append_to_category(self, category_num: int, entry: str)  # Section placement
```

#### 3. **CLI Integration** (`watcher.py`)
Main entry point updated with:
- `--enable-ai` flag for opt-in AI features
- Logger injection pattern (dependency injection)
- Graceful handling of missing API key
- Status display showing AI mode

**Usage**:
```bash
# Enable AI mode
export ANTHROPIC_API_KEY=sk-ant-...
./watcher.py start --watch-path /workspace --tree-path tree.md --enable-ai

# Basic mode (no AI)
./watcher.py start --watch-path /workspace --tree-path tree.md
```

---

## What Makes This Different

### Traditional File Watchers
```
2025-10-15 14:23:45 - Modified: src/auth.py
2025-10-15 14:24:12 - Modified: requirements.txt
```

**Problem**: No context, no reasoning, no WHY.

### Phase 2 AI Extraction
```markdown
🔹 **Decision: Switch to JWT-based authentication**
   - **What**: Implemented JWT token generation in auth.py
   - **Why**: Moving away from session-based auth to enable stateless API
             authentication for mobile clients
   - **Impact**: Enables horizontal scaling and better mobile app support.
                Will require client changes.
   - **Time**: 14:23:45
   - **Keywords**: authentication, jwt, stateless, mobile, api
```

**Value**: Captures decision-making reasoning, intent, and impact.

---

## Design Principles

1. **WHY-Focused**: Every extraction emphasizes reasoning and intent
2. **Backward Compatible**: Works with or without AI enabled
3. **Graceful Degradation**: Never fails - falls back to basic logging
4. **Atomic Operations**: Corruption-proof file writes
5. **Dual Logging**: Events always logged to event log (safety net)
6. **Context-Aware**: Reads file content for better categorization
7. **Privacy-Conscious**: Only reads first 500 chars, small files only

---

## Technical Architecture

### Logging Flow (AI Enabled)

```
File Change
    ↓
FileSystemWatcher
    ↓
Event Creation
    ↓
IntelligentLogger.log_event()
    ├─→ TreeLogger.log_event()  ← ALWAYS logs to event log
    └─→ _intelligent_log()
         ├─→ Read file context (first 500 chars)
         ├─→ CategoryEngine.categorize_event()
         │    ├─→ Build WHY-focused prompt
         │    ├─→ Call Claude API
         │    └─→ Parse JSON response
         ├─→ CategoryEngine.format_for_tree_section()
         └─→ _append_to_category()  ← Atomic section update
```

### Logging Flow (Basic Mode)

```
File Change
    ↓
FileSystemWatcher
    ↓
Event Creation
    ↓
TreeLogger.log_event()
    └─→ Append to event log
```

---

## Integration Testing

All tests pass (see `test_integration.py`):

```
✓ watcher.__version__ = 2.0.0
✓ watcher.event (Event, EventStore)
✓ watcher.logger (TreeLogger)
✓ watcher.category_engine (CategoryEngine)
✓ watcher.intelligent_logger (IntelligentLogger)

✓ CategoryEngine initialization
✓ 10 categories defined correctly
✓ IntelligentLogger graceful degradation
✓ Event creation and formatting

Results: 4 passed, 0 failed
```

---

## Files Changed (Commit 5713e0b)

1. **watcher.py** (main CLI)
   - Added `--enable-ai` flag
   - Integrated IntelligentLogger
   - Added logger injection pattern
   - Updated startup messages

2. **src/watcher/watcher.py** (FileSystemWatcher)
   - Made logger injectable via constructor
   - Maintained backward compatibility

3. **requirements.txt**
   - Added `anthropic>=0.8.0`

4. **README.md**
   - Added AI-Powered Mode section
   - Documented ANTHROPIC_API_KEY setup
   - Added detailed examples emphasizing WHY extraction
   - Updated daemon mode instructions

5. **src/watcher/category_engine.py** (new)
   - 329 lines of WHY-focused categorization logic

6. **src/watcher/intelligent_logger.py** (new)
   - 198 lines of dual-logging with AI integration

**Stats**: 6 files changed, 575 insertions (+)

---

## User Feedback Addressed

**Original Feedback** (from previous session):
> "and see it from my POV. will the info we're capturing be useful later?
> i need to know which decisions i made, and importantly why!"

**How Phase 2 Addresses This**:

1. **Captures WHY**: Every AI extraction includes explicit "why" field
2. **Extracts Intent**: Prompt asks "What problem is being solved?"
3. **Captures Impact**: Includes implications and significance
4. **Searchable**: Keywords enable finding decisions later
5. **Contextual**: Related files show decision scope
6. **Structured**: Consistent format makes review easy

**Before Phase 2**:
```
- [14:23:45] src/auth.py → code_change #auto #source_code
```

**After Phase 2**:
```
🔹 **Decision: Switch to JWT-based authentication**
   - **What**: Implemented JWT token generation in auth.py
   - **Why**: Moving away from session-based auth to enable stateless
             API authentication for mobile clients
   - **Impact**: Enables horizontal scaling and better mobile app support
   - **Keywords**: authentication, jwt, stateless, mobile, api
```

---

## What's Next (Future Enhancements - Not in Scope)

**Phase 3 Possibilities** (not requested, for reference):
- Batch processing optimization
- Historical event replay with re-categorization
- Custom category definitions
- Multi-model support (OpenAI, local models)
- Visual decision tree graphs
- Search interface for decisions
- Export to timeline format
- Integration with git blame for attribution

---

## How to Use

### Setup
```bash
cd v2-daemon
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### Basic Mode (No AI)
```bash
./watcher.py start \
  --watch-path /path/to/workspace \
  --tree-path decision_tree.md
```

Events logged to event log only.

### AI Mode (Recommended)
```bash
# Set API key
export ANTHROPIC_API_KEY=sk-ant-...

# Start with AI
./watcher.py start \
  --watch-path /path/to/workspace \
  --tree-path decision_tree.md \
  --enable-ai
```

Events logged to:
1. Event log (always)
2. Categorized sections (with WHY extraction)

### Daemon Mode
```bash
./watcher.py start \
  --watch-path /path/to/workspace \
  --tree-path decision_tree.md \
  --enable-ai \
  --daemon
```

Runs in background with PID file management.

---

## Performance Characteristics

**API Calls**: 1 per file event (when AI enabled)
**Latency**: ~500-1500ms per categorization (network dependent)
**Cost**: ~$0.003 per 1K tokens (Claude 3.5 Sonnet pricing)
**Rate Limiting**: Handled by Anthropic SDK
**Fallback**: Instant rule-based categorization if API fails

**Optimization Strategy**: Events processed sequentially to maintain order. Batch processing could be added if needed.

---

## Testing Instructions

### Integration Test
```bash
cd v2-daemon
python3 test_integration.py
```

### Manual Test (Without API Key)
```bash
# Should gracefully degrade
./watcher.py start --watch-path /tmp/test --tree-path tree.md --enable-ai
# Output: "⚠️  AI categorization disabled (no API key)"
```

### Manual Test (With API Key)
```bash
export ANTHROPIC_API_KEY=sk-ant-...
./watcher.py start --watch-path /tmp/test --tree-path tree.md --enable-ai
# Modify a file in /tmp/test
# Check tree.md for categorized entry with WHY
```

---

## Commit History

```
5713e0b - Add AI-powered WHY extraction (Phase 2)
         - Integrated CategoryEngine and IntelligentLogger into main CLI
         - Added --enable-ai flag for opt-in AI features
         - Updated README.md with comprehensive AI mode documentation
         - Added anthropic SDK to requirements.txt
         - Maintained full backward compatibility

fc5c75b - Implement intelligent logger with AI categorization
         - Created CategoryEngine with WHY-focused prompts
         - Created IntelligentLogger with dual logging
         - Added 10-category classification system
         - 4 detailed examples in prompt engineering
```

---

## Conclusion

Phase 2 transforms DecisionTreeTool from a passive file watcher into an **active decision reconstruction system**. The WHY-focused approach directly addresses the core user need: understanding past decisions and their reasoning.

**Key Achievement**: Captures not just WHAT changed, but WHY it changed, enabling effective decision review and learning.

**Status**: Fully integrated, tested, documented, and pushed to GitHub (v2-daemon-watcher branch).

**Ready for**: User testing with real ANTHROPIC_API_KEY and production workflows.

---

Generated: 2025-10-15
Author: Claude (DecisionTreeTool v2 development)
Commit: 5713e0b
