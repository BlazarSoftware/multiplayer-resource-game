import { MongoMemoryServer } from "mongodb-memory-server";
import { MongoClient, type Db } from "mongodb";
import { type Express } from "express";
import { createApp } from "../src/app.js";

let mongod: MongoMemoryServer;
let client: MongoClient;
let db: Db;
let app: Express;

export async function setupTestDb() {
  mongod = await MongoMemoryServer.create();
  const uri = mongod.getUri();
  client = new MongoClient(uri);
  await client.connect();
  db = client.db("test_creature_crafting");

  // Create indexes matching production
  await db.collection("players").createIndex({ player_name: 1 }, { unique: true });

  app = createApp(db);
  return { app, db };
}

export async function teardownTestDb() {
  if (client) await client.close();
  if (mongod) await mongod.stop();
}

export async function clearCollections() {
  if (db) {
    await db.collection("players").deleteMany({});
    await db.collection("world").deleteMany({});
  }
}

export { app, db };
