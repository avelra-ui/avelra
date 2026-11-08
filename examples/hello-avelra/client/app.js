async function main() {
  const response = await window.nativeCall({
    method: "app.ping",
    data: { value: 42 }
  });
  document.getElementById("status").textContent = "webview_bind works";
  document.getElementById("result").textContent = JSON.stringify(response, null, 2);
}

function reportReady() {
  // Wait for the first painted frame before dismissing the loading overlay.
  requestAnimationFrame(() => requestAnimationFrame(() => {
    window.nativeCall({ method: "app.ready" }).catch(() => {});
  }));
}

main().catch((error) => {
  document.getElementById("status").textContent = "bridge error";
  document.getElementById("result").textContent = String(error);
}).finally(reportReady);
