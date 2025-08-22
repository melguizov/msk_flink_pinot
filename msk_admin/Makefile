# MSK Admin Makefile

.PHONY: help setup install install-dev lint format test test-cov clean build docker-build docker-run

# Default target
help:
	@echo "MSK Admin - Available commands:"
	@echo ""
	@echo "  setup          - Set up development environment"
	@echo "  install        - Install package in development mode"
	@echo "  install-dev    - Install with development dependencies"
	@echo "  lint           - Run code linting (flake8, mypy)"
	@echo "  format         - Format code (black, isort)"
	@echo "  test           - Run tests"
	@echo "  test-cov       - Run tests with coverage report"
	@echo "  clean          - Clean build artifacts"
	@echo "  build          - Build package"
	@echo "  docker-build   - Build Docker image"
	@echo "  docker-run     - Run Docker container"
	@echo "  cli            - Show CLI help"

# Development setup
setup:
	python3.11 -m venv venv
	@echo "Virtual environment created. Activate with:"
	@echo "  source venv/bin/activate  # Linux/Mac"
	@echo "  venv\\Scripts\\activate     # Windows"

install:
	pip install -e .

install-dev:
	pip install -e ".[dev]"
	pre-commit install

# Code quality
lint:
	flake8 src/ tests/
	mypy src/
	@echo "Linting completed successfully!"

format:
	black src/ tests/
	isort src/ tests/
	@echo "Code formatting completed!"

# Testing
test:
	pytest

test-cov:
	pytest --cov=src/msk_admin --cov-report=term-missing --cov-report=html
	@echo "Coverage report generated in htmlcov/"

# Build and packaging
clean:
	rm -rf build/
	rm -rf dist/
	rm -rf *.egg-info/
	rm -rf .pytest_cache/
	rm -rf htmlcov/
	find . -type d -name __pycache__ -delete
	find . -type f -name "*.pyc" -delete

build: clean
	python -m build

# Docker
docker-build:
	docker build -t msk-admin:latest .

docker-run:
	docker run --rm -it \
		-v $(PWD)/.env:/app/.env \
		-v $(PWD)/schemas:/app/schemas \
		msk-admin:latest

# CLI shortcuts
cli:
	msk-admin --help

topics:
	msk-admin topics --help

schema:
	msk-admin schema --help

# Development shortcuts
dev-setup: setup install-dev
	@echo "Development environment ready!"
	@echo "Don't forget to:"
	@echo "  1. Copy .env.example to .env and configure"
	@echo "  2. Activate virtual environment: source venv/bin/activate"

check: lint test
	@echo "All checks passed!"
