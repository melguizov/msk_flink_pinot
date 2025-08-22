# Multi-stage build for MSK Admin
FROM python:3.11-slim as builder

# Set build arguments
ARG DEBIAN_FRONTEND=noninteractive

# Install build dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    libffi-dev \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Create build directory
WORKDIR /build

# Copy requirements
COPY pyproject.toml .
COPY src/ src/

# Install package and dependencies
RUN pip install --no-cache-dir --upgrade pip wheel && \
    pip install --no-cache-dir .

# Production stage
FROM python:3.11-slim

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

# Install runtime dependencies and CA certificates
RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    && rm -rf /var/lib/apt/lists/* \
    && update-ca-certificates

# Create non-root user
RUN groupadd -r mskadmin && useradd -r -g mskadmin -d /app -s /bin/bash mskadmin

# Set working directory
WORKDIR /app

# Copy installed packages from builder
COPY --from=builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY --from=builder /usr/local/bin/msk-admin /usr/local/bin/

# Copy application files
COPY src/ src/
COPY schemas/ schemas/
COPY .env.example .env.example

# Create directories for configuration and logs
RUN mkdir -p /app/config /app/logs && \
    chown -R mskadmin:mskadmin /app

# Switch to non-root user
USER mskadmin

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD msk-admin health || exit 1

# Default command
ENTRYPOINT ["msk-admin"]
CMD ["--help"]

# Labels
LABEL maintainer="MSK Admin Team"
LABEL version="0.1.0"
LABEL description="Production-grade Python tool for managing Amazon MSK (Kafka) control-plane tasks"
