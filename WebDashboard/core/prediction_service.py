"""Sliding-window inference for ShockTrack's v0.3 Random Forest model."""

from collections import deque
from copy import deepcopy
from pathlib import Path
from typing import Optional, Sequence

import joblib
import numpy as np
import pandas as pd


class PredictionService:
    SENSOR_COLUMNS = ("acel_x", "acel_y", "acel_z", "gyro_x", "gyro_y", "gyro_z")

    def __init__(self, model_path: str | Path, stride_samples: Optional[int] = None):
        bundle = joblib.load(model_path)  # Only load model artifacts you trust.
        self.model = bundle["model"]
        self.feature_names = list(bundle["features"])
        self.window_samples = int(bundle["window_samples"])
        self.stride_samples = int(stride_samples or max(1, self.window_samples // 2))
        if self.window_samples < 2 or self.stride_samples < 1:
            raise ValueError("Window must contain >=2 samples and stride must be >=1")

        self._buffer = deque(maxlen=self.window_samples)
        self._since_prediction = 0
        self._has_predicted = False
        self._latest = None

    @property
    def latest_prediction(self) -> Optional[dict]:
        return deepcopy(self._latest)

    def reset(self) -> None:
        """Clear sample history after serial disconnection or a new session."""
        self._buffer.clear()
        self._since_prediction = 0
        self._has_predicted = False
        self._latest = None

    def add_sample(self, values: Sequence[float]) -> Optional[np.ndarray]:
        """Buffer one six-axis reading. Return a snapshot when inference is due."""
        if len(values) != 6:
            return None
        sample = np.asarray(values, dtype=float)
        if not np.isfinite(sample).all():
            return None

        self._buffer.append(sample)
        self._since_prediction += 1
        if len(self._buffer) < self.window_samples:
            return None
        if self._has_predicted and self._since_prediction < self.stride_samples:
            return None

        self._has_predicted = True
        self._since_prediction = 0
        return np.asarray(self._buffer, dtype=float)

    @classmethod
    def extract_features(cls, window: np.ndarray) -> dict[str, float]:
        """Exact feature definitions used in retrain_shocktrack_v03.py."""
        x = np.asarray(window, dtype=float)
        if x.ndim != 2 or x.shape[1] != 6 or x.shape[0] < 2:
            raise ValueError("Expected a window of at least two six-axis samples")
        mag = np.linalg.norm(x[:, :3], axis=1)
        gyromag = np.linalg.norm(x[:, 3:], axis=1)
        feat = {}
        for i, column in enumerate(cls.SENSOR_COLUMNS):
            v = x[:, i]
            feat[f"{column}_mean"] = float(v.mean())
            feat[f"{column}_std"] = float(v.std())
            feat[f"{column}_range"] = float(v.max() - v.min())
            feat[f"{column}_rms_delta"] = float(np.sqrt(np.mean(np.diff(v) ** 2)))
        for name, v in (("accel_magnitude", mag), ("gyro_magnitude", gyromag)):
            feat[f"{name}_mean"] = float(v.mean())
            feat[f"{name}_std"] = float(v.std())
            feat[f"{name}_max"] = float(v.max())
        for prefix, signal in (("accel", x[:, :3]), ("gyro", x[:, 3:])):
            for metric, values in (
                ("std", signal.std(axis=0)),
                ("range", np.ptp(signal, axis=0)),
                ("rms_delta", np.sqrt(np.mean(np.diff(signal, axis=0) ** 2, axis=0))),
            ):
                for j, value in enumerate(sorted(values)):
                    feat[f"{prefix}_sorted_{metric}_{j}"] = float(value)
        feat["accel_magnitude_rms_delta"] = float(np.sqrt(np.mean(np.diff(mag) ** 2)))
        feat["gyro_magnitude_rms_delta"] = float(np.sqrt(np.mean(np.diff(gyromag) ** 2)))
        return feat

    def predict_window(self, window: np.ndarray, timestamp: str) -> dict:
        """Classify a complete window (call from asyncio.to_thread in serial loop)."""
        features = self.extract_features(window)
        frame = pd.DataFrame([{name: features[name] for name in self.feature_names}])
        probabilities = self.model.predict_proba(frame)[0]
        index = int(np.argmax(probabilities))
        classes = [str(c) for c in self.model.classes_]
        result = {
            "type": "prediction",
            "timestamp": timestamp,
            "prediction": classes[index],
            "confidence": float(probabilities[index]),
            "probabilities": {label: float(p) for label, p in zip(classes, probabilities)},
            "window_samples": self.window_samples,
        }
        return result

    def publish(self, prediction: dict) -> None:
        """Update cached inference on the event-loop thread."""
        self._latest = deepcopy(prediction)
