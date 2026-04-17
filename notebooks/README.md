# GigShield Notebooks: Using `xg_bost.pkl`

This folder contains the model saved by:

- `data_processing.ipynb`

Model file:

- `xg_bost.pkl`

## What It Predicts

`xg_bost.pkl` is an **XGBoost regressor** trained to predict:

- `severity_score`

## Important

The model was trained on a dataframe that was:

- label-encoded for object/category columns
- then numerically standardized (`StandardScaler`)

Only the model was saved. Encoder/scaler artifacts were not saved separately.
So for inference, use the same preprocessing logic below.

## Batch Inference (Recommended)

Run from `GigShield/notebooks`:

```python
import joblib
import pandas as pd
from sklearn.preprocessing import LabelEncoder, StandardScaler

def preprocess_like_notebook(df: pd.DataFrame):
    df_preprocessed = df.copy()
    target_col = "claim_triggered"

    if "record_id" in df_preprocessed.columns:
        df_preprocessed.drop(columns=["record_id"], inplace=True)

    all_categorical_cols = df_preprocessed.select_dtypes(include=["object", "category"]).columns.tolist()
    if target_col in all_categorical_cols:
        all_categorical_cols.remove(target_col)

    for c in all_categorical_cols:
        le = LabelEncoder()
        df_preprocessed[c] = le.fit_transform(df_preprocessed[c].astype(str))

    numeric_cols = df_preprocessed.select_dtypes(include=["int64", "float64"]).columns.tolist()
    if target_col in numeric_cols:
        numeric_cols.remove(target_col)

    # (kept to mirror notebook flow)
    categorical_cols = df_preprocessed.select_dtypes(include=["object"]).columns.tolist()
    label_encode_cols = [c for c in ["traffic_level", "time_of_day"] if c in categorical_cols]
    onehot_encode_cols = [c for c in categorical_cols if c not in label_encode_cols]

    for c in label_encode_cols:
        le = LabelEncoder()
        df_preprocessed[c] = le.fit_transform(df_preprocessed[c].astype(str))

    df_preprocessed = pd.get_dummies(df_preprocessed, columns=onehot_encode_cols, drop_first=True)

    scaler = StandardScaler()
    df_preprocessed[numeric_cols] = scaler.fit_transform(df_preprocessed[numeric_cols])

    return df_preprocessed, scaler, numeric_cols

model = joblib.load("xg_bost.pkl")
df = pd.read_csv("../data/processed/gigshield_training_ready.csv")

df_preprocessed, scaler, numeric_cols = preprocess_like_notebook(df)
feature_cols = list(model.feature_names_in_)
X_infer = df_preprocessed.reindex(columns=feature_cols, fill_value=0)

df["predicted_severity_score_scaled"] = model.predict(X_infer)
print(df[["predicted_severity_score_scaled"]].head())
```

## Convert Prediction Back To Raw `severity_score` Scale (Optional)

Because `severity_score` was standardized during training, model output is scaled.
If you kept `scaler` and `numeric_cols` from preprocessing:

```python
idx = numeric_cols.index("severity_score")
mean_ = scaler.mean_[idx]
std_ = scaler.scale_[idx]

df["predicted_severity_score"] = (
    df["predicted_severity_score_scaled"] * std_ + mean_
)
print(df[["predicted_severity_score"]].head())
```

## Single-Row Inference

For a single new row, safest approach is:

1. Append the row to the same reference dataset used for preprocessing.
2. Run `preprocess_like_notebook(...)`.
3. Predict on the last row only.

This keeps encoding/scaling consistent with notebook behavior.
