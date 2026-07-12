# Self-Hosted LLM Deployment Demo

[![Python](https://img.shields.io/badge/Python-3776AB?style=flat-square&logo=python&logoColor=white)](https://python.org)
[![Streamlit](https://img.shields.io/badge/Streamlit-FF4B4B?style=flat-square&logo=streamlit&logoColor=white)](https://streamlit.io)
[![Docker](https://img.shields.io/badge/Docker-2496ED?style=flat-square&logo=docker&logoColor=white)](https://docker.com)
[![AWS](https://img.shields.io/badge/AWS-232F3E?style=flat-square&logo=amazonaws&logoColor=white)](https://aws.amazon.com)

A production-ready self-hosted LLM stack — vLLM inference server fronted by a Streamlit chat UI, containerised with Docker Compose and deployable to AWS EC2 with a single script.

## Architecture

```
User Browser
     │
     ▼
┌─────────────────┐
│  Streamlit UI   │  :8501
│  (app.py)       │
└────────┬────────┘
         │  OpenAI-compatible API
         ▼
┌─────────────────┐
│  vLLM Server    │  :8000
│  (inference)    │
└────────┬────────┘
         │
┌─────────────────┐
│  Model Weights  │
│  (HuggingFace)  │
└─────────────────┘
```

## Quick Start

### Option A — GPU (recommended)

```bash
git clone https://github.com/Harishmaranthirumaran/llm-deployment-demo.git
cd llm-deployment-demo
cp .env.example .env
# Add your HuggingFace token to .env
docker compose --profile gpu up --build
```

Open **http://localhost:8501**

### Option B — CPU (small models)

```bash
docker compose --profile cpu up --build
```

Uses `facebook/opt-125m` by default — no GPU or HF token required.

## Deploy to AWS EC2

```bash
export HF_TOKEN=your_token_here
./scripts/deploy-ec2.sh g4dn.xlarge eu-west-1
```

Recommended instances:

| Instance | GPU | VRAM | Cost/hr | Best for |
|----------|-----|------|---------|----------|
| g4dn.xlarge | T4 | 16 GB | ~$0.53 | Mistral 7B, Llama 7B |
| g5.xlarge | A10G | 24 GB | ~$1.01 | Mistral 7B, Llama 13B |
| c5.2xlarge | — | — | ~$0.34 | Small models (opt-125m) |

## Supported Models

Any model compatible with vLLM and HuggingFace:

```bash
# Edit docker-compose.yml — change MODEL_NAME
MODEL_NAME=mistralai/Mistral-7B-Instruct-v0.2   # default
MODEL_NAME=meta-llama/Llama-2-7b-chat-hf
MODEL_NAME=facebook/opt-1.3b
MODEL_NAME=google/gemma-2b-it
```

## Project Structure

```
llm-deployment-demo/
├── app.py                 # Streamlit chat interface
├── Dockerfile             # Container for the UI
├── docker-compose.yml     # Full stack (GPU + CPU profiles)
├── requirements.txt       # Python dependencies
├── .env.example           # Environment variable template
└── scripts/
    └── deploy-ec2.sh      # One-command AWS EC2 deployment
```

## Author

**Harishmaran Subbaiah Thirumaran** — DevOps & Platform Engineer, Amsterdam

[linkedin.com/in/harishmaran](https://linkedin.com/in/harishmaran) · [harryportfolio-gamma.vercel.app](https://harryportfolio-gamma.vercel.app)
