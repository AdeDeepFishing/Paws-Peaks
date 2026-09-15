"""Precompress large Godot files; Vercel serves them with Content-Encoding: gzip."""
import gzip
from pathlib import Path
import shutil
root = Path(__file__).resolve().parents[2] / 'web-build'
for name in ['index.pck', 'index.wasm']:
    path = root / name
    with path.open('rb') as source:
        if source.read(2) == b'\x1f\x8b': continue
    before = path.stat().st_size
    temp = path.with_suffix(path.suffix + '.tmp')
    with path.open('rb') as source, temp.open('wb') as target:
        with gzip.GzipFile(fileobj=target, mode='wb', compresslevel=6, mtime=0) as compressed:
            shutil.copyfileobj(source, compressed)
    temp.replace(path)
    print(f'{name}: {before // 1048576} MiB -> {path.stat().st_size // 1048576} MiB transfer')
