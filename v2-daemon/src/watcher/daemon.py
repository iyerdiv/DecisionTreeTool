"""Daemon process management"""

import os
import sys
import signal
import atexit
from pathlib import Path


class Daemon:
    """Simple daemon process manager with PID file"""

    def __init__(self, pidfile: str):
        self.pidfile = pidfile

    def daemonize(self):
        """Daemonize the current process"""
        # First fork
        try:
            pid = os.fork()
            if pid > 0:
                # Exit parent
                sys.exit(0)
        except OSError as e:
            sys.stderr.write(f"Fork #1 failed: {e}\n")
            sys.exit(1)

        # Decouple from parent environment
        os.chdir('/')
        os.setsid()
        os.umask(0)

        # Second fork
        try:
            pid = os.fork()
            if pid > 0:
                # Exit second parent
                sys.exit(0)
        except OSError as e:
            sys.stderr.write(f"Fork #2 failed: {e}\n")
            sys.exit(1)

        # Redirect standard file descriptors
        sys.stdout.flush()
        sys.stderr.flush()

        # Write PID file
        atexit.register(self.delpid)
        pid = str(os.getpid())
        with open(self.pidfile, 'w+') as f:
            f.write(f"{pid}\n")

    def delpid(self):
        """Delete PID file"""
        if os.path.exists(self.pidfile):
            os.remove(self.pidfile)

    def start(self, func, *args, **kwargs):
        """Start the daemon"""
        # Check for existing PID
        if os.path.exists(self.pidfile):
            with open(self.pidfile, 'r') as f:
                pid = int(f.read().strip())

            # Check if process is running
            try:
                os.kill(pid, 0)
            except OSError:
                # Process not running, remove stale PID file
                os.remove(self.pidfile)
            else:
                print(f"Daemon already running (PID: {pid})")
                sys.exit(1)

        # Daemonize
        self.daemonize()

        # Run the function
        func(*args, **kwargs)

    def stop(self):
        """Stop the daemon"""
        if not os.path.exists(self.pidfile):
            print("Daemon not running")
            return

        # Read PID
        with open(self.pidfile, 'r') as f:
            pid = int(f.read().strip())

        # Kill the process
        try:
            os.kill(pid, signal.SIGTERM)
            print(f"Stopped daemon (PID: {pid})")

            # Wait for process to terminate
            import time
            for _ in range(10):
                try:
                    os.kill(pid, 0)
                    time.sleep(0.1)
                except OSError:
                    break

            # Remove PID file
            if os.path.exists(self.pidfile):
                os.remove(self.pidfile)

        except OSError as e:
            print(f"Error stopping daemon: {e}")
            # Remove stale PID file
            if os.path.exists(self.pidfile):
                os.remove(self.pidfile)

    def status(self):
        """Check daemon status"""
        if not os.path.exists(self.pidfile):
            print("Daemon is not running")
            return False

        with open(self.pidfile, 'r') as f:
            pid = int(f.read().strip())

        try:
            os.kill(pid, 0)
            print(f"Daemon is running (PID: {pid})")
            return True
        except OSError:
            print("Daemon is not running (stale PID file)")
            os.remove(self.pidfile)
            return False
