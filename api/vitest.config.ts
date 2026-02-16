import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    testTimeout: 15000, // mongodb-memory-server startup can be slow
    hookTimeout: 15000,
  },
});
