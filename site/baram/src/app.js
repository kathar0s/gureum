(() => {
  "use strict";
  const jamo = { f: "ㅏ", j: "ㅇ", s: "ㄴ" };
  const result = document.querySelector(".demo-result");
  const sequenceText = document.querySelector("#demo-jamo");
  const sequences = document.querySelectorAll(".sequence");
  sequences.forEach((button) => {
    button.addEventListener("click", () => {
      sequences.forEach((item) => {
        const selected = item === button;
        item.classList.toggle("selected", selected);
        item.setAttribute("aria-pressed", String(selected));
      });
      sequenceText.textContent = [...button.dataset.sequence].map((key) => jamo[key]).join(" · ");
      result.classList.remove("changed");
      requestAnimationFrame(() => result.classList.add("changed"));
    });
  });

  const themeButton = document.querySelector("#theme-toggle");
  const themes = ["system", "light", "dark"];
  const labels = { system: "시스템", light: "밝게", dark: "어둡게" };
  let themeIndex = 0;
  themeButton.addEventListener("click", () => {
    themeIndex = (themeIndex + 1) % themes.length;
    const theme = themes[themeIndex];
    if (theme === "system") delete document.documentElement.dataset.theme;
    else document.documentElement.dataset.theme = theme;
    themeButton.textContent = `테마: ${labels[theme]}`;
    themeButton.setAttribute("aria-label", `테마: ${labels[theme]}. 누르면 다음 테마로 변경합니다`);
  });
})();
