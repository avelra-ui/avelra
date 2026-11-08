// Minimal event bus injected by the Avelra client template.
(() => {
  const handlers = new Map();

  window.nativeEvents = {
    on(name, handler) {
      if (typeof handler !== "function") return () => {};
      const list = handlers.get(name) || [];
      list.push(handler);
      handlers.set(name, list);
      return () => this.off(name, handler);
    },
    off(name, handler) {
      const list = handlers.get(name);
      if (!list) return;
      handlers.set(name, list.filter((item) => item !== handler));
    }
  };

  window.__avelraEmit = (event) => {
    if (!event || typeof event.name !== "string") return;
    for (const handler of [...(handlers.get(event.name) || [])]) {
      try {
        handler(event.data);
      } catch (error) {
        console.error("nativeEvents handler failed", error);
      }
    }
  };
})();
