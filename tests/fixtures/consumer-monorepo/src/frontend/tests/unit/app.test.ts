import { describe, expect, it } from "vitest";

import { applicationName } from "../../src/index";

describe("consumer fixture", () => {
  it("exports the application name", () => {
    expect(applicationName).toBe("template-ai-native consumer fixture");
  });
});
