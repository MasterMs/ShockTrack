# ShockTrack live ML model

Copy the trusted model exported from `ShockTrack_6Class_Exploration_v03.ipynb` into this directory as:

`WebDashboard/models/shocktrack_v03_six_class.joblib`

The application loads the model on startup if it exists. Otherwise live ML is disabled, while CSV recording and the existing `/ws` telemetry continue working.

Install from the Python environment used to run `pyTrack.py`:

```bash
pip install numpy pandas scikit-learn joblib
```

Live inference uses the **exact 22-sample training feature definitions**, with predictions every 11 new valid readings (after the first 22 samples).

### API

- `GET /prediction`: returns `{"enabled": true, "prediction": {...}}` (or `prediction: null` while collecting a window).
- `WS /ws/predictions`: emits a JSON object with `type`, `timestamp`, `prediction`, `confidence`, `probabilities`, and `window_samples`.
- `WS /ws`: unchanged six-value raw CSV stream for existing clients.

The `confidence` field is the largest Random Forest class probability; it is **not calibrated reliability**. The model is exploratory and trained on very few independent driving sessions, so treat live labels as unvalidated indicators, not safety alerts.

Only load `.joblib` files you created or trust: loading arbitrary pickle/joblib files can execute code.
