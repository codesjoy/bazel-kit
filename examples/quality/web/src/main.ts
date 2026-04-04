import "./style.css";

const app = document.querySelector("#app");

if (app instanceof HTMLDivElement) {
  app.textContent = "quality web example";
}
