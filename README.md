# BodhixTech Backend — Agent Workflow & Custom Tools Engine

The backend service for **BodhixTech**, powering custom AI tool definitions, LangGraph multi-step agent reasoning, asynchronous webhook ingestion, Human-in-the-Loop (HITL) gatekeeping, and real-time WebSocket communications.

---

## 🛠️ Tech Stack & Key Technologies

- **Runtime & Language**: Python 3.12+
- **Package & Environment Manager**: [uv](https://github.com/astral-sh/uv) (supports standard `pyproject.toml` and `uv.lock`)
- **Web & ASGI Framework**: Django 6 + Django REST Framework (DRF) + Daphne + Django Channels
- **Database**: PostgreSQL (Supabase pooler connection via `psycopg2-binary`) or local SQLite fallback
- **Agent Orchestration**: [LangGraph](https://github.com/langchain-ai/langgraph) state machine with database checkpointing
- **LLM Integrations**: Google Generative AI (Gemini), Groq API, LangChain
- **Document Processing & OCR**: `pypdf`, `python-docx`, `openpyxl`, `pillow`, `pytesseract`

---

## 📂 Architecture & Directory Structure

```text
backend/
├── core/
│   ├── asgi.py             # ASGI entrypoint routing HTTP and WebSockets via Daphne
│   ├── settings.py         # Django settings, database configuration & third-party integrations
│   ├── urls.py             # Root URL routing
│   └── wsgi.py             # WSGI fallback entrypoint
│
├── tools/                  # Main AI Tool builder and execution engine
│   ├── models.py           # CustomTool, UserToolDeployment, WebhookEventJob, etc.
│   ├── views.py            # Custom tool CRUD and direct test endpoints
│   ├── views_agent.py      # LangGraph agent execution & HITL approval endpoints
│   ├── views_webhooks.py   # Inbound webhook ingestion & fast queuing
│   ├── views_oauth.py      # Google OAuth2 authorization flows
│   ├── views_sheets.py     # Google Sheets schema discovery & execution
│   ├── consumers.py        # WebSocket consumers for real-time notifications & agent updates
│   ├── urls.py             # API routes under /api/tools/
│   └── services/
│       ├── graph_engine.py         # LangGraph 4-node agent workflow state machine
│       ├── task_extractor.py       # LLM prompt analyzer extracting structured workflow tasks
│       ├── llm_router.py           # Dynamic routing to optimal LLM provider (Groq / Gemini)
│       ├── general_tools.py        # Execution handlers (Email, Webhooks, Google Docs/Sheets)
│       ├── google_executor.py      # Authenticated Google API execution engine
│       ├── sheets_service.py       # Google Sheets data read/write integration
│       ├── webhook_queue.py        # Background asynchronous webhook worker & job tracker
│       ├── notification_service.py # WebSocket & email alerts for HITL reviews and completions
│       └── app_logger.py           # Centralized structured logger & CriticalErrorLog persistence
│
├── tax_chat/               # Tax calculation & multi-format document analysis chat
│   ├── consumers.py        # WebSocket chat consumer for streaming responses
│   ├── models.py           # Chat sessions & uploaded document tracking
│   ├── views.py            # Tax chat queries and document parsing (PDF, DOCX, XLSX, OCR)
│   └── urls.py             # Chat routes under /tax-chat/
│
├── templates/              # HTML email templates (HITL review alerts, task notifications)
├── manage.py               # Django CLI management script
├── pyproject.toml          # Project metadata & dependency definitions
├── uv.lock                 # Deterministic dependency lockfile
└── .env                    # Environment variables (ignored by Git)
```

---

## ⚡ LangGraph Agent Engine

The core execution engine (`tools/services/graph_engine.py`) models tool execution as a 4-node directed graph:

1. **`tool_selector`**: Analyzes the input context and identifies the appropriate sub-tools required.
2. **`tool_planner`**: Formulates a validated, schema-compliant JSON execution plan.
3. **`hitl_gatekeeper`**: Intercepts sensitive or destructive actions (such as emails or database writes), checkpoints the graph state into the database (`LangGraphCheckpointModel`), and notifies the user via WebSocket and email.
4. **`tool_executor`**: Sequentially executes verified steps, handles errors gracefully, and stores logs.

---

## 📬 Webhook Ingestion Engine

- **High Throughput**: Responds in `< 25ms` with `HTTP 202 Accepted` while enqueuing tasks into `WebhookEventJob`.
- **Deduplication**: SHA-256 payload hashing and custom idempotency key validation.
- **Rate Limiting**: Sliding window rate limits per deployment endpoint.
- **Background Processing**: Asynchronous worker dequeues events, resumes or initiates graph workflows, and flags errors in `FailedWebhookJob`.

---

## 🚀 Setup & Local Development

### 1. Prerequisites

- Python 3.12 or newer
- [uv](https://docs.astral.sh/uv/) (recommended) or `pip`

### 2. Environment Configuration

Copy the example template and create a `.env` file in the `backend/` directory:

```bash
cp env.example .env
```

```env
SECRET_KEY=your-django-secret-key
DEBUG=True
DATABASE_URL=postgresql://user:password@host:port/dbname

# Brand & Email Configuration
COMPANY_NAME=BodhixTech
COMPANY_SUPPORT_EMAIL=support@yourdomain.com
EMAIL_BACKEND=django.core.mail.backends.smtp.EmailBackend
EMAIL_HOST=smtp.your-email-provider.com
EMAIL_PORT=587
EMAIL_HOST_USER=your-smtp-user
EMAIL_HOST_PASSWORD=your-smtp-password
EMAIL_USE_TLS=True

# LLM Providers
GROQ_API_KEY=your-groq-api-key
GEMINI_API_KEY=your-gemini-api-key

# Google OAuth Credentials (for Workspace integrations)
GOOGLE_CLIENT_ID=your-google-client-id
GOOGLE_CLIENT_SECRET=your-google-client-secret
GOOGLE_REDIRECT_URI=http://localhost:3000/tools/oauth-callback
```

### 3. Install Dependencies

Using `uv`:
```bash
uv sync
```

Or using standard `pip`:
```bash
python -m venv .venv
source .venv/bin/activate  # On Windows: .venv\Scripts\activate
pip install -e .
```

### 4. Database Migrations

Apply database migrations:
```bash
uv run python manage.py migrate
```

### 5. Run ASGI Server

Run with Daphne for complete HTTP and WebSocket support:
```bash
uv run python manage.py runserver 8000
```
Or directly via Daphne:
```bash
uv run daphne -b 0.0.0.0 -p 8000 core.asgi:application
```

The API will be available at `http://127.0.0.1:8000/`.

### 6. Health Check Endpoint

Monitor container and service health:
- `GET /health/` or `GET /api/health/`
  - Returns `200 OK` when the service and database are operational.
  - Returns `503 Service Unavailable` if database connectivity fails.

---

## 🐳 Docker Deployment

Build and run the production image using Docker:

```bash
cd backend

# Build Docker image
docker build -t bodhixtech-backend .

# Run container with environment file
docker run -d \
  -p 8000:8000 \
  --env-file .env \
  --name bodhixtech-backend \
  bodhixtech-backend
```

