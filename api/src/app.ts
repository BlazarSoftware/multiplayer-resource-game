import express, { type Express } from "express";
import { type Db } from "mongodb";
import { createPlayerRoutes } from "./routes/players.js";
import { createWorldRoutes } from "./routes/world.js";

export function createApp(db: Db): Express {
  const app = express();
  app.use(express.json({ limit: "1mb" }));

  // Health check
  app.get("/health", async (_req, res) => {
    try {
      await db.command({ ping: 1 });
      res.json({ status: "ok", db: "connected" });
    } catch (err) {
      res.status(503).json({ status: "error", db: "disconnected", error: String(err) });
    }
  });

  // Mount routes
  app.use("/api/players", createPlayerRoutes(db));
  app.use("/api/world", createWorldRoutes(db));

  return app;
}
