import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const yaml=readFileSync(new URL('../.github/workflows/ci.yml',import.meta.url),'utf8');
test('la CI corre la suite de pruebas del kit',()=>{
  assert.match(yaml,/npm test/,'la CI debe ejecutar npm test');
});
test('la CI fija Node 22 para respetar los engines declarados',()=>{
  assert.match(yaml,/node-version:\s*'?22/,'la CI debe usar Node 22');
});
test('la CI corre gitleaks sobre el repositorio y su historial',()=>{
  assert.match(yaml,/gitleaks/,'la CI debe ejecutar gitleaks');
  assert.match(yaml,/--log-opts|--all/,'gitleaks debe mirar tambien el historial');
});
test('la CI no depende de paquetes ausentes del kit',()=>{
  assert.equal(/axe-core|@axe-core|playwright/.test(yaml),false,'la CI no debe depender de paquetes que el kit no declara');
});
