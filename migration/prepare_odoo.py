"""CSV de preparación para Odoo u otra mesa de ayuda; sin escrituras externas."""
import csv,json,sys
from pathlib import Path
if len(sys.argv)!=3:raise SystemExit('Uso: python3 migration/prepare_odoo.py respaldo.json salida')
p=json.loads(Path(sys.argv[1]).read_text());s=p.get('state',p)
if s.get('format')!='hefesto-soporte':raise SystemExit('Formato incompatible')
out=Path(sys.argv[2]);out.mkdir(parents=True,exist_ok=True)
def save(name,columns,rows):
 with (out/name).open('w',newline='',encoding='utf-8-sig') as f:
  w=csv.writer(f);w.writerow(columns);w.writerows(rows)
save('01_clientes.csv',['ID externo','Nombre','Contacto','Correo','Teléfono'],[['hefesto_customer_'+c['id'],c['name'],c['contact'],c['email'],c['phone']] for c in s['customers']])
save('02_responsables_revision.csv',['ID referencia','Nombre','Especialidad','Activo'],[[a['id'],a['name'],a['specialty'],a['active']] for a in s['agents']])
save('03_contratos_revision.csv',['ID externo','Cliente referencia','Nombre','Inicio','Fin','Minutos mensuales','Valor mensual CLP','Hora extra CLP','Notas'],[['hefesto_contract_'+c['id'],'hefesto_customer_'+c['customerId'],c['name'],c['start'],c['end'],c['includedMinutes'],c['monthlyFee'],c['hourlyRate'],c['notes']] for c in s['contracts']])
save('04_tickets_revision.csv',['ID externo','Cliente referencia','Título','Descripción','Categoría','Prioridad','Estado','Responsable referencia','Contrato referencia','Creado ISO','Límite respuesta ISO','Límite resolución ISO','Solución','Verificación'],[['hefesto_ticket_'+t['id'],'hefesto_customer_'+t['customerId'],t['title'],t['description'],t['category'],t['priority'],t['status'],t['agentId'],('hefesto_contract_'+t['contractId']) if t['contractId'] else '',t['createdAt'],t['responseDue'],t['resolutionDue'],t.get('resolution',''),t.get('verification','')] for t in s['tickets']])
save('05_horas_revision.csv',['ID','Ticket referencia','Responsable referencia','Fecha Santiago','Minutos','Bolsa o facturable','Descripción','Anulado','Motivo anulación'],[[e['id'],'hefesto_ticket_'+t['id'],e['agentId'],e['date'],e['minutes'],e['billable'],e['description'],e.get('voided',False),e.get('voidReason','')] for t in s['tickets'] for e in t['timeEntries']])
save('06_conocimiento.csv',['ID','Título','Categoría','Contenido','Actualizado ISO'],[[a['id'],a['title'],a['category'],a['body'],a['updatedAt']] for a in s['articles']])
(out/'respaldo_completo.json').write_text(json.dumps(s,ensure_ascii=False,indent=2))
(out/'LEEME.txt').write_text('Preparación para mapear en la versión y módulos de destino; no importación automática ni addon. Clientes primero. Responsables son registros, no cuentas: crear y mapear usuarios en destino. Adaptar estados, prioridades, contratos y campos de tiempo. No asumir disponibilidad del módulo de mesa de ayuda en cualquier edición Odoo. Mensajes, notas internas, auditoría e historial están en JSON completo: conservar privacidad al migrar. Las horas se exportan en minutos; convertir si destino usa horas. No crea facturas, asientos ni suscripciones. Probar en base de ensayo.\n')
print('Exportación preparada:',out)
