// ShockTrack dashboard — GET /status, POST /reconnect, WS /ws
(() => {
    "use strict";

    function init() {
        const $ = id => document.getElementById(id);
        const names = [
            "status", "reconnect", "v", "dot", "lastTs", "httpHost", "wsHost", "dev", "wsState",
            "prediction", "predictionNote", "predictionCard"
        ];
        const axes = {
            ax: "acel_x", ay: "acel_y", az: "acel_z",
            gx: "gyro_x", gy: "gyro_y", gz: "gyro_z"
        };
        const missing = [...names, ...Object.keys(axes).flatMap(id => [`c_${id}`, `val_${id}`])].filter(id => !$(id));
        if (missing.length) return console.error("ShockTrack missing elements:", missing);

        const ui = Object.fromEntries(names.map(id => [id, $(id)]));
        const N = 240, TIMEOUT = 1500, RETRY = 2000;
        const url = `${location.protocol === "https:" ? "wss:" : "ws:"}//${location.host}/ws`;
        const charts = Object.entries(axes).map(([id, key]) => ({
            key, canvas: $(`c_${id}`), label: $(`val_${id}`),
            data: new Float32Array(N), ctx: null, width: 0, height: 0
        }));
        let ws = null, retryTimer = null, lastData = 0, device = null, statusFailed = false;
        let prediction = null, next = 0, count = 0, redrawPending = false;
        ui.httpHost.textContent = location.origin;
        ui.wsHost.textContent = url;

        const wsState = () => ["connecting", "open", "closing", "closed"][ws?.readyState ?? 3];
        function indicator(message, color) {
            ui.status.textContent = `status: ${message}`;
            ui.dot.classList.remove("ok", "bad", "warn");
            ui.dot.classList.add(color);
        }
        function showPrediction(label, state, note) {
            if (ui.prediction.textContent !== label) ui.prediction.textContent = label;
            if (ui.predictionNote.textContent !== note) ui.predictionNote.textContent = note;
            ui.predictionCard.dataset.state = state;
        }
        function refresh() {
            const state = wsState(), recent = lastData && Date.now() - lastData <= TIMEOUT;
            ui.wsState.textContent = state;
            ui.dev.textContent = device === null ? "unknown" : device ? "connected" : "disconnected";
            const [message, color] = state === "open" && recent ? ["streaming", "ok"]
                : device === false ? ["device disconnected", "bad"]
                    : state === "open" ? ["waiting for data", "warn"]
                        : state === "connecting" ? ["connecting to WebSocket", "warn"]
                            : statusFailed ? ["server status unavailable", "bad"]
                                : device === true ? ["WebSocket disconnected", "bad"] : ["connecting", "warn"];
            indicator(message, color);
            if (!lastData) ui.v.textContent = "(waiting for data)";

            if (state !== "open")
                showPrediction("Disconnected", "stale", "Waiting for the WebSocket connection.");
            else if (!lastData)
                showPrediction("Waiting for data", "waiting", "Waiting for a valid sensor sample.");
            else if (!recent)
                showPrediction("Stream paused", "stale", "Waiting for fresh sensor data.");
            else if (prediction !== null)
                showPrediction(prediction, "live", "Latest model prediction.");
            else
                showPrediction("Waiting for prediction", "waiting", "Sensor data is live; no prediction is available yet.");
        }
        function resetStream() {
            lastData = 0;
            prediction = null;
            next = count = 0;
            charts.forEach(chart => { chart.data.fill(0); chart.label.textContent = "—"; });
            ui.lastTs.textContent = "last: —";
            redraw();
        }
        function receive(text) {
            let sample;
            try { sample = JSON.parse(text); } catch { return; }
            if (sample === null || typeof sample !== "object" || Array.isArray(sample)) return;
            const values = charts.map(chart => sample[chart.key]);
            if (!values.every(Number.isFinite)) return;

            charts.forEach((chart, i) => {
                chart.data[next] = values[i];
                chart.label.textContent = values[i].toFixed(2);
            });
            prediction = typeof sample.prediction === "string" && sample.prediction.trim()
                ? sample.prediction.trim() : null;
            ui.lastTs.textContent = typeof sample.timestamp === "string" && sample.timestamp.trim()
                ? `last: ${sample.timestamp}` : `last received: ${new Date().toLocaleTimeString()}`;
            ui.v.textContent = text;
            lastData = Date.now();
            next = (next + 1) % N;
            count = Math.min(count + 1, N);
            redraw();
            refresh();
        }

        function resize(chart) {
            const { canvas } = chart, rect = canvas.getBoundingClientRect();
            const width = Math.max(1, Math.floor(rect.width));
            const height = Math.max(10, Math.floor(rect.height) || parseInt(getComputedStyle(canvas).height, 10) || 120);
            const dpr = window.devicePixelRatio || 1;
            const pixelWidth = Math.floor(width * dpr), pixelHeight = Math.floor(height * dpr);
            if (canvas.width !== pixelWidth || canvas.height !== pixelHeight) {
                canvas.width = pixelWidth;
                canvas.height = pixelHeight;
            }
            chart.ctx ||= canvas.getContext("2d");
            chart.ctx?.setTransform(dpr, 0, 0, dpr, 0, 0);
            chart.width = width;
            chart.height = height;
        }
        function draw(chart) {
            resize(chart);
            const { ctx, width: w, height: h, data } = chart;
            if (!ctx) return;
            ctx.clearRect(0, 0, w, h);
            const at = i => data[(next - count + i + N) % N];
            let min = Infinity, max = -Infinity;
            for (let i = 0; i < count; i++) { min = Math.min(min, at(i)); max = Math.max(max, at(i)); }
            if (!count) { min = -1; max = 1; }
            if (min === max) { min--; max++; }
            const y = value => h - (value - min) / (max - min) * h;
            const line = (x1, y1, x2, y2) => {
                ctx.beginPath(); ctx.moveTo(x1, y1); ctx.lineTo(x2, y2); ctx.stroke();
            };

            ctx.lineWidth = 1;
            ctx.strokeStyle = "rgba(255,255,255,.08)";
            for (let i = 1; i < 4; i++) line(0, h * i / 4, w, h * i / 4);
            for (let i = 1; i < 6; i++) line(w * i / 6, 0, w * i / 6, h);
            ctx.font = "11px ui-monospace, SFMono-Regular, Menlo, Consolas, monospace";
            ctx.textBaseline = "middle";
            ctx.fillStyle = "rgba(255,255,255,.55)";
            ctx.strokeStyle = "rgba(255,255,255,.14)";
            const ticks = [max, (min + max) / 2, min];
            if (min < 0 && max > 0) ticks.push(0);
            ticks.forEach(v => { line(0, y(v), 6, y(v)); ctx.fillText(v.toFixed(2), 10, y(v)); });
            if (min <= 0 && max >= 0) {
                ctx.strokeStyle = "rgba(255,255,255,.16)";
                line(0, y(0), w, y(0));
            }
            if (count < 2) return;

            ctx.lineWidth = 2;
            ctx.strokeStyle = "rgba(255,255,255,.85)";
            ctx.beginPath();
            for (let i = 0; i < count; i++) {
                const x = i / (count - 1) * w;
                if (!i) ctx.moveTo(x, y(at(i))); else ctx.lineTo(x, y(at(i)));
            }
            ctx.stroke();
            ctx.fillStyle = "rgba(255,255,255,.92)";
            ctx.beginPath();
            ctx.arc(Math.max(6, w - 6), y(at(count - 1)), 3, 0, Math.PI * 2);
            ctx.fill();
        }
        function redraw() {
            if (redrawPending) return;
            redrawPending = true;
            requestAnimationFrame(() => { redrawPending = false; charts.forEach(draw); });
        }
        function resizeAll() { charts.forEach(resize); redraw(); }

        function reconnectLater() {
            if (retryTimer !== null) return;
            retryTimer = setTimeout(() => { retryTimer = null; connect(); }, RETRY);
        }
        function connect() {
            if (ws?.readyState === WebSocket.OPEN || ws?.readyState === WebSocket.CONNECTING) return;
            if (ws?.readyState === WebSocket.CLOSING) return reconnectLater();
            clearTimeout(retryTimer);
            retryTimer = null;
            resetStream();
            const socket = new WebSocket(url);
            ws = socket;
            refresh();
            socket.onopen = () => { if (ws === socket) refresh(); };
            socket.onmessage = event => { if (ws === socket) receive(String(event.data ?? "")); };
            socket.onerror = error => { if (ws === socket) { console.warn("WebSocket:", error); refresh(); } };
            socket.onclose = () => { if (ws === socket) { refresh(); reconnectLater(); } };
        }

        const refreshConnectionsButton = $("refreshConnections");
        const connectionsStatus = $("connectionsStatus");
        const connectionsList = $("connectionsList");

        refreshConnectionsButton.addEventListener("click", async () => {
            refreshConnectionsButton.disabled = true;
            connectionsStatus.textContent = "Loading connections…";

            try {
                const response = await request("/connections");
                const { count, connections } = await response.json();

                const rows = connections.map(client => {
                    const row = document.createElement("li");
                    row.className = "kv";

                    const address = document.createElement("div");
                    address.className = "v";
                    address.textContent = `${client.ip} · ${client.id}`;

                    const details = document.createElement("div");
                    details.className = "k";
                    const connectedAt = new Date(client.connected_at).toLocaleString();
                    details.textContent = `Connected ${connectedAt} · ${client.duration_seconds}s`;

                    row.append(address, details);
                    return row;
                });

                connectionsList.replaceChildren(...rows);
                connectionsStatus.textContent = count === 0
                    ? "No active connections."
                    : `${count} active ${count === 1 ? "connection" : "connections"}`;
            } catch {
                connectionsStatus.textContent = connectionsList.childElementCount
                    ? "Refresh failed. Showing the last loaded list."
                    : "Could not load connections. Try again.";
            } finally {
                refreshConnectionsButton.disabled = false;
            }
        });

        async function request(path, method = "GET") {
            const res = await fetch(path, { method, cache: "no-store" });
            if (!res.ok) throw new Error(`HTTP ${res.status}`);
            return res;
        }
        async function checkStatus() {
            try {
                const res = await request("/status"), status = await res.json();
                if (typeof status?.connected !== "boolean") throw new Error("Invalid server status");
                device = status.connected;
                statusFailed = false;
            } catch (error) {
                console.warn("Status check:", error);
                device = null;
                statusFailed = true;
            }
            refresh();
        }
        ui.reconnect.addEventListener("click", async () => {
            ui.reconnect.disabled = true;
            try {
                await request("/reconnect", "POST");
                await checkStatus();
                connect();
            } catch (error) {
                console.error("Reconnect:", error);
                indicator("reconnect failed", "bad");
            } finally { ui.reconnect.disabled = false; }
        });

        if (typeof ResizeObserver !== "undefined") {
            const observer = new ResizeObserver(resizeAll);
            charts.forEach(chart => observer.observe(chart.canvas));
        }
        window.addEventListener("resize", resizeAll);
        window.addEventListener("orientationchange", resizeAll);
        resizeAll();
        refresh();
        connect();
        checkStatus();
        setInterval(checkStatus, 5000);
        setInterval(refresh, 250);
    }
    if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init, { once: true });
    else init();
})();