import {defineConfig} from "vitest/config";

// https://vitest.dev/config/
export default defineConfig({
  test: {
    globals: true,
    environment: "node",
    setupFiles: "test/test-setup.ts",
    reporters: ["verbose"],
    maxConcurrency: 5,
    testTimeout: 200e3, // 200s
    hookTimeout: 50e3, // 50s
  },
});
