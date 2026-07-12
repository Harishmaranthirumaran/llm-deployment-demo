"""
LLM Chat Interface — Streamlit frontend for vLLM inference server.

Author: Harishmaran Subbaiah Thirumaran
GitHub: github.com/Harishmaranthirumaran
"""

import os
import streamlit as st
import requests

# ── Config ────────────────────────────────────────────────────────────────────
VLLM_HOST = os.getenv("VLLM_HOST", "http://localhost:8000")
MODEL_NAME = os.getenv("MODEL_NAME", "mistralai/Mistral-7B-Instruct-v0.2")
MAX_TOKENS = int(os.getenv("MAX_TOKENS", "512"))

st.set_page_config(
    page_title="Self-Hosted LLM Chat",
    page_icon="🤖",
    layout="centered",
)

# ── Session state ─────────────────────────────────────────────────────────────
if "messages" not in st.session_state:
    st.session_state.messages = []

# ── Header ────────────────────────────────────────────────────────────────────
st.title("🤖 Self-Hosted LLM Chat")
st.caption(f"Model: `{MODEL_NAME}` · Endpoint: `{VLLM_HOST}`")

# ── Health check ──────────────────────────────────────────────────────────────
with st.sidebar:
    st.header("Server Status")
    try:
        r = requests.get(f"{VLLM_HOST}/health", timeout=3)
        if r.status_code == 200:
            st.success("✅ vLLM server online")
        else:
            st.warning(f"⚠️ Server returned {r.status_code}")
    except requests.exceptions.ConnectionError:
        st.error("❌ Cannot reach vLLM server")

    st.divider()
    st.header("Settings")
    max_tokens = st.slider("Max tokens", 64, 2048, MAX_TOKENS, step=64)
    temperature = st.slider("Temperature", 0.0, 1.5, 0.7, step=0.05)

    if st.button("Clear conversation"):
        st.session_state.messages = []
        st.rerun()

# ── Chat history ──────────────────────────────────────────────────────────────
for msg in st.session_state.messages:
    with st.chat_message(msg["role"]):
        st.markdown(msg["content"])

# ── Input ─────────────────────────────────────────────────────────────────────
if prompt := st.chat_input("Ask anything..."):
    st.session_state.messages.append({"role": "user", "content": prompt})
    with st.chat_message("user"):
        st.markdown(prompt)

    with st.chat_message("assistant"):
        with st.spinner("Generating..."):
            try:
                payload = {
                    "model": MODEL_NAME,
                    "messages": st.session_state.messages,
                    "max_tokens": max_tokens,
                    "temperature": temperature,
                    "stream": False,
                }
                response = requests.post(
                    f"{VLLM_HOST}/v1/chat/completions",
                    json=payload,
                    timeout=120,
                )
                response.raise_for_status()
                answer = response.json()["choices"][0]["message"]["content"]
                st.markdown(answer)
                st.session_state.messages.append(
                    {"role": "assistant", "content": answer}
                )
            except requests.exceptions.ConnectionError:
                st.error("Could not connect to the vLLM server. Is it running?")
            except Exception as exc:
                st.error(f"Error: {exc}")
