#!/usr/bin/env python3
"""Compatibility entry point; prefer backend/sketch_to_narrative/run.py."""

import sys
from sketch_to_narrative.run import main

if __name__ == "__main__":
    sys.exit(main())
