const statusEl = document.getElementById("status");
const resultEl = document.getElementById("result");
const pingButton = document.getElementById("ping");
const valueInput = document.getElementById("value");
const codeValue = document.getElementById("code-value");
const urlOpenError = document.getElementById("url-open-error");
const urlOpenErrorUrl = document.getElementById("url-open-error-url");
const urlOpenErrorClose = document.getElementById("url-open-error-close");

function readValue() {
  const value = Number(valueInput.value);
  return Number.isFinite(value) ? value : 0;
}

function syncCode() {
  codeValue.textContent = String(readValue());
}

async function ping() {
  if (typeof window.nativeCall !== "function") {
    statusEl.textContent = "preview";
    resultEl.textContent = "Open this app with `avelra run` to use the native bridge.";
    pingButton.disabled = true;
    return;
  }

  const value = readValue();
  statusEl.textContent = "calling…";
  statusEl.className = "state";

  try {
    const response = await window.nativeCall({
      method: "app.ping",
      data: { value }
    });
    statusEl.textContent = "ready";
    statusEl.classList.add("ok");
    renderResult(response);
  } catch (error) {
    statusEl.textContent = "bridge error";
    statusEl.classList.add("error");
    resultEl.textContent = String(error);
  }
}

function renderResult(response) {
  const payload = response.returnValue || {};
  const echo = payload.echo || {};
  const rows = [
    ["method", "app.ping"],
    ["message", payload.message],
    ["echo.value", echo.value],
    ["runtime", payload.runtime]
  ];

  resultEl.textContent = "";
  for (const [name, value] of rows) {
    const row = document.createElement("div");
    row.className = "row";
    const key = document.createElement("span");
    key.textContent = name;
    const val = document.createElement("span");
    val.textContent = String(value ?? "");
    row.append(key, val);
    resultEl.append(row);
  }
}

function reportReady() {
  if (typeof window.nativeCall !== "function") {
    return;
  }
  // Wait for the first painted frame before dismissing the loading overlay.
  requestAnimationFrame(() => requestAnimationFrame(() => {
    window.nativeCall({ method: "app.ready" }).catch(() => {});
  }));
}

function showUrlOpenError(url) {
  urlOpenErrorUrl.textContent = url;
  urlOpenError.hidden = false;
  urlOpenErrorClose.focus();
}

function hideUrlOpenError() {
  urlOpenError.hidden = true;
}

urlOpenErrorClose.addEventListener("click", hideUrlOpenError);
urlOpenError.addEventListener("click", (event) => {
  if (event.target === urlOpenError) {
    hideUrlOpenError();
  }
});
document.addEventListener("keydown", (event) => {
  if (event.key === "Escape" && !urlOpenError.hidden) {
    hideUrlOpenError();
  }
});

for (const link of document.querySelectorAll("a[data-open-url]")) {
  link.addEventListener("click", async (event) => {
    event.preventDefault();
    const url = link.href;
    if (typeof window.nativeCall === "function") {
      try {
        await window.nativeCall({ method: "os.openUrl", data: { url } });
      } catch (error) {
        showUrlOpenError(url);
      }
    } else {
      window.open(url, "_blank", "noopener");
    }
  });
}

valueInput.addEventListener("input", syncCode);
pingButton.addEventListener("click", ping);
syncCode();
ping().finally(reportReady);
