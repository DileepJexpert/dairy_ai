import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const { DatabaseSync } = require('node:sqlite');

export class MockD1PreparedStatement {
  public sql: string;
  public params: any[];
  private db: any;

  constructor(db: any, sql: string, params: any[] = []) {
    this.db = db;
    this.sql = sql;
    this.params = params;
  }

  bind(...values: any[]): MockD1PreparedStatement {
    const cleanParams = values.map((v) => {
      if (typeof v === 'boolean') return v ? 1 : 0;
      if (v === undefined) return null;
      return v;
    });
    return new MockD1PreparedStatement(this.db, this.sql, cleanParams);
  }

  async first<T = Record<string, any>>(colName?: string): Promise<T | null> {
    const stmt = this.db.prepare(this.sql);
    const row = stmt.get(...this.params) as Record<string, any> | undefined;
    if (!row) return null;
    if (colName) return row[colName] as T;
    return row as T;
  }

  async run(): Promise<{ success: boolean; meta: any }> {
    const stmt = this.db.prepare(this.sql);
    const info = stmt.run(...this.params);
    return { success: true, meta: info };
  }

  async all<T = Record<string, any>>(): Promise<{ results: T[]; success: boolean; meta: any }> {
    const stmt = this.db.prepare(this.sql);
    const results = stmt.all(...this.params) as T[];
    return { results, success: true, meta: {} };
  }

  async raw<T = any[]>(): Promise<T[]> {
    const stmt = this.db.prepare(this.sql);
    return stmt.all(...this.params) as unknown as T[];
  }
}

export class MockD1Database {
  public db: any;

  constructor() {
    this.db = new DatabaseSync(':memory:');
  }

  prepare(sql: string): MockD1PreparedStatement {
    return new MockD1PreparedStatement(this.db, sql);
  }

  async batch<T = unknown>(statements: MockD1PreparedStatement[]): Promise<any[]> {
    this.db.exec('BEGIN TRANSACTION');
    try {
      const results: any[] = [];
      for (const stmt of statements) {
        const isSelect = /^\s*(SELECT|PRAGMA)/i.test(stmt.sql);
        if (isSelect) {
          results.push(await stmt.all());
        } else {
          results.push(await stmt.run());
        }
      }
      this.db.exec('COMMIT');
      return results;
    } catch (err) {
      this.db.exec('ROLLBACK');
      throw err;
    }
  }

  async exec(query: string): Promise<{ count: number; duration: number }> {
    this.db.exec(query);
    return { count: 1, duration: 0 };
  }

  loadMigrations(migrationsDirPath: string): void {
    const files = fs.readdirSync(migrationsDirPath).filter((f: string) => f.endsWith('.sql')).sort();
    for (const f of files) {
      const sql = fs.readFileSync(path.join(migrationsDirPath, f), 'utf-8');
      this.db.exec(sql);
    }
  }
}
