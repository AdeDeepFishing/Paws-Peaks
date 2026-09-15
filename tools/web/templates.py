"""Fetch only Web templates from the official archive using HTTP byte ranges."""
import io
import os
from pathlib import Path
import sys
from urllib.request import Request, urlopen
from zipfile import ZipFile

URL = 'https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz'

class RemoteZip(io.RawIOBase):
    def __init__(self, url):
        response = urlopen(Request(url, method='HEAD'), timeout=60)
        self.url = response.url
        self.length = int(response.headers['Content-Length'])
        self.position = 0
    def seekable(self): return True
    def seek(self, offset, whence=0):
        self.position = offset + (self.position if whence == 1 else self.length if whence == 2 else 0)
        return self.position
    def tell(self): return self.position
    def read(self, size=-1):
        size = min(self.length - self.position, size if size >= 0 else self.length)
        if size <= 0: return b''
        request = Request(self.url, headers={'Range': f'bytes={self.position}-{self.position+size-1}'})
        with urlopen(request, timeout=120) as response:
            if response.status != 206: raise RuntimeError('Template server did not honor byte range')
            data = response.read(size)
        self.position += len(data)
        return data

def main():
    target = Path(sys.argv[1]); target.mkdir(parents=True, exist_ok=True)
    needed = ['web_nothreads_release.zip', 'web_nothreads_debug.zip']
    if not all((target / name).exists() for name in needed):
        with ZipFile(RemoteZip(URL)) as archive:
            for name in needed:
                data = archive.read('templates/' + name)
                temp = target / (name + '.tmp'); temp.write_bytes(data); temp.replace(target / name)
    # Custom templates avoid modifying the developer's installed templates.
    os.environ['TALE_WEB_TEMPLATES'] = str(target.resolve())
    print(target.resolve())
if __name__ == '__main__': main()
