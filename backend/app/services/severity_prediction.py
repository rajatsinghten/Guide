"""Model-backed severity score prediction service.

Loads the trained PKL artifact and applies notebook-consistent preprocessing
for single-row inference.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from threading import Lock
from typing import Any

import joblib
import pandas as pd
from sklearn.preprocessing import LabelEncoder, StandardScaler

from app.config import settings

FINAL_FEATURE_COLUMNS = [
    "distance_km",
    "weather_condition",
    "traffic_level",
    "vehicle_type",
    "temperature_c",
    "humidity_pct",
    "precipitation_mm",
    "preparation_time_min",
    "courier_experience_yrs",
    "worker_age",
    "worker_rating",
    "order_type",
    "weather_risk",
    "traffic_risk",
    "severity_score",
]

TARGET_COLUMN = "claim_triggered"


@dataclass(frozen=True)
class SeverityPredictionResult:
    """Result payload for severity score inference."""

    predicted_severity_score_scaled: float
    predicted_severity_score: float | None


class SeverityPredictionService:
    """Handles loading artifacts and running severity inference."""

    def __init__(self) -> None:
        self._model: Any | None = None
        self._reference_df: pd.DataFrame | None = None
        self._lock = Lock()

    def predict(self, payload: dict[str, Any]) -> SeverityPredictionResult:
        """Predict severity score from frontend-provided feature payload."""
        self._ensure_artifacts_loaded()
        if self._model is None or self._reference_df is None:
            raise RuntimeError("Model artifacts are not loaded")

        row_df = pd.DataFrame([payload], columns=FINAL_FEATURE_COLUMNS)
        inference_df = pd.concat([self._reference_df.copy(), row_df], ignore_index=True)

        processed_df, scaler, numeric_cols = _preprocess_like_notebook(inference_df)

        feature_cols = list(getattr(self._model, "feature_names_in_", []))
        if feature_cols:
            infer_matrix = processed_df.reindex(columns=feature_cols, fill_value=0)
        else:
            infer_matrix = processed_df

        scaled_prediction = float(self._model.predict(infer_matrix.tail(1))[0])

        raw_prediction: float | None = None
        if "severity_score" in numeric_cols:
            idx = numeric_cols.index("severity_score")
            raw_prediction = (
                scaled_prediction * float(scaler.scale_[idx]) + float(scaler.mean_[idx])
            )

        return SeverityPredictionResult(
            predicted_severity_score_scaled=round(scaled_prediction, 4),
            predicted_severity_score=(None if raw_prediction is None else round(raw_prediction, 2)),
        )

    def _ensure_artifacts_loaded(self) -> None:
        if self._model is not None and self._reference_df is not None:
            return

        with self._lock:
            if self._model is None:
                model_path = _resolve_model_path()
                if not model_path.exists():
                    raise FileNotFoundError(f"Model artifact not found: {model_path}")
                self._model = joblib.load(model_path)

            if self._reference_df is None:
                reference_path = _resolve_reference_data_path()
                if not reference_path.exists():
                    raise FileNotFoundError(
                        f"Reference dataset not found: {reference_path}"
                    )
                self._reference_df = pd.read_csv(reference_path)


_service: SeverityPredictionService | None = None


def get_severity_prediction_service() -> SeverityPredictionService:
    """Return a singleton inference service instance."""
    global _service
    if _service is None:
        _service = SeverityPredictionService()
    return _service


def predict_severity(payload: dict[str, Any]) -> SeverityPredictionResult:
    """Convenience wrapper for predicting severity score."""
    return get_severity_prediction_service().predict(payload)


def _resolve_project_root() -> Path:
    return Path(__file__).resolve().parents[3]


def _resolve_model_path() -> Path:
    if settings.ml_model_path:
        return Path(settings.ml_model_path).expanduser().resolve()
    return _resolve_project_root() / "notebooks" / "xg_bost.pkl"


def _resolve_reference_data_path() -> Path:
    if settings.ml_reference_data_path:
        return Path(settings.ml_reference_data_path).expanduser().resolve()
    return _resolve_project_root() / "data" / "processed" / "gigshield_training_ready.csv"


def _preprocess_like_notebook(
    df: pd.DataFrame,
) -> tuple[pd.DataFrame, StandardScaler, list[str]]:
    """Mirror preprocessing described in notebooks/README.md."""
    df_preprocessed = df.copy()

    if "record_id" in df_preprocessed.columns:
        df_preprocessed.drop(columns=["record_id"], inplace=True)

    all_categorical_cols = (
        df_preprocessed.select_dtypes(include=["object", "category"]).columns.tolist()
    )
    if TARGET_COLUMN in all_categorical_cols:
        all_categorical_cols.remove(TARGET_COLUMN)

    for col in all_categorical_cols:
        encoder = LabelEncoder()
        df_preprocessed[col] = encoder.fit_transform(df_preprocessed[col].astype(str))

    numeric_cols = df_preprocessed.select_dtypes(include=["int64", "float64"]).columns.tolist()
    if TARGET_COLUMN in numeric_cols:
        numeric_cols.remove(TARGET_COLUMN)

    categorical_cols = df_preprocessed.select_dtypes(include=["object"]).columns.tolist()
    label_encode_cols = [c for c in ["traffic_level", "time_of_day"] if c in categorical_cols]
    onehot_encode_cols = [c for c in categorical_cols if c not in label_encode_cols]

    for col in label_encode_cols:
        encoder = LabelEncoder()
        df_preprocessed[col] = encoder.fit_transform(df_preprocessed[col].astype(str))

    if onehot_encode_cols:
        df_preprocessed = pd.get_dummies(
            df_preprocessed,
            columns=onehot_encode_cols,
            drop_first=True,
        )

    scaler = StandardScaler()
    if numeric_cols:
        df_preprocessed[numeric_cols] = scaler.fit_transform(df_preprocessed[numeric_cols])

    return df_preprocessed, scaler, numeric_cols
