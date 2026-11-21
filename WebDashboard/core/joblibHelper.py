from collections import deque
from pathlib import Path

import joblib
import numpy as np
import pandas as pd


class JoblibHelper:
    FEATURES = (
        "acel_x", "acel_y", "acel_z",
        "gyro_x", "gyro_y", "gyro_z",
    )

    def __init__(self, model_path: str | Path):
        bundle = joblib.load(Path(model_path))

        if not isinstance(bundle, dict):
            raise TypeError("Expected the notebook's exported model bundle.")

        required = {"model", "features", "sensors", "window_samples"}
        missing = required - bundle.keys()

        if missing:
            raise ValueError(
                f"Model bundle is missing: {sorted(missing)}. "
                f"Available keys: {list(bundle)}"
            )

        self.model = bundle["model"]
        self.feature_names = list(bundle["features"])
        self.sensors = list(bundle["sensors"])
        self.window_samples = int(bundle["window_samples"])

        if not callable(getattr(self.model, "predict", None)):
            raise TypeError("bundle['model'] must contain the fitted pipeline.")

        if self.sensors != list(self.FEATURES):
            raise ValueError(f"Unexpected sensor order: {self.sensors}")

        if self.window_samples < 2:
            raise ValueError("Window must contain at least two samples.")

        # Validate feature names before starting sensor capture.
        example = self._extract_features(
            np.zeros((self.window_samples, 6))
        )

        if (
            len(set(self.feature_names)) != len(self.feature_names)
            or not set(self.feature_names) <= example.keys()
        ):
            raise ValueError("Bundle uses an unsupported feature contract.")

        self.reset()

    def reset(self) -> None:
        self.buffer = deque(maxlen=self.window_samples)

    def _extract_features(self, window: np.ndarray) -> dict:
        accel = window[:, :3]
        gyro = window[:, 3:]

        accel_mag = np.linalg.norm(accel, axis=1)
        gyro_mag = np.linalg.norm(gyro, axis=1)

        features = {
            "accel_magnitude_std": float(accel_mag.std()),
            "gyro_magnitude_std": float(gyro_mag.std()),
        }

        for name, axes in (("accel", accel), ("gyro", gyro)):
            summaries = {
                "std": axes.std(axis=0),
                "range": np.ptp(axes, axis=0),
                "rms_delta": np.sqrt(
                    np.mean(np.diff(axes, axis=0) ** 2, axis=0)
                ),
            }

            for metric, values in summaries.items():
                for index, value in enumerate(sorted(values)):
                    features[f"{name}_sorted_{metric}_{index}"] = float(value)

        features["accel_magnitude_rms_delta"] = float(
            np.sqrt(np.mean(np.diff(accel_mag) ** 2))
        )
        features["gyro_magnitude_rms_delta"] = float(
            np.sqrt(np.mean(np.diff(gyro_mag) ** 2))
        )

        features.update({
            f"{sensor}_mean": float(window[:, index].mean())
            for index, sensor in enumerate(self.sensors)
        })

        return features

    def predict(self, sample: dict[str, float]) -> dict:
        row = np.asarray(
            [sample[sensor] for sensor in self.sensors],
            dtype=float,
        )

        if not np.isfinite(row).all():
            self.reset()
            raise ValueError("Sensor values must be finite.")

        self.buffer.append(row)

        if len(self.buffer) < self.window_samples:
            return {"prediction": None}

        features = self._extract_features(np.asarray(self.buffer))

        # Supply the complete ordered feature set.
        # Scaling and feature selection happen inside the pipeline.
        values = pd.DataFrame(
            [features],
            columns=self.feature_names,
        )

        prediction = self.model.predict(values)[0]

        return {
            "prediction": (
                prediction.item()
                if isinstance(prediction, np.generic)
                else prediction
            )
        }