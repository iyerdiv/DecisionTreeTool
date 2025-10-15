"""CategoryEngine - AI-powered event categorization for decision trees"""

import os
import json
from typing import Dict, List, Optional
from datetime import datetime
from .event import Event


class CategoryEngine:
    """
    AI-powered engine that extracts semantic meaning from file system events
    and categorizes them into decision tree sections.

    Categories:
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
    """

    CATEGORIES = {
        1: "Decisions Made",
        2: "Actions Taken",
        3: "Files Created/Modified",
        4: "Issues Encountered",
        5: "Insights & Learnings",
        6: "Dependencies & Requirements",
        7: "TODO Items Generated",
        8: "Questions & Answers",
        9: "Testing & Validation",
        10: "Debugging Steps"
    }

    def __init__(self, api_key: Optional[str] = None, model: str = "claude-3-5-sonnet-20241022"):
        """
        Initialize CategoryEngine with optional AI provider.

        Args:
            api_key: API key for LLM provider (defaults to ANTHROPIC_API_KEY env var)
            model: Model to use for categorization
        """
        self.api_key = api_key or os.getenv('ANTHROPIC_API_KEY')
        self.model = model
        self.enabled = bool(self.api_key)

        if not self.enabled:
            print("⚠️  CategoryEngine: No API key found. AI extraction disabled.")
            print("   Set ANTHROPIC_API_KEY to enable intelligent categorization.")

    def categorize_event(self, event: Event, context: Optional[str] = None) -> Dict:
        """
        Categorize an event using AI analysis.

        Args:
            event: The event to categorize
            context: Optional file content or additional context

        Returns:
            Dict with:
            - category: Primary category (1-10)
            - categories: All applicable categories
            - extracted_info: Structured extraction
            - confidence: Confidence score (0.0-1.0)
        """
        if not self.enabled:
            return self._fallback_categorization(event)

        try:
            return self._ai_categorize(event, context)
        except Exception as e:
            print(f"⚠️  CategoryEngine error: {e}")
            return self._fallback_categorization(event)

    def _ai_categorize(self, event: Event, context: Optional[str]) -> Dict:
        """Use LLM to intelligently categorize the event"""
        import anthropic

        client = anthropic.Anthropic(api_key=self.api_key)

        prompt = self._build_categorization_prompt(event, context)

        response = client.messages.create(
            model=self.model,
            max_tokens=1024,
            temperature=0.0,
            messages=[{
                "role": "user",
                "content": prompt
            }]
        )

        # Parse response
        result = json.loads(response.content[0].text)
        return result

    def _build_categorization_prompt(self, event: Event, context: Optional[str]) -> str:
        """Build the LLM prompt for categorization"""

        categories_text = "\n".join([f"{k}. {v}" for k, v in self.CATEGORIES.items()])

        context_section = ""
        if context:
            context_section = f"\n\n**File Content Preview:**\n```\n{context[:500]}\n```"

        return f"""You are analyzing file system events to help a developer reconstruct their decision-making process.

**CRITICAL: The developer needs to know WHY decisions were made, not just WHAT changed.**

Your job: Extract the underlying intent, reasoning, and decision-making context from this event.

**Event Details:**
- Path: {event.path}
- Type: {event.event_type}
- Timestamp: {event.timestamp.isoformat()}
- Tags: {', '.join(event.tags)}
{context_section}

**Categories (select all that apply):**
{categories_text}

**Instructions:**
1. **Infer the WHY**: What decision or reasoning led to this change?
2. **Extract intent**: What problem is being solved? What goal is being pursued?
3. **Capture context**: What makes this change significant?
4. **Identify relationships**: How does this relate to other work?

**Response Format (JSON only):**
{{
  "category": <primary_category_number>,
  "categories": [<list_of_applicable_category_numbers>],
  "extracted_info": {{
    "title": "<concise title of the decision/action>",
    "what": "<what specifically changed>",
    "why": "<inferred reasoning - WHY this change was made>",
    "impact": "<significance and implications>",
    "related_files": ["<files that provide context>"],
    "keywords": ["<searchable terms>"]
  }},
  "confidence": <0.0-1.0>
}}

**Examples:**

Event: src/api/auth.py → code_change (with context showing JWT token implementation)
Response:
{{
  "category": 1,
  "categories": [1, 2, 3],
  "extracted_info": {{
    "title": "Decision: Switch to JWT-based authentication",
    "what": "Implemented JWT token generation in auth.py",
    "why": "Moving away from session-based auth to enable stateless API authentication for mobile clients",
    "impact": "Enables horizontal scaling and better mobile app support. Will require client changes.",
    "related_files": ["src/api/auth.py", "src/middleware/session.py"],
    "keywords": ["authentication", "jwt", "stateless", "mobile", "api"]
  }},
  "confidence": 0.92
}}

Event: requirements.txt → file_change (added 'pytest-cov')
Response:
{{
  "category": 1,
  "categories": [1, 6, 9],
  "extracted_info": {{
    "title": "Decision: Add test coverage tracking",
    "what": "Added pytest-cov to requirements.txt",
    "why": "Need visibility into test coverage to identify untested code paths before production deployment",
    "impact": "Enables automated coverage reports in CI/CD. May reveal gaps in existing test suite.",
    "related_files": ["requirements.txt", "tests/"],
    "keywords": ["testing", "coverage", "quality", "ci-cd"]
  }},
  "confidence": 0.88
}}

Event: docs/RCA_database_outage.md → doc_change
Response:
{{
  "category": 10,
  "categories": [4, 5, 10],
  "extracted_info": {{
    "title": "Root cause analysis: Database connection pool exhaustion",
    "what": "Documented RCA for production database outage",
    "why": "Connection pool size (10) insufficient for traffic spike. Need to capture learnings to prevent recurrence.",
    "impact": "Identified architectural weakness. Action items: increase pool size, add monitoring, implement circuit breaker.",
    "related_files": ["docs/RCA_database_outage.md", "src/config/database.py"],
    "keywords": ["rca", "outage", "database", "connection-pool", "production"]
  }},
  "confidence": 0.95
}}

Event: src/utils/retry.py → code_change (new file with retry logic)
Response:
{{
  "category": 2,
  "categories": [2, 3, 5],
  "extracted_info": {{
    "title": "Action: Implement retry mechanism for API calls",
    "what": "Created retry.py with exponential backoff logic",
    "why": "External API calls failing intermittently. Need resilience pattern to handle transient failures gracefully.",
    "impact": "Improves reliability of external integrations. Learned: need retry budgets to prevent cascading failures.",
    "related_files": ["src/utils/retry.py", "src/api/external_client.py"],
    "keywords": ["resilience", "retry", "exponential-backoff", "api", "reliability"]
  }},
  "confidence": 0.90
}}

Now analyze the event above and respond with JSON only. Focus on extracting WHY."""

    def _fallback_categorization(self, event: Event) -> Dict:
        """Rule-based fallback when AI is unavailable"""

        # Simple heuristics
        path_lower = event.path.lower()

        # Category 3: Files Created/Modified (default for most)
        category = 3
        categories = [3]

        # Category 9: Testing
        if 'test' in path_lower or '/tests/' in path_lower:
            category = 9
            categories = [9, 3]

        # Category 10: Debugging
        elif 'debug' in path_lower or 'fix' in path_lower:
            category = 10
            categories = [10, 3]

        # Category 6: Dependencies
        elif any(dep in path_lower for dep in ['requirements.txt', 'package.json', 'pom.xml', 'build.gradle']):
            category = 6
            categories = [6, 3]

        # Category 5: Documentation/Insights
        elif path_lower.endswith('.md') and 'readme' not in path_lower:
            category = 5
            categories = [5, 3]

        # Category 7: TODO
        elif 'todo' in path_lower:
            category = 7
            categories = [7, 3]

        return {
            "category": category,
            "categories": categories,
            "extracted_info": {
                "title": f"{event.event_type}: {os.path.basename(event.path)}",
                "description": f"File {event.event_type} detected",
                "context": "Automatic rule-based categorization",
                "related_files": [event.path]
            },
            "confidence": 0.6
        }

    def format_for_tree_section(self, event: Event, categorization: Dict) -> str:
        """
        Format categorized event for insertion into decision tree section.

        Args:
            event: The original event
            categorization: Result from categorize_event()

        Returns:
            Formatted markdown entry with WHY emphasis
        """
        info = categorization['extracted_info']
        confidence_indicator = "🔹" if categorization['confidence'] > 0.8 else "🔸"

        entry = f"{confidence_indicator} **{info['title']}**\n"

        # What changed
        entry += f"   - **What**: {info.get('what', info.get('description', 'File modified'))}\n"

        # WHY (most important!)
        if info.get('why'):
            entry += f"   - **Why**: {info['why']}\n"

        # Impact/significance
        if info.get('impact'):
            entry += f"   - **Impact**: {info['impact']}\n"

        # Metadata
        entry += f"   - **Time**: {event.timestamp.strftime('%H:%M:%S')}\n"
        entry += f"   - **ID**: `{event.unique_id}`\n"

        # Related files
        if len(info.get('related_files', [])) > 1:
            entry += f"   - **Related**: {', '.join(info['related_files'])}\n"

        # Keywords for searchability
        if info.get('keywords'):
            entry += f"   - **Keywords**: {', '.join(info['keywords'])}\n"

        return entry

    def batch_categorize(self, events: List[Event], context_provider=None) -> List[Dict]:
        """
        Categorize multiple events efficiently.

        Args:
            events: List of events to categorize
            context_provider: Optional function(event) -> context string

        Returns:
            List of categorization results
        """
        results = []
        for event in events:
            context = None
            if context_provider:
                try:
                    context = context_provider(event)
                except Exception:
                    pass

            result = self.categorize_event(event, context)
            results.append(result)

        return results
