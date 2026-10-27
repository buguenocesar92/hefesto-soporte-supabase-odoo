import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,existsSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {join} from 'node:path';
const raiz=fileURLToPath(new URL('..',import.meta.url));
const src=readFileSync(join(raiz,'migration/prepare_odoo.py'),'utf8');
test('la preparacion Odoo no tiene ningun mecanismo de conexion',()=>{
  assert.equal(/xmlrpc|jsonrpc|8069|import requests|import urllib|import socket|import http/i.test(src),false,
    'el script de preparacion no debe poder conectarse a un Odoo');
});
test('la preparacion Odoo se declara offline',()=>{
  assert.match(src,/no conecta ni escribe en el ERP|no escribe a Odoo|sin escrituras externas|mapear y validar en Odoo|never contacts Odoo/i,
    'el script debe declarar que es una preparacion offline');
});
test('la preparacion Odoo exporta CSV, el JSON completo y su LEEME',()=>{
  const csvs=[...src.matchAll(/(?:save|write)\('([^']+\.csv)'/g)].map(m=>m[1]);
  assert.ok(csvs.length>=4,'debe exportar al menos cuatro CSV, encontro '+csvs.length);
  assert.match(src,/respaldo_completo\.json|hefesto-completo\.json/,'debe exportar el JSON completo');
  assert.match(src,/LEEME\.txt|manifest\.json/,'debe exportar el LEEME o su manifiesto');
});
test('la preparacion Odoo no publica datos personales en crudo fuera del LEEME',()=>{
  assert.equal(/print\(.*(password|clave|secret)/i.test(src),false,'no debe imprimir secretos');
});
