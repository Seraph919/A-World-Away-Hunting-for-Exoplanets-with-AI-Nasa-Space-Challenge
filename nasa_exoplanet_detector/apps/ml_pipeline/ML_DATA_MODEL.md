# Data Processing & RandomForest Training Overview

This document explains how the Kepler KOI (Kepler Object of Interest) dataset is ingested, cleaned, transformed, and used to train the RandomForest model in this repository.

## 1. Source Data
- Primary source: NASA Exoplanet Archive KOI table (downloaded as CSV).
- Fallback: Local sample at `data/sample/kepler_sample.csv` (auto-generated minimally viable multi-class subset in `setup.sh`).
- Downloader: `apps/ml_pipeline/data_loader.py` (`ensure_datasets()` + `download_csv()`).
- Commented metadata lines beginning with `#` are ignored using `pandas.read_csv(..., comment='#')`.

## 2. Selected Features & Column Mapping
Raw KOI columns are renamed / mapped to internal feature names:

| Internal Feature | Source Column | Description |
|------------------|---------------|-------------|
| `orbital_period` | `koi_period`  | Orbital period (days) |
| `transit_duration` | `koi_duration` | Transit duration (hours) |
| `planet_radius` | `koi_prad` | Planet radius (Earth radii) |
| `stellar_temp`  | `koi_steff` | Stellar effective temperature (Kelvin) |

Implementation: in `load_and_prepare()`, a new DataFrame is built with only these columns.

## 3. Label Construction
Two possible KOI disposition fields exist:
1. `koi_pdisposition` (preferred)
2. `koi_disposition` (fallback if the first is absent)

Mapping (uppercased input → canonical label):
- `CONFIRMED` → `Confirmed`
- `CANDIDATE` → `Candidate`
- `FALSE POSITIVE` → `False Positive`

Rows without a valid disposition mapping are implicitly turned into `NaN` then dropped if they collide with feature NaNs.

## 4. Data Cleaning Steps
1. Drop rows with missing critical numeric features: `orbital_period`, `transit_duration`, `planet_radius`.
2. Clip extreme anomalies by filtering strictly positive values for those three fields.
3. Fill missing `stellar_temp` with the median (computed after initial filtering). If absent entirely, a constant `0` is injected (rare fallback).

_No scaling is applied for RandomForest_; scaling is applied only in other model pipelines (SVM, MLP) via `StandardScaler`.

## 5. Feature / Target Separation
```
FEATURES = ['orbital_period', 'transit_duration', 'planet_radius', 'stellar_temp']
TARGET = 'label'
X = df[FEATURES]
y = df[TARGET]
```

## 6. Train/Test Split Logic
To remain robust on both large and very small datasets:
- If dataset length >= 100 → `test_size = 0.2`
- Else → `test_size = 0.33`
- Stratification: only applied if at least 2 classes exist AND each class has at least 2 instances (`y.value_counts().min() >= 2`).
- If fewer than 2 distinct classes → training aborts with `ValueError`.

```
train_test_split(X, y, test_size=..., random_state=42, stratify=maybe_y)
```

## 7. RandomForest Model Configuration
The RandomForest pipeline (from `train_all()` in `model_trainer.py`):
```
Pipeline([
  ('clf', RandomForestClassifier(n_estimators=300, random_state=42))
])
```
Key points:
- `n_estimators=300` for a balance of stability vs. build time.
- `random_state=42` ensures reproducibility.
- No max depth or min samples constraints explicitly set (defaults used) to allow trees to grow until pure or constrained by other defaults—appropriate for modest feature dimensionality.
- No scaling required due to tree-based invariance to monotonic transformations.

## 8. Other Models (For Comparison)
Also trained in parallel:
- SVM (RBF kernel) with probability output + scaling.
- MLP neural network with 2 hidden layers (64, 32) + scaling.
Accuracy for each is computed on the test split. All models and metrics stored transiently in memory; only models are persisted.

## 9. Model Persistence
Each trained model is serialized with pickle:
```
trained_models/RandomForest.pkl
trained_models/SVM.pkl
trained_models/NeuralNet.pkl
```
Serialized format:
```
{
  'model': <sklearn Pipeline>,
  'features': ['orbital_period', 'transit_duration', 'planet_radius', 'stellar_temp']
}
```
A simple text file stores the best model by accuracy:
```
trained_models/BEST.txt  # e.g., "RandomForest"
```

## 10. Prediction Path
`predictor.py`:
1. Loads `BEST.txt`; falls back to first available `.pkl` if absent.
2. Deserializes model & feature list.
3. Accepts a feature dict; orders features consistently.
4. If `predict_proba` exists, returns full class probability distribution; else, returns a single class with confidence 1.0.

Class label ordering (for probability alignment if fallback needed):
```
['Confirmed', 'Candidate', 'False Positive']
```

## 11. Handling Small / Imbalanced Samples
- Stratification skipped if any class has < 2 examples.
- If only one unique class remain → training stops (prevents meaningless model).
- Offline sample (`setup.sh`) intentionally contains all three classes so pipelines succeed without network.

## 12. Extending the Pipeline
To add new features:
1. Update `COLUMNS_MAP` in `data_loader.py`.
2. Add the new feature name to `FEATURES` list in `model_trainer.py`.
3. Ensure proper null-handling or scaling if needed.

To tune RandomForest:
- Modify `n_estimators`, `max_depth`, `min_samples_split`, etc., in the pipeline config.
- Consider adding cross-validation or GridSearch for automated selection.

## 13. Re-training
```
python apps/ml_pipeline/model_trainer.py
```
Or run the full setup (downloads data + trains):
```
./setup.sh
```

## 14. Summary Flow
```
Download → Clean/Map → Feature Matrix (X) + Labels (y) → Train/Test Split → Train RF/SVM/MLP → Pick Best → Persist → Predict
```

## 15. Rationale for Chosen Features
- They are fundamental transit and stellar descriptors influencing detectability and classification confidence.
- Low dimensionality reduces overfitting risk with limited data subsets.

---
For quick reference, see also: `apps/ml_pipeline/README_PIPELINE.md` (concise summary) vs. this document (full detail).
