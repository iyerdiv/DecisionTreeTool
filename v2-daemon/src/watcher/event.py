"""Event data structures and ID generation"""

import hashlib
import json
from collections import deque
from datetime import datetime
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional, List, Deque


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
    """Manages event storage and retrieval with hybrid memory + disk caching"""

    def __init__(self, storage_path: str, max_memory_events: int = 500):
        self.storage_path = storage_path
        self.max_memory_events = max_memory_events

        # Memory cache: bounded circular buffer
        self.events: Deque[Event] = deque(maxlen=max_memory_events)

        # Disk persistence paths
        self.cache_dir = self._get_cache_dir()
        self.cache_dir.mkdir(parents=True, exist_ok=True)

        # Current day's event log
        self.current_log = self._get_current_log_path()

        # Load recent events into memory if log exists
        self._load_recent_events()

    def _get_cache_dir(self) -> Path:
        """Get cache directory path"""
        tree_path = Path(self.storage_path)
        workspace_root = tree_path.parent.parent.parent  # Go up from daily_trees/YYYY/file.md
        year = datetime.now().strftime("%Y")
        return workspace_root / ".opsbrain_cache" / year

    def _get_current_log_path(self) -> Path:
        """Get today's event log path"""
        today = datetime.now().strftime("%Y%m%d")
        return self.cache_dir / f"events_{today}.jsonl"

    def _load_recent_events(self):
        """Load recent events from disk into memory on startup"""
        if not self.current_log.exists():
            return

        try:
            with open(self.current_log, 'r') as f:
                # Load last N events into memory
                lines = f.readlines()
                recent_lines = lines[-self.max_memory_events:] if len(lines) > self.max_memory_events else lines

                for line in recent_lines:
                    event_dict = json.loads(line.strip())
                    event = Event(
                        timestamp=datetime.fromisoformat(event_dict['timestamp']),
                        path=event_dict['path'],
                        event_type=event_dict['event_type'],
                        unique_id=event_dict['unique_id'],
                        tags=event_dict['tags'],
                        category=event_dict.get('category')
                    )
                    self.events.append(event)
        except Exception as e:
            print(f"Warning: Could not load events from cache: {e}")

    def add_event(self, event: Event):
        """Add event to store (memory + disk)"""
        # 1. Persist to disk immediately (no data loss)
        try:
            with open(self.current_log, 'a') as f:
                f.write(json.dumps(event.to_dict()) + '\n')
        except Exception as e:
            print(f"Error persisting event to disk: {e}")

        # 2. Add to memory cache (bounded)
        self.events.append(event)

    def get_events_by_date(self, date: datetime) -> List[Event]:
        """Get all events for a specific date (from memory cache)"""
        return [e for e in self.events if e.timestamp.date() == date.date()]

    def get_events_by_category(self, category: str) -> List[Event]:
        """Get all events in a category (from memory cache)"""
        return [e for e in self.events if e.category == category]

    def get_all_events_from_disk(self, date: Optional[datetime] = None) -> List[Event]:
        """Load all events from disk for a specific date (slow, use sparingly)"""
        if date:
            log_path = self.cache_dir / f"events_{date.strftime('%Y%m%d')}.jsonl"
        else:
            log_path = self.current_log

        if not log_path.exists():
            return []

        events = []
        try:
            with open(log_path, 'r') as f:
                for line in f:
                    event_dict = json.loads(line.strip())
                    event = Event(
                        timestamp=datetime.fromisoformat(event_dict['timestamp']),
                        path=event_dict['path'],
                        event_type=event_dict['event_type'],
                        unique_id=event_dict['unique_id'],
                        tags=event_dict['tags'],
                        category=event_dict.get('category')
                    )
                    events.append(event)
        except Exception as e:
            print(f"Error loading events from disk: {e}")

        return events
