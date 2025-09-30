# ML Pipeline Notes

- Data source: Kepler KOI CSV via NASA Exoplanet Archive. Using comment='#' to handle metadata lines.
- Features: orbital_period (koi_period), transit_duration (koi_duration), planet_radius (koi_prad), stellar_temp (koi_steff).
- Labels: koi_pdisposition preferred, fallback to koi_disposition. Mapped to Confirmed/Candidate/False Positive.
- Models: RandomForest, SVM (with scaling), MLP (with scaling), XGBoost. Best model stored in trained_models/BEST.txt
