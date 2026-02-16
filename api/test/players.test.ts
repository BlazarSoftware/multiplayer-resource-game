import { describe, it, expect, beforeAll, afterAll, beforeEach } from "vitest";
import request from "supertest";
import { setupTestDb, teardownTestDb, clearCollections } from "./setup.js";
import type { Express } from "express";

let app: Express;

beforeAll(async () => {
  const ctx = await setupTestDb();
  app = ctx.app;
});

afterAll(async () => {
  await teardownTestDb();
});

beforeEach(async () => {
  await clearCollections();
});

describe("POST /api/players", () => {
  it("creates a player with a UUID", async () => {
    const res = await request(app)
      .post("/api/players")
      .send({ player_name: "Alice", level: 1 });
    expect(res.status).toBe(201);
    expect(res.body.player_name).toBe("Alice");
    expect(res.body.player_id).toBeDefined();
    expect(typeof res.body.player_id).toBe("string");
    expect(res.body.player_id.length).toBeGreaterThan(0);
  });

  it("returns 400 without player_name", async () => {
    const res = await request(app)
      .post("/api/players")
      .send({ level: 1 });
    expect(res.status).toBe(400);
    expect(res.body.error).toContain("player_name");
  });

  it("returns 409 on duplicate name", async () => {
    await request(app)
      .post("/api/players")
      .send({ player_name: "Bob" });
    const res = await request(app)
      .post("/api/players")
      .send({ player_name: "Bob" });
    expect(res.status).toBe(409);
  });

  it("preserves extra fields in body", async () => {
    const res = await request(app)
      .post("/api/players")
      .send({ player_name: "Carol", party: [{ species_id: "rice_ball" }] });
    expect(res.status).toBe(201);
    expect(res.body.party).toEqual([{ species_id: "rice_ball" }]);
  });
});

describe("GET /api/players/by-name/:name", () => {
  it("returns player data when found", async () => {
    const create = await request(app)
      .post("/api/players")
      .send({ player_name: "Dave", money: 500 });
    const res = await request(app).get("/api/players/by-name/Dave");
    expect(res.status).toBe(200);
    expect(res.body.player_name).toBe("Dave");
    expect(res.body.money).toBe(500);
    expect(res.body.player_id).toBe(create.body.player_id);
  });

  it("returns empty object when not found", async () => {
    const res = await request(app).get("/api/players/by-name/Nobody");
    expect(res.status).toBe(200);
    expect(res.body).toEqual({});
  });
});

describe("GET /api/players/by-name/:name/exists", () => {
  it("returns exists:true when player exists", async () => {
    await request(app)
      .post("/api/players")
      .send({ player_name: "Eve" });
    const res = await request(app).get("/api/players/by-name/Eve/exists");
    expect(res.status).toBe(200);
    expect(res.body.exists).toBe(true);
  });

  it("returns exists:false when player missing", async () => {
    const res = await request(app).get("/api/players/by-name/Ghost/exists");
    expect(res.status).toBe(200);
    expect(res.body.exists).toBe(false);
  });
});

describe("GET /api/players/:id", () => {
  it("returns player by UUID", async () => {
    const create = await request(app)
      .post("/api/players")
      .send({ player_name: "Frank" });
    const id = create.body.player_id;
    const res = await request(app).get(`/api/players/${id}`);
    expect(res.status).toBe(200);
    expect(res.body.player_name).toBe("Frank");
  });

  it("returns 404 for missing UUID", async () => {
    const res = await request(app).get("/api/players/nonexistent-uuid");
    expect(res.status).toBe(404);
  });
});

describe("PUT /api/players/:id", () => {
  it("upserts player data", async () => {
    const create = await request(app)
      .post("/api/players")
      .send({ player_name: "Grace" });
    const id = create.body.player_id;
    const res = await request(app)
      .put(`/api/players/${id}`)
      .send({ player_name: "Grace", money: 1000, level: 10 });
    expect(res.status).toBe(200);
    expect(res.body.ok).toBe(true);

    // Verify update
    const get = await request(app).get(`/api/players/${id}`);
    expect(get.body.money).toBe(1000);
    expect(get.body.level).toBe(10);
  });

  it("creates new player on upsert with new ID", async () => {
    const res = await request(app)
      .put("/api/players/new-uuid-123")
      .send({ player_name: "Heidi", money: 0 });
    expect(res.status).toBe(200);
    expect(res.body.upserted).toBe(true);
  });
});

describe("DELETE /api/players/:id", () => {
  it("deletes existing player", async () => {
    const create = await request(app)
      .post("/api/players")
      .send({ player_name: "Ivan" });
    const id = create.body.player_id;
    const res = await request(app).delete(`/api/players/${id}`);
    expect(res.status).toBe(200);
    expect(res.body.ok).toBe(true);

    // Verify deleted
    const get = await request(app).get(`/api/players/${id}`);
    expect(get.status).toBe(404);
  });

  it("returns 404 when deleting non-existent player", async () => {
    const res = await request(app).delete("/api/players/nonexistent");
    expect(res.status).toBe(404);
  });
});
