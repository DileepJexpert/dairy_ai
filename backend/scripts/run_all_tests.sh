#!/bin/bash
echo "Running DairyAI Backend Tests..."
echo "================================"
cd "$(dirname "$0")/.."
python -m pytest tests/ -v --tb=short
echo ""
echo "================================"
echo "Test run complete!"
