const statusEl = document.getElementById("status");
const resultEl = document.getElementById("result");
const pingButton = document.getElementById("ping");
const valueInput = document.getElementById("value");
const codeValue = document.getElementById("code-value");

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
    renderRows([
      ["method", "app.ping"],
      ["message", "preview"],
      ["echo.value", readValue()],
      ["runtime", "browser"]
    ]);
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

function renderRows(rows) {
  resultEl.textContent = "";
  const table = document.createElement("table");
  const body = document.createElement("tbody");
  for (const [name, value] of rows) {
    const row = document.createElement("tr");
    const key = document.createElement("th");
    key.scope = "row";
    key.textContent = name;
    const val = document.createElement("td");
    val.textContent = String(value ?? "");
    row.append(key, val);
    body.append(row);
  }
  table.append(body);
  resultEl.append(table);
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

  renderRows(rows);
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

valueInput.addEventListener("input", syncCode);
pingButton.addEventListener("click", ping);
syncCode();
ping().finally(reportReady);
