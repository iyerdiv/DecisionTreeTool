"""Simple chat content extraction from prompt files"""

from pathlib import Path
from typing import Optional, Dict


class ChatExtractor:
    """Extract key information from Claude prompt/chat files"""

    def extract_from_file(self, file_path: str) -> Optional[Dict[str, str]]:
        """
        Extract last user message and assistant response from prompt file.
        Returns dict with 'user_message' and 'assistant_response' or None if not a chat file.
        """
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()

            # Only process if it looks like a chat/prompt file
            if not self._is_chat_file(content):
                return None

            # Extract last exchange
            user_msg = self._extract_last_user_message(content)
            assistant_msg = self._extract_last_assistant_message(content)

            if not user_msg:
                return None

            return {
                'user_message': user_msg,
                'assistant_response': assistant_msg or "(no response yet)"
            }

        except Exception as e:
            print(f"⚠️  Error extracting from {file_path}: {e}")
            return None

    def _is_chat_file(self, content: str) -> bool:
        """Check if file looks like a chat/prompt"""
        indicators = ['Human:', 'Assistant:', 'User:', 'Claude:', '## Human', '## Assistant']
        return any(ind in content for ind in indicators)

    def _extract_last_user_message(self, content: str) -> Optional[str]:
        """Extract the last user message"""
        # Try different user message patterns
        patterns = ['Human:', 'User:', '## Human', '## User']

        last_position = -1
        last_pattern = None

        for pattern in patterns:
            pos = content.rfind(pattern)
            if pos > last_position:
                last_position = pos
                last_pattern = pattern

        if last_position == -1:
            return None

        # Extract from pattern to next section or end
        start = last_position + len(last_pattern)

        # Find where assistant response starts (if any)
        assistant_patterns = ['Assistant:', 'Claude:', '## Assistant', '## Claude']
        end_position = len(content)

        for ap in assistant_patterns:
            pos = content.find(ap, start)
            if pos != -1 and pos < end_position:
                end_position = pos

        message = content[start:end_position].strip()

        # Truncate if too long (keep first 200 chars)
        if len(message) > 200:
            message = message[:200] + "..."

        return message

    def _extract_last_assistant_message(self, content: str) -> Optional[str]:
        """Extract the last assistant message"""
        patterns = ['Assistant:', 'Claude:', '## Assistant', '## Claude']

        last_position = -1
        last_pattern = None

        for pattern in patterns:
            pos = content.rfind(pattern)
            if pos > last_position:
                last_position = pos
                last_pattern = pattern

        if last_position == -1:
            return None

        # Extract from pattern to end
        start = last_position + len(last_pattern)
        message = content[start:].strip()

        # Truncate if too long (keep first 200 chars)
        if len(message) > 200:
            message = message[:200] + "..."

        return message

    def format_for_tree(self, extraction: Dict[str, str]) -> str:
        """Format extracted chat as tree entry"""
        user = extraction['user_message']
        assistant = extraction['assistant_response']

        # Create compact single-line format
        return f"💬 Q: {user} | A: {assistant}"
