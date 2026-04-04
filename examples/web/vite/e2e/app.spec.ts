import { expect, test } from "@playwright/test";

test("counter increments", async ({ page }) => {
  await page.goto("/");
  const button = page.getByRole("button");
  await expect(button).toHaveText("count is 0");
  await button.click();
  await expect(button).toHaveText("count is 1");
});
