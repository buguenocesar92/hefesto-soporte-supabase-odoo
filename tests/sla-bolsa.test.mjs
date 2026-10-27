import test from 'node:test';
import assert from 'node:assert/strict';
import {sla,minutesUsed,contractUsage,active,stages,priorities} from '../lib/domain.ts';

const iso=(ms)=>new Date(ms).toISOString();
const ahora=Date.parse('2026-03-10T15:00:00.000Z');
const ticket=(extra={})=>{const t={id:'t1',status:'En curso',priority:'Alta',firstResponseAt:null,resolvedAt:null,
  responseDue:iso(ahora+3600000),resolutionDue:iso(ahora+7200000),timeEntries:[],...extra};return t;};

test('un ticket sin respuesta y con la hora vencida queda vencido',()=>{
  const t=ticket({responseDue:iso(ahora-3600000),resolutionDue:iso(ahora+7200000)});
  const r=sla(t,ahora);
  assert.equal(r.responseLate,true,'sin primera respuesta y con el plazo vencido debe estar atrasado');
  assert.equal(r.resolutionLate,false,'el plazo de resolucion sigue vigente');
  assert.equal(r.overdue,true,'el ticket activo y vencido debe estar overdue');
});

test('un ticket respondido y resuelto a tiempo no esta vencido',()=>{
  const t=ticket({firstResponseAt:iso(ahora-1800000),resolvedAt:iso(ahora-900000)});
  const r=sla(t,ahora);
  assert.equal(r.responseLate,false);
  assert.equal(r.resolutionLate,false);
  assert.equal(r.overdue,false);
});

test('un ticket resuelto con retraso queda marcado como resuelto tarde, pero deja de estar overdue',()=>{
  const t=ticket({status:'Resuelto',firstResponseAt:iso(ahora-5400000),resolvedAt:iso(ahora+1000),
    responseDue:iso(ahora-7200000),resolutionDue:iso(ahora)});
  const r=sla(t,ahora);
  assert.equal(r.resolutionLate,true,'resolver despues del plazo se registra');
  assert.equal(active(t),false,'un ticket resuelto ya no esta activo');
  assert.equal(r.overdue,false,'el atraso de un ticket ya cerrado no se arrastra como pendiente');
});

test('un ticket en espera de cliente sigue activo y cuenta los dias',()=>{
  const t=ticket({status:'Esperando cliente',firstResponseAt:iso(ahora-5400000)});
  assert.equal(active(t),true);
  assert.equal(sla(t,ahora).overdue,false,'con la primera respuesta a tiempo no hay atraso de respuesta');
});

test('los estados y prioridades del dominio son los que la UI documenta',()=>{
  assert.deepEqual(stages,['Nuevo','En curso','Esperando cliente','Resuelto','Cerrado']);
  assert.deepEqual(priorities,['Baja','Normal','Alta','Urgente']);
});

test('minutesUsed suma los minutos registrados del ticket',()=>{
  const t=ticket({timeEntries:[{minutes:30},{minutes:45},{minutes:15}]});
  assert.equal(minutesUsed(t),90);
  assert.equal(minutesUsed(ticket()),0);
});

test('la bolsa de horas resta lo incluido y no marca excedente mientras alcanza',()=>{
  const c={id:'co1',includedMinutes:300,hourlyRate:25000};
  const s={tickets:[{id:'t1',contractId:'co1',timeEntries:[{billable:true,minutes:120,date:'2026-03-02'}]}]};
  const u=contractUsage(s,c,'2026-03');
  assert.equal(u.used,120);
  assert.equal(u.remaining,180);
  assert.equal(u.extra,0);
  assert.equal(u.estimate,0);
});

test('la bolsa de horas calcula el excedente y su estimacion en CLP',()=>{
  const c={id:'co1',includedMinutes:300,hourlyRate:25000};
  const s={tickets:[{id:'t1',contractId:'co1',timeEntries:[{billable:true,minutes:360,date:'2026-03-02'}]}]};
  const u=contractUsage(s,c,'2026-03');
  assert.equal(u.used,360);
  assert.equal(u.remaining,0,'nunca queda bolsa negativa');
  assert.equal(u.extra,60);
  assert.equal(u.estimate,Math.round(60*25000/60),'60 minutos extra a 25000 CLP la hora son 25000 CLP');
});

test('la bolsa de horas ignora lo no facturable y los otros meses',()=>{
  const c={id:'co1',includedMinutes:300,hourlyRate:25000};
  const s={tickets:[{id:'t1',contractId:'co1',timeEntries:[
    {billable:false,minutes:500,date:'2026-03-02'},
    {billable:true,minutes:90,date:'2026-02-11'},
    {billable:true,minutes:60,date:'2026-03-09'}]}]};
  const u=contractUsage(s,c,'2026-03');
  assert.equal(u.used,60,'solo lo billable del mes pedido');
  assert.equal(u.extra,0);
});

test('la bolsa de horas separa contratos',()=>{
  const c1={id:'co1',includedMinutes:300,hourlyRate:25000};
  const c2={id:'co2',includedMinutes:600,hourlyRate:22000};
  const s={tickets:[
    {id:'t1',contractId:'co1',timeEntries:[{billable:true,minutes:400,date:'2026-03-02'}]},
    {id:'t2',contractId:'co2',timeEntries:[{billable:true,minutes:100,date:'2026-03-02'}]}]};
  assert.equal(contractUsage(s,c1,'2026-03').used,400);
  assert.equal(contractUsage(s,c2,'2026-03').used,100);
});
