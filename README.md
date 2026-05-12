# Smart Doctor Connect AI

This is a full-stack application for connecting patients with doctors in Pakistan, featuring AI-powered search and assistance.

## Tech Stack

- **Frontend:** Next.js (App Router, TypeScript, Tailwind CSS)
- **Backend:** FastAPI (Python, SQLAlchemy, Pydantic)
- **Database:** PostgreSQL
- **Caching/Rate Limiting:** Redis

## Project Structure

```text
├── frontend/             # Next.js application
│   ├── src/app/          # Pages and layouts
│   ├── src/components/   # Reusable UI components
│   └── src/lib/          # API client and utilities
├── backend/              # FastAPI application
│   ├── app/api/          # API endpoints
│   ├── app/core/         # Configuration and security
│   ├── app/models/       # Database models
│   ├── app/schemas/      # Pydantic validation schemas
│   └── app/services/     # Business logic
├── docs/                 # Project documentation
└── docker-compose.yml    # Development environment orchestration
```

## Getting Started

1. **Clone the repository**
2. **Setup Backend:**
   ```bash
   cd backend
   python -m venv venv
   source venv/bin/activate
   pip install -r requirements.txt
   ```
3. **Setup Frontend:**
   ```bash
   cd frontend
   npm install
   ```
4. **Environment Variables:**
   Copy `.env.example` to `.env` in the root and fill in the values.

## Development with Docker

```bash
docker-compose up --build
```
