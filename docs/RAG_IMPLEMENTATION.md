# P2 RAG implementation boundary

`ingest_knowledge.py` deterministically chunks only the existing Markdown knowledge base and records source paths plus SHA-256 deduplication hashes in `knowledge_chunks`.

The vector column is deliberately empty at bootstrap: embedding requires an approved BGE-M3 model artifact and a separately deployed worker. This prevents an unreviewed model download or an accidental attempt to run 1024-dimension embeddings in the API process. Before enabling retrieval, deploy a worker that writes BGE-M3 1024-d vectors, then add cosine top-k retrieval in the NestJS `ChatService`. The LLM remains unreachable until the P0 safety and clarification branch completes.
