import http from 'node:http';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
const root = path.dirname(fileURLToPath(import.meta.url));
const files = new Map([['/', 'index.html'], ['/index.html','index.html'], ['/styles.css','styles.css'], ['/app.mjs','app.mjs'], ['/engine.mjs','engine.mjs']]);
const types = { '.html': 'text/html; charset=utf-8', '.css': 'text/css; charset=utf-8', '.mjs': 'text/javascript; charset=utf-8' };
const server = http.createServer(async (req,res) => {
  const pathname = new URL(req.url, 'http://localhost').pathname;
  if (!files.has(pathname) || !['GET','HEAD'].includes(req.method)) { res.writeHead(404); res.end('Not found'); return; }
  try {
    const file = files.get(pathname);
    const data = await readFile(path.join(root,file));
    res.writeHead(200, { 'Content-Type': types[path.extname(file)], 'Cache-Control':'no-store', 'X-Content-Type-Options':'nosniff', 'Referrer-Policy':'no-referrer', 'Content-Security-Policy': "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self'; frame-ancestors 'none'; base-uri 'none'" });
    res.end(req.method === 'HEAD' ? undefined : data);
  } catch { res.writeHead(500); res.end('Cannot load preview'); }
});
server.listen(4317,'127.0.0.1',()=>console.log('Seuil preview: http://127.0.0.1:4317'));
