async function main() {
  const response = await window.avelra.app.ping({ value: 42 });
  document.getElementById("status").textContent = "webview_bind works";
  document.getElementById("result").textContent = JSON.stringify(response, null, 2);
}

function reportReady() {
  // Wait for the first painted frame before dismissing the loading overlay.
  requestAnimationFrame(() => requestAnimationFrame(() => {
    window.avelra.app.ready().catch(() => {});
  }));
}

main().catch((error) => {
  document.getElementById("status").textContent = "bridge error";
  document.getElementById("result").textContent = String(error);
}).finally(reportReady);
