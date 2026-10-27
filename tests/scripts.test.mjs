import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
test('package.json declara las cuatro puertas de calidad del kit',()=>{
  const pkg=JSON.parse(readFileSync(new URL('../package.json',import.meta.url),'utf8'));
  for(const s of ['test','typecheck','build:portable','check:coolify'])
    assert.ok(pkg.scripts&&pkg.scripts[s],'falta el script '+s);
  assert.equal(pkg.engines&&pkg.engines.node,'>=22.13.0','el motor declarado no cambia sin decision de Cesar');
});
test('el kit declara la version de Node que usa la CI',()=>{
  const nvm=readFileSync(new URL('../.nvmrc',import.meta.url),'utf8').trim();
  assert.match(nvm,/^22\.\d+\.\d+$/,'.nvmrc debe fijar Node 22');
});
test('los scripts de respaldo y restauracion siguen el contrato',()=>{
  const b=readFileSync(new URL('../scripts/respaldar.sh',import.meta.url),'utf8');
  const r=readFileSync(new URL('../scripts/restaurar.sh',import.meta.url),'utf8');
  for(const clave of ['software','version','database','sha256','status'])
    assert.ok(b.includes(clave),'el respaldo debe escribir la clave '+clave);
  assert.ok(b.includes('.env'),'el respaldo debe tratar el .env de forma explicita');
  assert.ok(r.includes('status'),'la restauracion debe validar el status del manifiesto');
  assert.ok(r.includes('SHA256SUMS'),'la restauracion debe validar el checksum');
});
