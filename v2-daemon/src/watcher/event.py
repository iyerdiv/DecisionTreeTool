"""Event data structures and ID generation"""

import hashlib
from datetime import datetime
from dataclasses import dataclass, field
from typing import Optional, List


@dataclass
class Event:
    """Represents a file system event"""

    timestamp: datetime
    path: str
    event_type: str  # file_change, prompt_created, tree_update, etc.
    unique_id: str = field(default="")
    tags: List[str] = field(default_factory=list)
    category: Optional[str] = None

    def __post_init__(self):
        """Generate unique ID if not provided"""
        if not self.unique_id:
            self.unique_id = self.generate_unique_id()

    def generate_unique_id(self) -> str:
        """Generate unique ID: YYYYMMDDTHHMMSS-[8-char-hash]"""
        # Time component
        time_str = self.timestamp.strftime("%Y%m%dT%H%M%S")

        # Hash component (path + timestamp + event_type for uniqueness)
        hash_input = f"{self.path}{self.timestamp.isoformat()}{self.event_type}"
        hash_obj = hashlib.sha256(hash_input.encode())
        hash_str = hash_obj.hexdigest()[:8]

        return f"{time_str}-{hash_str}"

    def to_log_entry(self) -> str:
        """Format as OpsBrain log entry"""
        time_only = self.timestamp.strftime("%H:%M:%S")
        tags_str = " ".join(f"#{tag}" for tag in self.tags)

        return f"- [{time_only}] (id:{self.unique_id}) {self.path} → {self.event_type} {tags_str}"

    def to_dict(self) -> dict:
        """Convert to dictionary for storage"""
        return {
            "timestamp": self.timestamp.isoformat(),
            "path": self.path,
            "event_type": self.event_type,
            "unique_id": self.unique_id,
            "tags": self.tags,
            "category": self.category
        }


class EventStore:
    """Manages event storage and retrieval"""

    def __init__(self, storage_path: str):
        self.storage_path = storage_path
        self.events: List[Event] = []

    def add_event(self, event: Event):
        """Add event to store"""
        self.events.append(event)

    def get_events_by_date(self, date: datetime) -> List[Event]:
        """Get all events for a specific date"""
        return [e for e in self.events if e.timestamp.date() == date.date()]

    def get_events_by_category(self, category: str) -> List[Event]:
        """Get all events in a category"""
        return [e for e in self.events if e.category == category]
