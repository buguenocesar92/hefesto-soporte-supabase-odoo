import {sqliteTable,text,integer} from 'drizzle-orm/sqlite-core';
export const workshops=sqliteTable('soporte',{owner:text('owner').primaryKey(),data:text('data').notNull(),revision:integer('revision').notNull().default(0)});
