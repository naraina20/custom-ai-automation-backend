FROM python:3.13-slim

# Prevent Python from writing .pyc files and enable unbuffered output for real-time logging
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/app/.venv/bin:$PATH"

# Install essential system dependencies:
# - curl: required for Docker container HEALTHCHECK
# - libpq5: runtime library for PostgreSQL (psycopg2-binary)
# - tesseract-ocr & tesseract-ocr-eng: required for document OCR processing (pytesseract)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    libpq5 \
    tesseract-ocr \
    tesseract-ocr-eng \
    && rm -rf /var/lib/apt/lists/*

# Install uv package manager from the official Astral image
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# Set working directory inside container
WORKDIR /app

# Copy dependency specifications first to maximize Docker layer cache hits
COPY pyproject.toml uv.lock README.md ./

# Install locked dependencies into /app/.venv (cached by Docker layer)
RUN uv sync --frozen --no-dev --no-install-project

# Copy the rest of the application source code
COPY . .

# Create and switch to a non-privileged user for security
RUN useradd --create-home --shell /bin/bash appuser && \
    chown -R appuser:appuser /app

USER appuser

# Expose Daphne ASGI server port
EXPOSE 8000

# Docker Healthcheck targeting the newly created /health/ endpoint
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8000/health/ || exit 1

# Start Daphne ASGI server (handles both HTTP REST APIs and Channels WebSockets)
CMD ["daphne", "-b", "0.0.0.0", "-p", "8000", "core.asgi:application"]

