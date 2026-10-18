
// ShockTrack Live Dashboard
// FastAPI endpoints: GET /status, POST /reconnect, WebSocket /ws

(() => {
    "use strict";

    function init() {
        const $ = (id) => document.getElementById(id);

        const ids = [
            "status", "reconnect", "v", "dot", "lastTs",
            "httpHost", "wsHost", "dev", "wsState",
            "c_ax", "c_ay", "c_az", "c_gx", "c_gy", "c_gz",
            "val_ax", "val_ay", "val_az", "val_gx", "val_gy", "val_gz"
        ];

        const missing = ids.filter((id) => !$(id));

        if (missing.length) {
            console.error(
                "ShockTrack: missing HTML elements:",
                missing.join(", ")
            );
            return;
        }

        // DOM elements
        const statusEl = $("status");
        const reconnectBtn = $("reconnect");
        const valueEl = $("v");
        const dotEl = $("dot");
        const lastTsEl = $("lastTs");

        const httpHostEl = $("httpHost");
        const wsHostEl = $("wsHost");
        const devEl = $("dev");
        const wsStateEl = $("wsState");

        // Server connection
        const WS_URL =
            `${location.protocol === "https:" ? "wss:" : "ws:"}//${location.host}/ws`;

        httpHostEl.textContent = location.origin;
        wsHostEl.textContent = WS_URL;

        // Configuration
        const DATA_TIMEOUT_MS = 1500;
        const RECONNECT_DELAY_MS = 2000;
        const SAMPLE_WINDOW = 240;

        const keys = ["ax", "ay", "az", "gx", "gy", "gz"];

        // Canvas elements
        const canvases = Object.fromEntries(
            keys.map((key) => [key, $(`c_${key}`)])
        );

        const labels = Object.fromEntries(
            keys.map((key) => [key, $(`val_${key}`)])
        );

        // Rolling sensor data buffers
        const series = Object.fromEntries(
            keys.map((key) => [
                key,
                new Float32Array(SAMPLE_WINDOW)
            ])
        );

        const contexts = {};
        const sizes = {};

        let nextIndex = 0;
        let sampleCount = 0;

        let ws = null;
        let reconnectTimer = null;
        let lastDataAt = 0;

        let deviceConnected = null;
        let statusRequestFailed = false;

        let needsRedraw = false;
        let frameRequested = false;

        // ------------------------------------
        // Utility functions
        // ------------------------------------

        function nowTime() {
            return new Date().toLocaleTimeString([], {
                hour: "2-digit",
                minute: "2-digit",
                second: "2-digit"
            });
        }

        function socketState() {
            if (!ws) return "closed";

            switch (ws.readyState) {
                case WebSocket.CONNECTING:
                    return "connecting";

                case WebSocket.OPEN:
                    return "open";

                case WebSocket.CLOSING:
                    return "closing";

                case WebSocket.CLOSED:
                    return "closed";

                default:
                    return "unknown";
            }
        }

        // ------------------------------------
        // Connection status
        // ------------------------------------

        function setIndicator(text, dot) {
            statusEl.textContent = `status: ${text}`;

            dotEl.classList.remove(
                "ok",
                "bad",
                "warn"
            );

            dotEl.classList.add(dot);
        }

        function refreshStatus() {
            const state = socketState();

            const hasRecentData =
                lastDataAt > 0 &&
                Date.now() - lastDataAt <= DATA_TIMEOUT_MS;

            wsStateEl.textContent = state;

            devEl.textContent =
                deviceConnected === null
                    ? "unknown"
                    : deviceConnected
                        ? "connected"
                        : "disconnected";

            if (deviceConnected === false) {
                setIndicator("device disconnected", "bad");
            }
            else if (state === "open" && hasRecentData) {
                setIndicator("streaming", "ok");
            }
            else if (state === "open") {
                setIndicator("waiting for data", "warn");
            }
            else if (state === "connecting") {
                setIndicator("connecting to WebSocket", "warn");
            }
            else if (statusRequestFailed) {
                setIndicator("server status unavailable", "bad");
            }
            else if (deviceConnected === true) {
                setIndicator("WebSocket disconnected", "bad");
            }
            else {
                setIndicator("connecting", "warn");
            }

            if (!hasRecentData && lastDataAt === 0) {
                valueEl.textContent = "(waiting for data)";
            }
        }

        // ------------------------------------
        // Sensor data parsing
        // ------------------------------------

        function parseLine(line) {
            const parts = String(line)
                .trim()
                .split(",")
                .map((part) => part.trim());

            if (
                parts.length !== 6 ||
                parts.some((part) => part === "")
            ) {
                return null;
            }

            const numbers = parts.map(Number);

            return numbers.every(Number.isFinite)
                ? numbers
                : null;
        }

        function pushSample(numbers) {
            keys.forEach((key, i) => {
                series[key][nextIndex] = numbers[i];
                labels[key].textContent = numbers[i].toFixed(2);
            });

            nextIndex =
                (nextIndex + 1) % SAMPLE_WINDOW;

            sampleCount = Math.min(
                SAMPLE_WINDOW,
                sampleCount + 1
            );

            requestRedraw();
        }

        // ------------------------------------
        // Canvas resizing
        // ------------------------------------

        function resizeCanvas(key) {
            const canvas = canvases[key];
            const rect = canvas.getBoundingClientRect();

            const cssWidth = Math.max(
                1,
                Math.floor(rect.width)
            );

            const cssHeight = Math.max(
                10,
                Math.floor(rect.height) ||
                parseInt(getComputedStyle(canvas).height, 10) ||
                120
            );

            const dpr = window.devicePixelRatio || 1;

            const pixelWidth = Math.floor(cssWidth * dpr);
            const pixelHeight = Math.floor(cssHeight * dpr);

            const old = sizes[key];

            if (
                old &&
                old.pixelWidth === pixelWidth &&
                old.pixelHeight === pixelHeight
            ) {
                return;
            }

            canvas.width = pixelWidth;
            canvas.height = pixelHeight;

            const ctx = canvas.getContext("2d");

            if (!ctx) return;

            ctx.setTransform(
                dpr, 0, 0, dpr, 0, 0
            );

            contexts[key] = ctx;

            sizes[key] = {
                width: cssWidth,
                height: cssHeight,
                pixelWidth,
                pixelHeight
            };
        }

        function resizeAllCanvases() {
            keys.forEach(resizeCanvas);
            requestRedraw();
        }

        // ------------------------------------
        // Graph scaling
        // ------------------------------------

        function getRange(key) {
            if (sampleCount === 0) {
                return { min: -1, max: 1 };
            }

            let min = Infinity;
            let max = -Infinity;

            for (let i = 0; i < sampleCount; i++) {
                const index =
                    (nextIndex - sampleCount + i + SAMPLE_WINDOW)
                    % SAMPLE_WINDOW;

                const value = series[key][index];

                min = Math.min(min, value);
                max = Math.max(max, value);
            }

            if (min === max) {
                min -= 1;
                max += 1;
            }

            return { min, max };
        }

        function drawYAxis(ctx, width, height, range) {
            const values = [
                range.max,
                (range.min + range.max) / 2,
                range.min
            ];

            if (range.min < 0 && range.max > 0) {
                values.push(0);
            }

            ctx.save();

            ctx.font =
                "11px ui-monospace, SFMono-Regular, Menlo, Consolas, monospace";

            ctx.fillStyle = "rgba(255,255,255,0.55)";
            ctx.strokeStyle = "rgba(255,255,255,0.14)";
            ctx.textBaseline = "middle";

            values.forEach((value) => {
                const y =
                    height -
                    (value - range.min) /
                    (range.max - range.min) * height;

                ctx.beginPath();
                ctx.moveTo(0, y);
                ctx.lineTo(6, y);
                ctx.stroke();

                ctx.fillText(
                    value.toFixed(2),
                    10,
                    y
                );
            });

            ctx.restore();
        }

        // ------------------------------------
        // Chart rendering
        // ------------------------------------

        function drawChart(key) {
            resizeCanvas(key);

            const ctx = contexts[key];
            const size = sizes[key];

            if (!ctx || !size) return;

            const { width, height } = size;

            ctx.clearRect(0, 0, width, height);

            // Grid
            ctx.lineWidth = 1;
            ctx.strokeStyle = "rgba(255,255,255,0.08)";

            for (let i = 1; i < 4; i++) {
                const y = height * i / 4;

                ctx.beginPath();
                ctx.moveTo(0, y);
                ctx.lineTo(width, y);
                ctx.stroke();
            }

            for (let i = 1; i < 6; i++) {
                const x = width * i / 6;

                ctx.beginPath();
                ctx.moveTo(x, 0);
                ctx.lineTo(x, height);
                ctx.stroke();
            }

            // Y-axis scaling
            const range = getRange(key);

            const yFor = (value) =>
                height -
                (value - range.min) /
                (range.max - range.min) * height;

            drawYAxis(ctx, width, height, range);

            // Zero line
            if (range.min <= 0 && range.max >= 0) {
                ctx.strokeStyle = "rgba(255,255,255,0.16)";

                ctx.beginPath();
                ctx.moveTo(0, yFor(0));
                ctx.lineTo(width, yFor(0));
                ctx.stroke();
            }

            if (sampleCount < 2) return;

            // Sensor data line
            ctx.lineWidth = 2;
            ctx.strokeStyle = "rgba(255,255,255,0.85)";
            ctx.beginPath();

            for (let i = 0; i < sampleCount; i++) {
                const index =
                    (nextIndex - sampleCount + i + SAMPLE_WINDOW)
                    % SAMPLE_WINDOW;

                const x =
                    i / (sampleCount - 1) * width;

                const y =
                    yFor(series[key][index]);

                if (i === 0) {
                    ctx.moveTo(x, y);
                } else {
                    ctx.lineTo(x, y);
                }
            }

            ctx.stroke();

            // Latest point indicator
            const lastIndex =
                (nextIndex - 1 + SAMPLE_WINDOW)
                % SAMPLE_WINDOW;

            ctx.fillStyle = "rgba(255,255,255,0.92)";

            ctx.beginPath();

            ctx.arc(
                Math.max(6, width - 6),
                yFor(series[key][lastIndex]),
                3,
                0,
                Math.PI * 2
            );

            ctx.fill();
        }

        // ------------------------------------
        // Efficient redraw scheduling
        // ------------------------------------

        function requestRedraw() {
            needsRedraw = true;

            if (frameRequested) return;

            frameRequested = true;

            requestAnimationFrame(() => {
                frameRequested = false;

                if (!needsRedraw) return;

                needsRedraw = false;

                keys.forEach(drawChart);
            });
        }

        // ------------------------------------
        // WebSocket connection
        // ------------------------------------

        function connectWS() {
            if (
                ws &&
                (
                    ws.readyState === WebSocket.OPEN ||
                    ws.readyState === WebSocket.CONNECTING
                )
            ) {
                return;
            }

            if (
                ws &&
                ws.readyState === WebSocket.CLOSING
            ) {
                scheduleReconnect();
                return;
            }

            if (reconnectTimer !== null) {
                clearTimeout(reconnectTimer);
                reconnectTimer = null;
            }

            const socket = new WebSocket(WS_URL);
            ws = socket;

            refreshStatus();

            socket.onopen = () => {
                if (ws !== socket) return;

                console.log(
                    "ShockTrack WebSocket connected"
                );

                refreshStatus();
            };

            socket.onmessage = (event) => {
                if (ws !== socket) return;

                const line = String(event.data ?? "");

                valueEl.textContent = line;

                lastTsEl.textContent =
                    `last: ${nowTime()}`;

                const numbers = parseLine(line);

                if (numbers) {
                    lastDataAt = Date.now();
                    pushSample(numbers);
                }

                refreshStatus();
            };

            socket.onerror = (error) => {
                if (ws !== socket) return;

                console.warn(
                    "ShockTrack WebSocket error",
                    error
                );

                refreshStatus();
            };

            socket.onclose = () => {
                if (ws !== socket) return;

                refreshStatus();
                scheduleReconnect();
            };
        }

        // ------------------------------------
        // Automatic WebSocket reconnection
        // ------------------------------------

        function scheduleReconnect() {
            if (reconnectTimer !== null) return;

            reconnectTimer = setTimeout(() => {
                reconnectTimer = null;
                connectWS();
            }, RECONNECT_DELAY_MS);
        }

        // ------------------------------------
        // Serial device status
        // ------------------------------------

        async function checkStatus() {
            try {
                const response = await fetch(
                    "/status",
                    { cache: "no-store" }
                );

                if (!response.ok) {
                    throw new Error(
                        `HTTP ${response.status}`
                    );
                }

                const data = await response.json();

                deviceConnected = Boolean(data.connected);
                statusRequestFailed = false;
            }
            catch (error) {
                console.warn(
                    "ShockTrack status check failed:",
                    error
                );

                deviceConnected = null;
                statusRequestFailed = true;
            }

            refreshStatus();
        }

        // ------------------------------------
        // Manual reconnect button
        // ------------------------------------

        reconnectBtn.addEventListener(
            "click",
            async () => {
                reconnectBtn.disabled = true;

                try {
                    const response = await fetch(
                        "/reconnect",
                        {
                            method: "POST",
                            cache: "no-store"
                        }
                    );

                    if (!response.ok) {
                        throw new Error(
                            `HTTP ${response.status}`
                        );
                    }

                    await checkStatus();
                    connectWS();
                }
                catch (error) {
                    console.error(
                        "ShockTrack reconnect failed:",
                        error
                    );

                    setIndicator(
                        "reconnect failed",
                        "bad"
                    );
                }
                finally {
                    reconnectBtn.disabled = false;
                }
            }
        );

        // ------------------------------------
        // Canvas observers
        // ------------------------------------

        if (typeof ResizeObserver !== "undefined") {
            const observer = new ResizeObserver(
                resizeAllCanvases
            );

            keys.forEach((key) => {
                observer.observe(canvases[key]);
            });
        }

        window.addEventListener(
            "resize",
            resizeAllCanvases
        );

        window.addEventListener(
            "orientationchange",
            resizeAllCanvases
        );

        // ------------------------------------
        // Application startup
        // ------------------------------------

        resizeAllCanvases();
        refreshStatus();

        connectWS();
        checkStatus();

        // Poll serial connection status
        setInterval(checkStatus, 5000);

        // Check if telemetry is still arriving
        setInterval(refreshStatus, 250);
    }

    // ------------------------------------
    // Wait for HTML to finish loading
    // ------------------------------------

    if (document.readyState === "loading") {
        document.addEventListener(
            "DOMContentLoaded",
            init,
            { once: true }
        );
    }
    else {
        init();
    }
})();
