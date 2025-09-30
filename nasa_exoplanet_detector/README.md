# NASA Exoplanet AI Detector

One-command setup Django app with ML models to classify exoplanet candidates using NASA Kepler KOI data.

## Quickstart

Run the setup script (creates venv, installs deps, downloads data, trains 4 models, runs server):

```bash
./setup.sh
```

Then open http://127.0.0.1:8000/

## Structure
- apps/core: Web UI
- apps/api: REST endpoints
- apps/ml_pipeline: Data loader, trainer, predictor
- data/: datasets (downloaded automatically)
- trained_models/: saved models

## Results Page Features

The results page (`/results/`) displays all your predictions with comprehensive details:

### What You'll See:
- **Prediction History**: All single predictions and batch uploads in chronological order
- **Classification Results**: Three possible outcomes for each exoplanet candidate:
  - `Confirmed` (Green badge): High confidence exoplanet detection
  - `Candidate` (Yellow badge): Potential exoplanet requiring further investigation
  - `False Positive` (Red badge): Not likely to be an exoplanet
- **Confidence Scores**: Model confidence level (0.000-1.000) for each prediction
- **Class Probabilities**: Detailed breakdown showing probability for each classification:
  - Shows exact probability values and percentages for all three classes
  - Helps understand model uncertainty and decision boundaries
- **Input Parameters**: Original data used for prediction (orbital period, transit duration, planet radius, stellar temperature)
- **Model Information**: Which ML model was used (RandomForest, SVM, or NeuralNet)
- **Timestamps**: When each prediction was made

### Export Functionality:
- **Download CSV**: Export all results as CSV file for further analysis
- Includes all prediction data, probabilities, and metadata
- Perfect for data analysis, reporting, or sharing results

### Data Sources:
- Single predictions from the `/predict/` page
- Batch predictions from CSV uploads via `/upload/`
- All results are stored persistently in the database

## Offline sample
If dataset download fails, a small sample CSV in `data/sample/kepler_sample.csv` will be used.
