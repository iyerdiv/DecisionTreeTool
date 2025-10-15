"""IntelligentLogger - AI-powered decision tree logging with auto-categorization"""

import os
import re
from typing import Optional, Dict
from .event import Event
from .logger import TreeLogger
from .category_engine import CategoryEngine


class IntelligentLogger(TreeLogger):
    """
    Enhanced TreeLogger with AI-powered categorization and auto-placement.

    Extends TreeLogger to:
    1. Automatically categorize events using CategoryEngine
    2. Place events in appropriate decision tree sections
    3. Update both event log AND category sections
    """

    def __init__(self, tree_path: str, enable_ai: bool = True):
        """
        Initialize IntelligentLogger.

        Args:
            tree_path: Path to decision tree markdown file
            enable_ai: Enable AI categorization (requires ANTHROPIC_API_KEY)
        """
        super().__init__(tree_path)
        self.category_engine = CategoryEngine() if enable_ai else None
        self.ai_enabled = enable_ai and self.category_engine and self.category_engine.enabled

        if not self.ai_enabled and enable_ai:
            print("⚠️  IntelligentLogger: AI categorization disabled (no API key)")
            print("   Events will be logged to Event Log only")

    def log_event(self, event: Event):
        """
        Log event with AI categorization and auto-placement.

        Args:
            event: Event to log
        """
        # Always log to event log (base behavior)
        super().log_event(event)

        # If AI enabled, also categorize and place in sections
        if self.ai_enabled:
            try:
                self._intelligent_log(event)
            except Exception as e:
                print(f"⚠️  AI categorization failed: {e}")
                # Event still logged to event log via super().log_event()

    def _intelligent_log(self, event: Event):
        """Perform AI categorization and place in tree section"""

        # Get file content for context if available
        context = self._get_event_context(event)

        # Categorize using AI
        categorization = self.category_engine.categorize_event(event, context)

        # Format for tree section
        entry = self.category_engine.format_for_tree_section(event, categorization)

        # Place in primary category section
        primary_category = categorization['category']
        self._append_to_category(primary_category, entry)

        # Also add to additional categories if applicable
        for cat_num in categorization['categories']:
            if cat_num != primary_category:
                self._append_to_category(cat_num, entry)

    def _get_event_context(self, event: Event) -> Optional[str]:
        """
        Get file content context for better categorization.

        Args:
            event: Event to get context for

        Returns:
            File content (first 500 chars) or None
        """
        try:
            # Only read small text files
            if os.path.isfile(event.path) and os.path.getsize(event.path) < 100000:
                # Check if it's a text file
                if event.path.endswith(('.py', '.js', '.java', '.md', '.txt', '.yaml', '.json', '.xml')):
                    with open(event.path, 'r', encoding='utf-8', errors='ignore') as f:
                        return f.read(500)
        except Exception:
            pass

        return None

    def _append_to_category(self, category_num: int, entry: str):
        """
        Append entry to specific category section in decision tree.

        Args:
            category_num: Category number (1-10)
            entry: Formatted markdown entry
        """
        category_name = CategoryEngine.CATEGORIES.get(category_num, "Unknown")
        section_header = f"### "

        # Find the header pattern for this category
        # e.g., "### ✅ 1. Decisions Made"
        pattern = re.escape(f"{category_num}. {category_name}")

        temp_path = f"{self.tree_path}.tmp"

        try:
            with open(self.tree_path, 'r') as f:
                content = f.read()

            # Find category section
            match = re.search(f"{section_header}[^#]*{pattern}", content)
            if not match:
                print(f"⚠️  Category section not found: {category_num}. {category_name}")
                return

            section_start = match.end()

            # Find where this section ends (next ### or next ##)
            next_section = re.search(r'\n###? ', content[section_start:])
            if next_section:
                section_end = section_start + next_section.start()
            else:
                section_end = len(content)

            # Extract section content
            section_content = content[section_start:section_end]

            # Remove placeholder if present
            section_content = re.sub(r'\*Placeholder[^\n]*\*\n?', '', section_content)
            section_content = re.sub(r'\*Auto-extracted[^\n]*\*\n?', '', section_content)

            # Add entry (with proper spacing)
            if not section_content.strip():
                new_section = f"\n\n{entry}\n"
            else:
                new_section = section_content.rstrip() + f"\n\n{entry}\n"

            # Reconstruct content
            new_content = (
                content[:section_start] +
                new_section +
                content[section_end:]
            )

            # Atomic write
            with open(temp_path, 'w') as f:
                f.write(new_content)

            os.replace(temp_path, self.tree_path)

        except Exception as e:
            if os.path.exists(temp_path):
                os.remove(temp_path)
            raise e

    def categorize_and_format(self, event: Event) -> Dict:
        """
        Categorize event and return formatted entry (for testing/preview).

        Args:
            event: Event to categorize

        Returns:
            Dict with categorization and formatted entry
        """
        if not self.ai_enabled:
            return {
                "categorization": None,
                "entry": None,
                "error": "AI categorization not enabled"
            }

        try:
            context = self._get_event_context(event)
            categorization = self.category_engine.categorize_event(event, context)
            entry = self.category_engine.format_for_tree_section(event, categorization)

            return {
                "categorization": categorization,
                "entry": entry,
                "error": None
            }
        except Exception as e:
            return {
                "categorization": None,
                "entry": None,
                "error": str(e)
            }
