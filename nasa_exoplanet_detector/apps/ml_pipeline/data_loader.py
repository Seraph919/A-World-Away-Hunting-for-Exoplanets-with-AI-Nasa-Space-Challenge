import os
import io
import csv
import requests
import pandas as pd

DATA_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), '..', 'data')
DATA_DIR = os.path.abspath(DATA_DIR)

NASA_SOURCES = {
    'kepler_koi': 'https://exoplanetarchive.ipac.caltech.edu/TAP/sync?query=select+*+from+koi&format=csv',
}

COLUMNS_MAP = {
    'orbital_period': ['koi_period'],
    'transit_duration': ['koi_duration'],
    'planet_radius': ['koi_prad'],
    'stellar_temp': ['koi_steff'],
    'label': ['koi_pdisposition', 'koi_disposition'],
}

LABEL_MAP = {
    'CONFIRMED': 'Confirmed',
    'CANDIDATE': 'Candidate',
    'FALSE POSITIVE': 'False Positive',
}


def download_csv(url: str, dest_path: str) -> str:
    os.makedirs(os.path.dirname(dest_path), exist_ok=True)
    r = requests.get(url, timeout=60)
    r.raise_for_status()
    with open(dest_path, 'wb') as f:
        f.write(r.content)
    return dest_path


from typing import Optional, Dict

def ensure_datasets(offline_fallback_path: Optional[str] = None) -> Dict[str, str]:
    paths = {}
    
    # Check if we have the large cumulative dataset first
    base_dir = os.path.dirname(os.path.dirname(os.path.dirname(__file__)))
    cumulative_path = os.path.join(base_dir, 'cumulative_2025.09.20_14.12.59.csv')
    
    if os.path.exists(cumulative_path):
        print(f"📊 Using large cumulative dataset: {cumulative_path}")
        paths['kepler_koi'] = cumulative_path
        return paths
    
    # Try online download
    try:
        paths['kepler_koi'] = download_csv(NASA_SOURCES['kepler_koi'], os.path.join(DATA_DIR, 'raw_kepler_koi.csv'))
        print(f"🌐 Downloaded fresh data from NASA")
    except Exception as e:
        print(f"⚠️  Failed to download from NASA: {e}")
        if offline_fallback_path and os.path.exists(offline_fallback_path):
            print(f"📂 Using offline fallback: {offline_fallback_path}")
            paths['kepler_koi'] = offline_fallback_path
        else:
            raise Exception("No datasets available for training!")
    return paths


def load_and_prepare(paths: dict) -> pd.DataFrame:
    # The provided sample may have commented header lines starting with '#'
    df = pd.read_csv(paths['kepler_koi'], comment='#')
    # Map columns
    out = pd.DataFrame()
    out['orbital_period'] = df[COLUMNS_MAP['orbital_period'][0]]
    out['transit_duration'] = df[COLUMNS_MAP['transit_duration'][0]]
    out['planet_radius'] = df[COLUMNS_MAP['planet_radius'][0]]
    out['stellar_temp'] = df.get(COLUMNS_MAP['stellar_temp'][0])
    # Label preference: koi_pdisposition else koi_disposition
    label_col = None
    for c in COLUMNS_MAP['label']:
        if c in df.columns:
            label_col = c
            break
    if label_col is None:
        raise ValueError('No disposition label columns found')
    labels = df[label_col].astype(str).str.upper().map(LABEL_MAP)
    out['label'] = labels
    # Drop rows with missing critical values
    out = out.dropna(subset=['orbital_period', 'transit_duration', 'planet_radius'])
    # Clean extreme outliers by simple clipping
    out = out[(out['orbital_period'] > 0) & (out['transit_duration'] > 0) & (out['planet_radius'] > 0)]
    return out
