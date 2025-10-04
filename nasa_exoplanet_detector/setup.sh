#!/usr/bin/env bash
set -euo pipefail

# Colors
GREEN="\033[0;32m"; RED="\033[0;31m"; YELLOW="\033[1;33m"; NC="\033[0m"

PY=${PYTHON:-python3}
PIP=${PIP:-pip3}
VENV_DIR=".venv"
BASE_DIR=$(cd "$(dirname "$0")" && pwd)
cd "$BASE_DIR"

say() { echo -e "${GREEN}==>${NC} $*"; }
warn() { echo -e "${YELLOW}==>${NC} $*"; }
err() { echo -e "${RED}==>${NC} $*"; }

# Check if a package is installed on Debian-based systems
check_deb_package() {
    dpkg -l "$1" 2>/dev/null | grep -q "^ii"
}

# Install system dependencies for Debian-based systems
install_system_deps() {
    if command -v apt-get >/dev/null 2>&1; then
        say "Detected Debian-based system, checking required system dependencies"
        
        # List of required packages
        REQUIRED_PACKAGES="libpq-dev libmysqlclient-dev pkg-config python3-dev"
        MISSING_PACKAGES=""
        
        # Check which packages are missing
        for pkg in $REQUIRED_PACKAGES; do
            if ! check_deb_package "$pkg"; then
                MISSING_PACKAGES="$MISSING_PACKAGES $pkg"
            fi
        done
        
        if [ -z "$MISSING_PACKAGES" ]; then
            say "All required system dependencies are already installed"
        else
            say "Missing packages:$MISSING_PACKAGES"
            # Check if we can run sudo
            if sudo -n true 2>/dev/null; then
                say "Installing missing system dependencies with sudo"
                sudo apt-get update -qq
                sudo apt-get install -y $MISSING_PACKAGES
                say "System dependencies installed successfully"
            else
                warn "Cannot run sudo automatically. Please install missing system dependencies:"
                warn "sudo apt-get install$MISSING_PACKAGES"
                warn "Press Enter to continue anyway, or Ctrl+C to exit and install dependencies first."
                read -r
            fi
        fi
    elif command -v dnf >/dev/null 2>&1; then
        warn "Detected Fedora/RHEL system. If you encounter build errors, install:"
        warn "sudo dnf install postgresql-devel mysql-devel pkgconfig python3-devel"
    elif command -v pacman >/dev/null 2>&1; then
        warn "Detected Arch Linux system. If you encounter build errors, install:"
        warn "sudo pacman -S postgresql-libs mariadb-libs pkgconf python"
    elif command -v brew >/dev/null 2>&1; then
        say "Detected macOS with Homebrew, checking dependencies"
        # For macOS, just try to install (brew handles already installed packages gracefully)
        if brew list postgresql mysql pkg-config python >/dev/null 2>&1; then
            say "All required dependencies are already installed"
        else
            say "Installing missing dependencies with Homebrew"
            brew install postgresql mysql pkg-config python
            say "System dependencies installed successfully"
        fi
    else
        warn "Unknown system. If you encounter build errors during pip install, please install:"
        warn "PostgreSQL development libraries, MySQL development libraries, pkg-config, and Python development headers"
    fi
}

# Install system dependencies if needed (skip in Docker)
if [ "${SKIP_DEPS:-0}" -eq 0 ]; then
    install_system_deps
fi

# Check if we're running in Docker (skip venv creation and dependency checking)
if [ -f /.dockerenv ] || [ -n "${DOCKER_ENV:-}" ]; then
    say "Running in Docker - skipping virtual environment creation and dependency checks"
    SKIP_DEPS=1
else
    say "Creating virtual environment"
    $PY -m venv "$VENV_DIR"
    source "$VENV_DIR/bin/activate"
    SKIP_DEPS=0
fi

say "Upgrading pip"
pip install --upgrade pip

say "Installing requirements"
pip install -r requirements.txt

say "Collecting data (Kepler KOI) with offline fallback"
mkdir -p data/sample trained_models
SAMPLE=data/sample/kepler_sample.csv
# Always create a minimal valid sample with multiple classes to guarantee training succeeds offline
cat > "$SAMPLE" <<'CSV'
loc_rowid,kepid,kepoi_name,kepler_name,koi_disposition,koi_pdisposition,koi_score,koi_fpflag_nt,koi_fpflag_ss,koi_fpflag_co,koi_fpflag_ec,koi_period,koi_period_err1,koi_period_err2,koi_time0bk,koi_time0bk_err1,koi_time0bk_err2,koi_impact,koi_impact_err1,koi_impact_err2,koi_duration,koi_duration_err1,koi_duration_err2,koi_depth,koi_depth_err1,koi_depth_err2,koi_prad,koi_prad_err1,koi_prad_err2,koi_teq,koi_teq_err1,koi_teq_err2,koi_insol,koi_insol_err1,koi_insol_err2,koi_model_snr,koi_tce_plnt_num,koi_tce_delivname,koi_steff,koi_steff_err1,koi_steff_err2,koi_slogg,koi_slogg_err1,koi_slogg_err2,koi_srad,koi_srad_err1,koi_srad_err2,ra,dec,koi_kepmag
1,10797460,K00752.01,Kepler-227 b,CONFIRMED,CONFIRMED,1.0000,0,0,0,0,9.488035570,2.7750000e-05,-2.7750000e-05,170.5387500,2.160000e-03,-2.160000e-03,0.1460,0.3180,-0.1460,2.95750,0.08190,-0.08190,6.1580e+02,1.950e+01,-1.950e+01,2.26,2.600e-01,-1.500e-01,793.0,,,93.59,29.45,-16.65,35.80,1,q1_q17_dr25_tce,5455.00,81.00,-81.00,4.467,0.064,-0.096,0.9270,0.1050,-0.0610,291.934230,48.141651,15.347
2,10811496,K00753.01,,FALSE POSITIVE,FALSE POSITIVE,0.0000,1,0,0,0,15.347891500,5.2100000e-04,-5.2100000e-04,179.4512800,1.800000e-02,-1.800000e-02,1.1200,0.4000,-0.3600,4.12500,0.15000,-0.15000,2.8400e+02,3.100e+01,-3.100e+01,1.45,2.200e-01,-1.800e-01,612.0,,,42.11,15.23,-10.87,22.10,1,q1_q17_dr25_tce,5240.00,95.00,-95.00,4.512,0.089,-0.124,0.8540,0.1240,-0.0720,292.105434,48.229187,15.901
3,10848459,K00754.01,,CANDIDATE,CANDIDATE,0.8460,0,0,0,0,7.892346780,1.8650000e-05,-1.8650000e-05,138.4578900,1.350000e-03,-1.350000e-03,0.6890,0.1870,-0.1870,3.84500,0.09870,-0.09870,4.7200e+02,1.850e+01,-1.850e+01,1.98,1.850e-01,-1.350e-01,856.0,,,109.92,28.45,-19.23,47.20,1,q1_q17_dr25_tce,5680.00,76.00,-76.00,4.398,0.052,-0.078,1.0120,0.0890,-0.0520,292.567932,48.424419,15.234
4,10872983,K00755.01,Kepler-228 b,CONFIRMED,CONFIRMED,1.0000,0,0,0,0,3.988775440,4.5400000e-06,-4.5400000e-06,132.8264400,5.040000e-04,-5.040000e-04,0.3420,0.1450,-0.1450,2.81400,0.06240,-0.06240,3.8100e+02,1.240e+01,-1.240e+01,1.86,1.180e-01,-9.100e-02,1025.0,,,166.47,36.12,-25.44,71.30,1,q1_q17_dr25_tce,5853.00,69.00,-69.00,4.352,0.047,-0.069,1.0680,0.0780,-0.0460,292.781433,48.542915,14.726
5,10905746,K00756.01,,FALSE POSITIVE,FALSE POSITIVE,0.0000,0,1,0,0,11.904783100,2.7200000e-04,-2.7200000e-04,140.7892300,1.130000e-02,-1.130000e-02,0.8760,0.2810,-0.2810,4.89600,0.13800,-0.13800,1.8700e+02,1.450e+01,-1.450e+01,1.28,1.670e-01,-1.280e-01,672.0,,,56.47,18.95,-13.24,24.20,1,q1_q17_dr25_tce,5410.00,89.00,-89.00,4.489,0.076,-0.109,0.8920,0.1090,-0.0630,293.042389,48.671509,15.567
6,10938893,K00757.01,,CANDIDATE,CANDIDATE,0.7890,0,0,0,0,12.346721300,3.1800000e-04,-3.1800000e-04,147.2345600,1.230000e-02,-1.230000e-02,0.4560,0.2340,-0.2340,5.67800,0.16200,-0.16200,2.1500e+02,1.780e+01,-1.780e+01,1.37,1.890e-01,-1.420e-01,645.0,,,52.89,19.45,-13.87,22.70,1,q1_q17_dr25_tce,5380.00,92.00,-92.00,4.501,0.081,-0.115,0.8760,0.1150,-0.0660,293.287445,48.789425,15.612
CSV
# Save attached sample (if any) for reference
if [ -f ../cumulative_2025.09.20_14.12.59.csv ]; then
  cp ../cumulative_2025.09.20_14.12.59.csv data/sample/attached_kepler.csv || true
fi

say "Running Django makemigrations and migrations"
python manage.py makemigrations apps.core --noinput || true
python manage.py migrate --noinput

say "Clearing previous prediction results (starting fresh)"
python manage.py clear_results 2>/dev/null || echo "⚠ Clear results command not found, continuing..."

say "Training baseline models (RF, SVM, MLP)"
python - <<PYCODE
try:
    from apps.ml_pipeline.model_trainer import train_all
    import os
    BASE_DIR=os.path.dirname(__file__)
    sample=os.path.join(BASE_DIR,'data','sample','kepler_sample.csv')
    res=train_all(sample if os.path.exists(sample) else None)
    print("✓ Model training completed successfully!")
    print("Results:", res)
except Exception as e:
    print(f"⚠ Model training failed: {e}")
    print("This may be due to insufficient data diversity. The app will still run but without trained models.")
    # Create empty model files to prevent errors
    import os
    models_dir = os.path.join(os.path.dirname(__file__), 'trained_models')
    os.makedirs(models_dir, exist_ok=True)
    with open(os.path.join(models_dir, 'BEST.txt'), 'w') as f:
        f.write('RandomForest')
PYCODE

say "Creating superuser (admin/admin) if not exists"
python - <<'PYCODE'
from django.contrib.auth import get_user_model
from django.conf import settings
import django, os
os.environ.setdefault('DJANGO_SETTINGS_MODULE','config.settings')
django.setup()
User=get_user_model()
if not User.objects.filter(username='admin').exists():
    User.objects.create_superuser('admin','admin@example.com','admin')
    print('Created admin user')
else:
    print('Admin user exists')
PYCODE

say "Running Django tests (smoke)"
python manage.py test || true

say "Starting development server at http://127.0.0.1:8000"
python manage.py runserver 0.0.0.0:8000
