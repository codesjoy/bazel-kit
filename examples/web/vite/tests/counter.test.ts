import { describe, expect, it } from "vitest";

import { nextCount } from "../src/counter";

describe("nextCount", () => {
  it("increments by one", () => {
    expect(nextCount(0)).toBe(1);
  });
});
