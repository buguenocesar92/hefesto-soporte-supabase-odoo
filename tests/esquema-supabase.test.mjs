import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,readdirSync,existsSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {join} from 'node:path';
const raiz=fileURLToPath(new URL('..',import.meta.url));
const tablas=['hefesto_soporte_states','hefesto_soporte_sessions'];
const sql=readdirSync(join(raiz,'supabase/migrations')).filter(f=>f.endsWith('.sql')).map(f=>readFileSync(join(raiz,'supabase/migrations',f),'utf8')).join('\n');
test('la migracion crea las dos tablas del kit',()=>{
  for(const t of tablas){
    assert.ok(sql.includes(t),'la migracion debe crear '+t);
    assert.match(sql,new RegExp('create table[^;]*'+t,'i'),'debe existir create table para '+t);
  }
});
test('la migracion habilita RLS en las dos tablas',()=>{
  for(const t of tablas)
    assert.match(sql,new RegExp('alter table[^;]*'+t+'[^;]*enable row level security','i'),'RLS debe estar habilitado en '+t);
});
test('la migracion revoca el acceso a los roles publicos y no se lo concede',()=>{
  assert.match(sql,/revoke[^;]*\b(anon|authenticated)\b/i,'debe revocarse el acceso a anon/authenticated');
  assert.equal(/grant[^;]*\bto\s+(anon|authenticated)\b/i.test(sql),false,'no se debe dar acceso a anon/authenticated');
  assert.match(sql,/grant[^;]*\bto\s+service_role\b/i,'el servidor de confianza accede como service_role');
});
test('el adaptador solo consulta las tablas vigentes',()=>{
  const src=readFileSync(join(raiz,'portable/storage.mjs'),'utf8');
  for(const t of tablas)assert.ok(src.includes(t),'el adaptador debe consultar '+t);
  const otras=src.match(/hefesto_[a-z_]*(?:workshops|sessions)\b/g)||[];
  const ajenas=[...new Set(otras.filter(t=>!tablas.includes(t)))];
  assert.deepEqual(ajenas,[],'el adaptador no debe consultar tablas ajenas: '+ajenas.join(','));
});
test('la documentacion de Supabase nombra las tablas vigentes',()=>{
  const doc=join(raiz,'docs/SUPABASE.md');
  if(!existsSync(doc))return;
  const txt=readFileSync(doc,'utf8');
  for(const t of tablas)assert.ok(txt.includes(t),'docs/SUPABASE.md debe nombrar '+t);
});
