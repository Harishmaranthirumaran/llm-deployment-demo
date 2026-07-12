# ── Build stage ───────────────────────────────────────────────────────────────
FROM python:3.11-slim AS base

LABEL maintainer="Harishmaran Subbaiah Thirumaran <harishmaran2001@gmail.com>"
LABEL org.opencontainers.image.source="https://github.com/Harishmaranthirumaran/llm-deployment-demo"
LABEL org.opencontainers.image.description="Streamlit frontend for vLLM self-hosted inference"

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application
COPY app.py .

# ── Runtime config ─────────────────────────────────────────────────────────────
ENV VLLM_HOST=http://vllm:8000
ENV MODEL_NAME=mistralai/Mistral-7B-Instruct-v0.2
ENV MAX_TOKENS=512

EXPOSE 8501

HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8501/_stcore/health || exit 1

CMD ["streamlit", "run", "app.py", "--server.port=8501", "--server.address=0.0.0.0"]
