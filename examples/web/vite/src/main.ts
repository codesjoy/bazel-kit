import "./style.css";
import { mountCounter } from "./counter";

const app = document.querySelector<HTMLDivElement>("#app");

if (app) {
  app.innerHTML = '<button id="counter" type="button"></button>';
  const button = app.querySelector<HTMLButtonElement>("#counter");
  if (button) {
    mountCounter(button);
  }
}
