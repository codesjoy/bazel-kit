export function nextCount(current: number): number {
  return current + 1;
}

export function mountCounter(button: HTMLButtonElement): void {
  let count = 0;

  const render = () => {
    button.textContent = "count is " + count;
  };

  button.addEventListener("click", () => {
    count = nextCount(count);
    render();
  });

  render();
}
