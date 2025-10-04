# NASA Exoplanet AI Detector

One-command setup Django app with ML models to classify exoplanet candidates using NASA Kepler KOI data.

## Quickstart

Run the setup script (automatically installs system dependencies, creates venv, installs Python packages, downloads data, trains 3 models, runs server):

```bash
./setup.sh
```

The setup script automatically detects your system and installs required dependencies:
- **Debian/Ubuntu**: Automatically installs `libpq-dev`, `libmysqlclient-dev`, `pkg-config`, `python3-dev`
- **macOS**: Uses Homebrew to install PostgreSQL, MySQL, pkg-config, and Python
- **Other systems**: Shows manual installation instructions

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

## Troubleshooting

### Database Package Installation Errors

The `./setup.sh` script now automatically handles system dependencies for most systems. However, if you still encounter errors related to `psycopg2` or `mysqlclient`, you may need to install system dependencies manually:

**Install all required system packages:**
```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install libpq-dev libmysqlclient-dev pkg-config python3-dev

# Fedora/CentOS/RHEL
sudo dnf install postgresql-devel mysql-devel pkgconfig python3-devel

# Arch Linux
sudo pacman -S postgresql-libs mariadb-libs pkgconf python

# macOS (with Homebrew)
brew install postgresql mysql pkg-config python
```

**Alternative: Use binary packages instead**
If you prefer to avoid installing system dependencies, edit `requirements.txt` and replace:
- `psycopg2==2.9.9` with `psycopg2-binary==2.9.9`
- `mysqlclient==2.2.4` with `PyMySQL==1.1.0`

Then run `./setup.sh` again.

### Common Issues Summary

The most common installation issues require these system packages:
- **PostgreSQL**: `libpq-dev` (Ubuntu/Debian) or `postgresql-devel` (Fedora)
- **MySQL**: `libmysqlclient-dev` (Ubuntu/Debian) or `mysql-devel` (Fedora)  
- **Python**: `python3-dev` (Ubuntu/Debian) or `python3-devel` (Fedora)
- **Build tools**: `pkg-config` (Ubuntu/Debian) or `pkgconfig` (Fedora)

For a quick fix on Ubuntu/Debian, run:
```bash
sudo apt-get install libpq-dev libmysqlclient-dev pkg-config python3-dev
```

## Offline sample
If dataset download fails, a small sample CSV in `data/sample/kepler_sample.csv` will be used.
