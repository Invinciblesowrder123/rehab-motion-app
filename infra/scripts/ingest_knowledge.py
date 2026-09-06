"""P2: chunks Markdown into PostgreSQL. Embeddings remain NULL until a reviewed bge-m3 worker fills them."""
import argparse, hashlib, os, re
from pathlib import Path
import psycopg

def chunks(text: str, size: int = 900, overlap: int = 120):
    text = re.sub(r'\n{3,}', '\n\n', text).strip()
    start = 0
    while start < len(text):
        end = min(len(text), start + size)
        if end < len(text):
            cut = max(text.rfind('\n\n', start, end), text.rfind('。', start, end))
            if cut > start + size // 2: end = cut + 1
        piece = text[start:end].strip()
        if piece: yield piece
        start = max(end - overlap, start + 1)

def main():
    p = argparse.ArgumentParser()
    p.add_argument('--source', required=True)
    p.add_argument('--database-url', default=os.environ.get('DATABASE_URL'))
    args = p.parse_args()
    if not args.database_url: raise SystemExit('DATABASE_URL is required')
    root = Path(args.source)
    files = list(root.rglob('*.md'))
    with psycopg.connect(args.database_url) as conn:
        with conn.cursor() as cur:
            for path in files:
                text = path.read_text(encoding='utf-8')
                book = path.relative_to(root).parts[0]
                for content in chunks(text):
                    digest = hashlib.sha256(f'{path}:{content}'.encode()).hexdigest()
                    cur.execute('INSERT INTO knowledge_chunks(source_book, source_path, chapter, content, content_hash, metadata) VALUES (%s,%s,%s,%s,%s,%s) ON CONFLICT (content_hash) DO NOTHING', (book, str(path), path.stem, content, digest, '{}'))
        conn.commit()
    print(f'processed {len(files)} Markdown files; embeddings are intentionally pending')
if __name__ == '__main__': main()
