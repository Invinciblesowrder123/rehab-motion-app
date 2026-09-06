CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE TABLE IF NOT EXISTS medical_terms (
  id BIGSERIAL PRIMARY KEY,
  standard VARCHAR(255) NOT NULL,
  en VARCHAR(255),
  category VARCHAR(50) NOT NULL,
  colloquial TEXT[] NOT NULL DEFAULT '{}',
  confidence VARCHAR(20),
  definition TEXT,
  source_book VARCHAR(255),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_medical_terms_standard ON medical_terms(standard);
CREATE INDEX IF NOT EXISTS idx_medical_terms_category ON medical_terms(category);

CREATE TABLE IF NOT EXISTS knowledge_chunks (
  id BIGSERIAL PRIMARY KEY,
  source_book VARCHAR(255) NOT NULL,
  source_path TEXT NOT NULL,
  chapter VARCHAR(255),
  content TEXT NOT NULL,
  content_hash CHAR(64) NOT NULL UNIQUE,
  metadata JSONB NOT NULL DEFAULT '{}',
  embedding vector(1024),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_knowledge_chunks_source ON knowledge_chunks(source_book);

CREATE TABLE IF NOT EXISTS chat_sessions (
  id UUID PRIMARY KEY,
  slot_state JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS safety_audit_events (
  id BIGSERIAL PRIMARY KEY,
  request_id UUID NOT NULL,
  outcome VARCHAR(20) NOT NULL CHECK (outcome IN ('urgent', 'clarify', 'answer', 'unavailable')),
  severity SMALLINT NOT NULL DEFAULT 0,
  matched_rules TEXT[] NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
