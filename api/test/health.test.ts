import { describe, it, expect, beforeAll, afterAll } from "vitest";
import request from "supertest";
import { setupTestDb, teardownTestDb } from "./setup.js";
import type { Express } from "express";

let app: Express;

beforeAll(async () => {
  const ctx = await setupTestDb();
  app = ctx.app;
});

afterAll(async () => {
  await teardownTestDb();
});

describe("GET /health", () => {
  it("returns ok status with connected db", async () => {
    const res = await request(app).get("/health");
    expect(res.status).toBe(200);
    expect(res.body.status).toBe("ok");
    expect(res.body.db).toBe("connected");
  });
});
