(() => {
    'use strict';
    const $ = id => document.getElementById(id);
    const canvas = $('overlay'), ctx = canvas.getContext('2d'), video = $('video');
    const keys = ['accel_x', 'accel_y', 'accel_z', 'gyro_x', 'gyro_y', 'gyro_z'];
    // Normalize the original serial spelling and common short axis names.
    const aliases = { accel_x: ['accel_x', 'acel_x', 'ax'], accel_y: ['accel_y', 'acel_y', 'ay'], accel_z: ['accel_z', 'acel_z', 'az'], gyro_x: ['gyro_x', 'gx'], gyro_y: ['gyro_y', 'gy'], gyro_z: ['gyro_z', 'gz'] };
    function parseSample(raw) {
        let data;
        try { data = JSON.parse(raw); } catch { throw Error('Message is not valid JSON.'); }
        if (!data || typeof data !== 'object' || Array.isArray(data)) throw Error('Expected a JSON object with sensor fields.');
        const axes = {};
        for (const key of keys) {
            const name = aliases[key].find(alias => Object.hasOwn(data, alias));
            if (!name) throw Error(`Missing ${key}. Received fields: ${Object.keys(data).join(', ') || '(none)'}`);
            const value = data[name];
            if (!['number', 'string'].includes(typeof value) || (typeof value === 'string' && !value.trim()) || !Number.isFinite(Number(value))) throw Error(`${name} must be a finite number; received ${JSON.stringify(value)}.`);
            axes[key] = Number(value);
        }
        return { ...axes, timestamp: ['string', 'number'].includes(typeof data.timestamp) ? String(data.timestamp) : '—', prediction: ['string', 'number'].includes(typeof data.prediction) ? String(data.prediction) : null };
    }
    const storage = { get: key => { try { return localStorage.getItem(key) } catch { return null } }, set: (key, value) => { try { localStorage.setItem(key, value) } catch { } } };
    let socket = null, retry = null, wanted = false, endpoint = '';
    let stream = null, cameraBusy = false, disposed = false, cameraRotation = 0;
    let sample = null, received = 0, arrivals = [], invalid = 0, lastParseError = '';
    let recorder = null, recordingStream = null, chunks = [], recordStart = 0, lastDraw = 0;
    const recordings = new Set();
    $('url').value = storage.get('shocktrack-camera-url') || `${location.protocol === 'https:' ? 'wss:' : 'ws:'}//${location.host}/ws`;
    const say = text => { $('notice').textContent = text; };
    const clearSample = () => { sample = null; received = 0; arrivals = []; };
    function disconnect() {
        wanted = false; clearTimeout(retry); retry = null;
        const old = socket; socket = null; if (old) old.close();
        clearSample(); $('url').disabled = false; $('connect').textContent = 'Connect'; $('wsStatus').textContent = 'Disconnected';
    }
    function openSocket() {
        if (!wanted) return;
        $('wsStatus').textContent = 'Connecting…';
        let ws;
        try { ws = new WebSocket(endpoint); } catch (error) { disconnect(); say(error.message); return; }
        socket = ws;
        ws.onopen = () => { if (socket !== ws) return; clearSample(); invalid = 0; lastParseError = ''; $('diagnostics').hidden = true; $('wsStatus').textContent = 'Connected · waiting for sensor data'; };
        ws.onmessage = event => {
            if (socket !== ws) return;
            try {
                sample = parseSample(event.data); lastParseError = '';
                received = performance.now(); arrivals.push(received); arrivals = arrivals.filter(t => received - t < 2000);
            } catch (error) { invalid++; lastParseError = error.message; $('diagnostics').hidden = false; $('parseError').textContent = lastParseError; $('lastMessage').textContent = String(event.data).slice(0, 4000); $('wsStatus').textContent = lastParseError; }
        };
        ws.onerror = () => { if (socket === ws) $('wsStatus').textContent = 'Socket error · check address and server'; };
        ws.onclose = () => {
            if (socket !== ws) return;
            socket = null; clearSample();
            if (wanted) { $('wsStatus').textContent = 'Disconnected · retrying in 2 seconds'; retry = setTimeout(openSocket, 2000); }
        };
    }
    $('connect').onclick = () => {
        if (wanted) { disconnect(); return; }
        try {
            const url = new URL($('url').value.trim());
            if (!['ws:', 'wss:'].includes(url.protocol)) throw Error('Enter a ws:// or wss:// address.');
            if (location.protocol === 'https:' && url.protocol === 'ws:') throw Error('Use wss:// on HTTPS, or open this app from localhost for a ws:// server.');
            endpoint = url.href; storage.set('shocktrack-camera-url', endpoint); wanted = true; $('url').disabled = true; $('connect').textContent = 'Disconnect'; say(''); openSocket();
        } catch (error) { say(error.message); }
    };
    async function listCameras() {
        try {
            const devices = (await navigator.mediaDevices.enumerateDevices()).filter(d => d.kind === 'videoinput');
            const selected = stream?.getVideoTracks()[0]?.getSettings().deviceId || $('cameras').value;
            $('cameras').replaceChildren(new Option('Default camera', ''), ...devices.filter(d => d.deviceId).map((d, i) => new Option(d.label || `Camera ${i + 1}`, d.deviceId)));
            if ([...$('cameras').options].some(o => o.value === selected)) $('cameras').value = selected;
        } catch { /* Keep the default camera available if enumeration is restricted. */ }
    }
    function updateRecordButton() { $('record').disabled = !stream || !window.MediaRecorder || !canvas.captureStream || !!(recorder && recorder.state === 'inactive'); }
    function stopCamera() {
        if (recorder?.state === 'recording') recorder.stop();
        if (stream) stream.getTracks().forEach(track => track.stop());
        stream = null; video.srcObject = null; $('camera').textContent = 'Start camera'; $('camStatus').textContent = 'Camera off'; updateRecordButton();
    }
    async function startCamera() {
        if (cameraBusy) return;
        if (!window.isSecureContext || !navigator.mediaDevices?.getUserMedia) { say('Camera access needs HTTPS or http://localhost. See connection help below.'); return; }
        cameraBusy = true; $('camera').disabled = true; $('cameras').disabled = true; $('camStatus').textContent = 'Requesting camera access…'; say('');
        try {
            const device = $('cameras').value;
            const next = await navigator.mediaDevices.getUserMedia({ audio: false, video: { ...(device ? { deviceId: { exact: device } } : { facingMode: { ideal: 'environment' } }), width: { ideal: 1920 }, height: { ideal: 1080 } } });
            if (disposed) { next.getTracks().forEach(t => t.stop()); return; }
            stream = next; video.srcObject = stream; await video.play();
            stream.getVideoTracks()[0].addEventListener('ended', () => { stopCamera(); say('Camera access ended. Start the camera to resume.'); });
            $('camera').textContent = 'Stop camera'; $('camStatus').textContent = 'Camera on'; await listCameras();
        } catch (error) { stopCamera(); say(`Camera could not start: ${error.message}`); }
        finally { cameraBusy = false; $('camera').disabled = false; $('cameras').disabled = false; updateRecordButton(); }
    }
    $('camera').onclick = () => stream ? stopCamera() : startCamera();
    $('rotate').onclick = () => {
        cameraRotation = (cameraRotation + 90) % 360;
        $('rotate').textContent = `Rotate (${cameraRotation}°)`;
        $('rotate').title = `Rotate camera clockwise; current orientation: ${cameraRotation}°`;
    };
    $('cameras').onchange = async () => { if (stream) { stopCamera(); await startCamera(); } };
    navigator.mediaDevices?.addEventListener?.('devicechange', listCameras);
    function panel(x, y, width, height) {
        ctx.fillStyle = 'rgba(8,14,22,.86)';
        ctx.fillRect(x, y, width, height);
    }
    function text(value, x, y, size = 22, color = '#edf4fa', weight = 500) { ctx.font = `${weight} ${size}px system-ui,sans-serif`; ctx.fillStyle = color; ctx.fillText(String(value), x, y); }
    function fit(value, x, y, maxWidth, size, color, weight = 600) {
        let s = size; ctx.font = `${weight} ${s}px system-ui,sans-serif`;
        while (ctx.measureText(String(value)).width > maxWidth && s > 16) { s--; ctx.font = `${weight} ${s}px system-ui,sans-serif`; }
        let str = String(value); while (ctx.measureText(str).width > maxWidth && str.length > 1) str = str.slice(0, -2) + '…'; text(str, x, y, s, color, weight);
    }
    function draw(now) {
        if (disposed) return; requestAnimationFrame(draw);
        if (now - lastDraw < 1000 / 30) return; lastDraw = now;
        const portrait = matchMedia('(max-width:760px)').matches;
        if (!recorder && canvas.height !== (portrait ? 960 : 720)) { canvas.width = portrait ? 720 : 1280; canvas.height = portrait ? 960 : 720; }
        canvas.style.aspectRatio = `${canvas.width}/${canvas.height}`;
        const W = canvas.width, H = canvas.height, age = received ? now - received : Infinity, live = !!sample && age < 1500;
        const narrow = W < 1000;
        ctx.fillStyle = '#0c141e'; ctx.fillRect(0, 0, W, H);
        if (stream && video.readyState >= 2) {
            const sideways = cameraRotation % 180 !== 0;
            const scale = Math.min(W / (sideways ? video.videoHeight : video.videoWidth), H / (sideways ? video.videoWidth : video.videoHeight));
            const w = video.videoWidth * scale, h = video.videoHeight * scale;
            ctx.save(); ctx.translate(W / 2, H / 2); ctx.rotate(cameraRotation * Math.PI / 180);
            ctx.drawImage(video, -w / 2, -h / 2, w, h); ctx.restore();
        } else {
            ctx.textAlign = 'center';
            text('Camera off', W / 2, H * .43, 30, '#bacbd9', 500);
            ctx.textAlign = 'left';
        }
        panel(28, 28, 330, 80); text('ShockTrack', 48, 61, 23, '#edf4fa', 650); text(new Date().toLocaleTimeString(), 48, 91, 21, '#bacbd9');
        const state = live ? 'Telemetry live' : sample ? 'Telemetry stale' : socket?.readyState === WebSocket.OPEN ? 'Waiting for data' : wanted ? 'Connecting' : 'Disconnected';
        $('cameraDot').className = `dot ${live ? 'ok' : wanted ? 'warn' : 'bad'}`;
        panel(W - 350, 28, 322, 80); text(state, W - 330, 62, 23, live ? '#33d17a' : '#f6be83', 700);
        const recent = arrivals.filter(t => now - t < 2000), hz = recent.length > 1 ? (recent.length - 1) * 1000 / (recent.at(-1) - recent[0]) : 0;
        text(sample ? `${Math.min(age / 1000, 999).toFixed(1)}s since sample · ${hz.toFixed(0)} Hz` : 'No sensor samples yet', W - 330, 92, 19, '#bacbd9');
        const top = H - (narrow ? 340 : 236); panel(28, top, W - 56, narrow ? 312 : 208);
        text('Driving prediction', 50, top + 36, 20, '#9cb2c4', 600);
        const prediction = live ? (sample.prediction || 'Building prediction window…') : sample ? 'Waiting for fresh data' : '—';
        fit(prediction, 50, top + 88, W - 104, 40, live ? '#33d17a' : '#a2b2bf', 700);
        ctx.globalAlpha = live ? 1 : .5;
        const columns = narrow ? 3 : 6, col = (W - 104) / columns;
        keys.forEach((key, i) => { const x = 50 + (i % columns) * col, y = top + 132 + Math.floor(i / columns) * 80; text(key.replace('_', ' ').toUpperCase(), x, y, narrow ? 24 : 19, '#9cb2c4'); fit(sample ? sample[key].toFixed(3) : '—', x, y + 40, col - 14, narrow ? 36 : 32, '#edf4fa', 600); });
        ctx.globalAlpha = 1;
        fit(`Sensor time  ${sample?.timestamp || '—'}  ·  stream units`, 50, H - 40, W - 104, 16, '#8fa6b9', 400);
        if (recorder?.state === 'recording') {
            const seconds = Math.floor((now - recordStart) / 1000), elapsed = `${String(Math.floor(seconds / 60)).padStart(2, '0')}:${String(seconds % 60).padStart(2, '0')}`;
            panel(28, 126, 180, 50); text(`● REC ${elapsed}`, 44, 159, 22, '#ff9292', 700);
        }
        if (socket?.readyState === WebSocket.OPEN) $('wsStatus').textContent = (live ? `Receiving sensor data · ${hz.toFixed(0)} Hz` : sample ? 'Connected · sensor stream is stale' : 'Connected · waiting for sensor data') + (lastParseError ? ` · ${lastParseError}` : invalid ? ` · ${invalid} earlier messages ignored` : '');
    }
    $('record').onclick = () => {
        if (recorder) { if (recorder.state === 'recording') { recorder.stop(); $('record').disabled = true; } return; }
        if (!stream) return;
        try {
            const type = ['video/webm;codecs=vp9', 'video/webm;codecs=vp8', 'video/webm', 'video/mp4'].find(t => MediaRecorder.isTypeSupported(t));
            recordingStream = canvas.captureStream(30); chunks = [];
            const current = new MediaRecorder(recordingStream, { ...(type ? { mimeType: type } : {}), videoBitsPerSecond: 6000000 }); recorder = current;
            current.ondataavailable = event => { if (event.data.size) chunks.push(event.data); };
            current.onerror = () => { say('Recording failed. Stop and try again.'); if (current.state === 'recording') current.stop(); };
            current.onstop = () => {
                const blob = new Blob(chunks, { type: current.mimeType || type || 'video/webm' });
                if (blob.size && !disposed) {
                    const url = URL.createObjectURL(blob), link = document.createElement('a'); recordings.add(url);
                    const ext = blob.type.includes('mp4') ? 'mp4' : 'webm'; link.href = url; link.download = `shocktrack-${new Date().toISOString().replace(/[:.]/g, '-')}.${ext}`;
                    link.className = 'download'; link.textContent = `Download recording · ${(blob.size / 1024 / 1024).toFixed(1)} MB`; $('downloads').prepend(link); link.click();
                }
                recordingStream?.getTracks().forEach(t => t.stop()); recordingStream = null; recorder = null; chunks = [];
                $('record').textContent = 'Record'; $('record').setAttribute('aria-pressed', 'false'); $('recordStatus').textContent = 'Recording ready to download.'; updateRecordButton();
            };
            current.start(1000); recordStart = performance.now(); $('record').textContent = 'Stop recording'; $('record').setAttribute('aria-pressed', 'true');
            $('recordStatus').textContent = 'Keep this tab visible. Stop recording to download the video.'; say('');
        } catch (error) { recordingStream?.getTracks().forEach(t => t.stop()); recordingStream = null; recorder = null; say(`Recording unavailable: ${error.message}`); updateRecordButton(); }
    };
    $('fullscreen').onclick = async () => { try { if (document.fullscreenElement) await document.exitFullscreen(); else await $('stage').requestFullscreen(); } catch { say('Fullscreen is unavailable in this browser.'); } };
    document.addEventListener('visibilitychange', () => { if (document.hidden && recorder?.state === 'recording') say('Keep this tab visible: browsers may pause camera rendering in the background.'); });
    window.addEventListener('beforeunload', event => { if (recorder) { event.preventDefault(); event.returnValue = ''; } });
    window.addEventListener('pagehide', () => { disposed = true; disconnect(); stopCamera(); recordings.forEach(url => URL.revokeObjectURL(url)); });
    window.addEventListener('pageshow', event => { if (event.persisted) { disposed = false; requestAnimationFrame(draw); } });
    if (!window.MediaRecorder || !canvas.captureStream) $('recordStatus').textContent = 'This browser supports live overlay only; recording is unavailable.';
    requestAnimationFrame(draw);
})();