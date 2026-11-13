const statusEl = document.getElementById("status");
const healthApp = document.getElementById("health-app");
const healthMeta = document.getElementById("health-meta");
const healthChecks = document.getElementById("health-checks");
const healthUptime = document.getElementById("health-uptime");
const healthRefresh = document.getElementById("health-refresh");
const urlOpenError = document.getElementById("url-open-error");
const urlOpenErrorUrl = document.getElementById("url-open-error-url");
const urlOpenErrorClose = document.getElementById("url-open-error-close");

function formatUptime(ms) {
  const totalSeconds = Math.max(0, Math.floor(Number(ms) / 1000));
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  return minutes > 0 ? `${minutes}m ${seconds}s` : `${seconds}s`;
}

function healthStatusLabel(status) {
  if (status === "ok") return "ok";
  if (status === "degraded") return "degraded";
  if (status === "failed") return "failed";
  return "unknown";
}

function setHealthState(status) {
  statusEl.textContent = healthStatusLabel(status);
  statusEl.className = "state";
  if (status === "ok") statusEl.classList.add("ok");
  if (status === "degraded") statusEl.classList.add("degraded");
  if (status === "failed") statusEl.classList.add("error");
}

function renderHealth(health) {
  setHealthState(health.status);
  healthApp.textContent = `${health.app.name} ${health.app.version}`;
  healthMeta.textContent =
    `Avelra ${health.runtime.version} · ${health.platform.os}/${health.platform.arch}`;
  healthUptime.textContent = `uptime ${formatUptime(health.runtime.uptimeMs)}`;
  healthChecks.textContent = "";
  for (const check of health.checks) {
    const row = document.createElement("div");
    row.className = "health-row";
    const id = document.createElement("span");
    id.textContent = check.id;
    const state = document.createElement("span");
    state.className = `health-check ${check.status}`;
    state.textContent = check.status;
    row.append(id, state);
    healthChecks.append(row);
  }
}

async function checkHealth() {
  if (typeof window.nativeCall !== "function") {
    statusEl.textContent = "preview";
    healthApp.textContent = "Avelra preview";
    healthMeta.textContent = "Open this app with `avelra run`.";
    return;
  }

  statusEl.textContent = "checking…";
  statusEl.className = "state";
  healthRefresh.disabled = true;
  try {
    const response = await window.nativeCall({ method: "app.healthCheck" });
    if (!response || response.success !== true) {
      throw new Error((response && response.error && response.error.message) ||
        "health check failed");
    }
    renderHealth(response.returnValue);
  } catch (error) {
    setHealthState("failed");
    healthApp.textContent = "Health check failed";
    healthMeta.textContent = String(error);
  } finally {
    healthRefresh.disabled = false;
  }
}

async function openUrl(url) {
  const response = await window.nativeCall({
    method: "os.openUrl",
    data: { url }
  });
  if (!response || response.success !== true) {
    throw new Error((response && response.error && response.error.message) ||
      "could not open URL");
  }
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
    try {
      await openUrl(link.href);
    } catch (error) {
      showUrlOpenError(link.href);
    }
  });
}

function reportReady() {
  if (typeof window.nativeCall !== "function") {
    return;
  }
  requestAnimationFrame(() => requestAnimationFrame(() => {
    window.nativeCall({ method: "app.ready" }).catch(() => {});
  }));
}

healthRefresh.addEventListener("click", checkHealth);
checkHealth().finally(reportReady);
