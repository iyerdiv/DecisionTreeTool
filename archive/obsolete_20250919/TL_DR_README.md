# DecisionTreeTool - TL;DR 🌳

*Turn "I have no idea what to do" into structured decisions*

## What It Does
- Creates visual decision trees for systematic problem-solving
- **Works with ANY project** (no hardcoded paths)
- **Integrates with Claude workflows** for systematic analysis
- Exports to multiple formats: JSON, YAML, Mermaid, ASCII, **Markdown**

## Quick Setup
```bash
# One-time project setup
python manage_decision_tree.py set-project myproject
python manage_decision_tree.py set-path myproject "/your/project/path"
```

## Basic Usage
```bash
# Create → Add → Link → Export
python manage_decision_tree.py create --name "My Analysis"
python manage_decision_tree.py add --question "Is the server down?"
python manage_decision_tree.py add --question "Restart server" --type action --action "sudo systemctl restart app"
python manage_decision_tree.py link --parent node1 --child node2 --answer "yes"
python manage_decision_tree.py export --format markdown --project myproject
```

## Claude Integration
Perfect for systematic analysis workflows:
- **Generates structured markdown** with node numbering and systematic evaluation
- **Works with activation scripts** for automated workflow integration
- **Auto-saves to project directories** like `/decision_trees/` and `/claude_prompts/`

## Key Features
- ✅ **Project-agnostic** - works anywhere, no hardcoded paths
- ✅ **Claude workflow ready** - generates systematic decision documentation
- ✅ **Multiple export formats** - ASCII, Mermaid, JSON, YAML, Markdown
- ✅ **Confidence scoring** - track decision quality
- ✅ **Fallback logic** - never hit dead ends

## Common Commands
| Task | Command |
|------|---------|
| Set project | `python manage_decision_tree.py set-project myproject` |
| Create tree | `python manage_decision_tree.py create --name "Analysis"` |
| Add question | `python manage_decision_tree.py add --question "Is it working?"` |
| Add action | `python manage_decision_tree.py add --question "Fix it" --type action --action "restart service"` |
| Link nodes | `python manage_decision_tree.py link --parent node1 --child node2 --answer "yes"` |
| Export | `python manage_decision_tree.py export --format markdown --project myproject` |
| Load saved | `python manage_decision_tree.py load --name "my_tree" --project myproject` |

## Output Example
```markdown
### **Node 56: Database Performance Analysis**
**Timestamp**: 2025-09-12 18:42
**Situation**: Query response time degraded by 300%

#### Options Evaluated:
1. ✅ **Check Connection Pool** - Quick to verify, likely cause
2. ❌ **Rebuild Indexes** - Takes 4 hours, affects production

**Action Taken**: Increased pool size from 10 to 50 connections
**Result**: Response time improved by 250%
**Next Node**: 57 - Monitor for 24 hours
```

## The Bottom Line
**No hardcoded paths. No broken functionality. Just systematic decision-making that works with your existing workflow.**

Your activation scripts? **Still work perfectly.**
Your decision trees? **Auto-exported to the right folders.**
Your systematic approach? **Now enhanced with automated tooling.**

*Because good decisions deserve good tools.* 🚀
