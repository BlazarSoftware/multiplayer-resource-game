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

describe("GET /api/world", () => {
  it("returns empty object when no world state exists", async () => {
    const res = await request(app).get("/api/world");
    expect(res.status).toBe(200);
    expect(res.body).toEqual({});
  });

  it("returns saved world state", async () => {
    await request(app)
      .put("/api/world")
      .send({ season: "spring", day: 3, weather: "sunny" });
    const res = await request(app).get("/api/world");
    expect(res.status).toBe(200);
    expect(res.body.season).toBe("spring");
    expect(res.body.day).toBe(3);
    expect(res.body.weather).toBe("sunny");
  });

  it("does not include _id in response", async () => {
    await request(app)
      .put("/api/world")
      .send({ season: "summer" });
    const res = await request(app).get("/api/world");
    expect(res.body._id).toBeUndefined();
  });
});

describe("PUT /api/world", () => {
  it("creates world state", async () => {
    const res = await request(app)
      .put("/api/world")
      .send({ season: "autumn", day: 7 });
    expect(res.status).toBe(200);
    expect(res.body.ok).toBe(true);
  });

  it("replaces world state on second PUT", async () => {
    await request(app)
      .put("/api/world")
      .send({ season: "spring", day: 1 });
    await request(app)
      .put("/api/world")
      .send({ season: "winter", day: 14, year: 2 });
    const res = await request(app).get("/api/world");
    expect(res.body.season).toBe("winter");
    expect(res.body.day).toBe(14);
    expect(res.body.year).toBe(2);
    // Old field should not persist if not in new body
    // (replaceOne replaces entire document)
  });

  it("round-trips complex data", async () => {
    const worldData = {
      season: "spring",
      day: 5,
      restaurants: { player1: 0, player2: 1 },
      world_items: [{ uid: 1, item_id: "herb", pos: [10, 0, 5] }],
    };
    await request(app).put("/api/world").send(worldData);
    const res = await request(app).get("/api/world");
    expect(res.body.season).toBe("spring");
    expect(res.body.restaurants).toEqual({ player1: 0, player2: 1 });
    expect(res.body.world_items).toHaveLength(1);
  });
});
