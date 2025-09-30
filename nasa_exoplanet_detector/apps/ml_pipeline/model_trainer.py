import os
import pickle
import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler, LabelEncoder
from sklearn.pipeline import Pipeline
from sklearn.metrics import classification_report, accuracy_score
from sklearn.ensemble import RandomForestClassifier
from sklearn.svm import SVC
from sklearn.neural_network import MLPClassifier
import xgboost as xgb

from .data_loader import ensure_datasets, load_and_prepare

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
MODELS_DIR = os.path.join(BASE_DIR, 'trained_models')

FEATURES = ['orbital_period', 'transit_duration', 'planet_radius', 'stellar_temp']
TARGET = 'label'


def train_all(offline_sample: str | None = None) -> dict:
    os.makedirs(MODELS_DIR, exist_ok=True)
    paths = ensure_datasets(offline_sample)
    df = load_and_prepare(paths)

    # Fill missing stellar_temp with median
    if 'stellar_temp' in df.columns:
        df['stellar_temp'] = df['stellar_temp'].fillna(df['stellar_temp'].median())
    else:
        df['stellar_temp'] = 0

    X = df[FEATURES]
    y = df[TARGET]
    
    # Encode labels for XGBoost compatibility
    label_encoder = LabelEncoder()
    y_encoded = label_encoder.fit_transform(y)
    
    # Create mapping for later use
    label_mapping = dict(zip(label_encoder.classes_, label_encoder.transform(label_encoder.classes_)))
    print(f"Label mapping: {label_mapping}")

    # Choose split strategy robustly for small datasets
    test_size = 0.2 if len(y) >= 50 else max(2, min(len(y) // 3, len(y) - 1))
    stratify = y if (y.nunique() >= 2 and y.value_counts().min() >= 2 and len(y) >= 10) else None
    
    print(f"Dataset size: {len(y)} samples, {y.nunique()} classes")
    print(f"Test size: {test_size}, Stratify: {stratify is not None}")
    
    if len(y) < 4:
        raise ValueError('Dataset must contain at least 4 samples to train and test models.')
    if y.nunique() < 2:
        raise ValueError('Dataset must contain at least two classes to train a classifier.')
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=test_size, random_state=42, stratify=stratify
    )
    
    # Also split encoded labels for XGBoost
    _, _, y_train_encoded, y_test_encoded = train_test_split(
        X, y_encoded, test_size=test_size, random_state=42, stratify=y_encoded if stratify is not None else None
    )

    results = {}

    # Common parameters for all models
    N_ESTIMATORS = 300
    RANDOM_STATE = 42
    MAX_ITER = 300
    
    configs = {
        'RandomForest': Pipeline([
            ('scaler', StandardScaler()),  # Added scaling for consistency
            ('clf', RandomForestClassifier(
                n_estimators=N_ESTIMATORS, 
                random_state=RANDOM_STATE,
                max_depth=6  # Same max_depth as XGBoost
            ))
        ]),
        'SVM': Pipeline([
            ('scaler', StandardScaler()),
            ('clf', SVC(
                kernel='rbf', 
                probability=True, 
                C=3.0, 
                gamma='scale', 
                random_state=RANDOM_STATE,
                max_iter=MAX_ITER  # Added max_iter limit
            ))
        ]),
        'NeuralNet': Pipeline([
            ('scaler', StandardScaler()),
            ('clf', MLPClassifier(
                hidden_layer_sizes=(64, 32), 
                max_iter=MAX_ITER, 
                random_state=RANDOM_STATE,
                learning_rate_init=0.1  # Same learning rate as XGBoost
            ))
        ]),
        'XGBoost': Pipeline([
            ('scaler', StandardScaler()),  # Added scaling for consistency
            ('clf', xgb.XGBClassifier(
                n_estimators=N_ESTIMATORS,
                max_depth=6,
                learning_rate=0.1,
                subsample=0.8,
                colsample_bytree=0.8,
                random_state=RANDOM_STATE,
                eval_metric='mlogloss'
            ))
        ]),
    }

    for name, model in configs.items():
        print(f"Training {name}...")
        
        # Use encoded labels for XGBoost, string labels for others
        if name == 'XGBoost':
            model.fit(X_train, y_train_encoded)
            y_pred = model.predict(X_test)
            # Convert predictions back to string labels for consistency
            y_pred_strings = label_encoder.inverse_transform(y_pred)
            acc = accuracy_score(y_test, y_pred_strings)
        else:
            model.fit(X_train, y_train)
            y_pred = model.predict(X_test)
            acc = accuracy_score(y_test, y_pred)
            
        results[name] = {'accuracy': acc}
        print(f"  {name} accuracy: {acc:.4f}")
        
        # Save model with label encoder for XGBoost
        model_data = {'model': model, 'features': FEATURES}
        if name == 'XGBoost':
            model_data['label_encoder'] = label_encoder
            
        with open(os.path.join(MODELS_DIR, f'{name}.pkl'), 'wb') as f:
            pickle.dump(model_data, f)

    # Choose best
    best = max(results.items(), key=lambda kv: kv[1]['accuracy'])[0]
    best_accuracy = results[best]['accuracy']
    print(f"\n🏆 Best model: {best} with accuracy: {best_accuracy:.4f}")
    print(f"\n📊 Model Performance Comparison:")
    for name, result in sorted(results.items(), key=lambda x: x[1]['accuracy'], reverse=True):
        print(f"  {name:12s}: {result['accuracy']:.4f}")
        
    with open(os.path.join(MODELS_DIR, 'BEST.txt'), 'w') as f:
        f.write(best)

    return results

if __name__ == '__main__':
    # Use the large cumulative dataset instead of small sample
    cumulative_data = os.path.join(BASE_DIR, 'cumulative_2025.09.20_14.12.59.csv')
    sample = os.path.join(BASE_DIR, 'data', 'sample', 'kepler_sample.csv')
    
    # Prefer the large dataset, fallback to sample
    if os.path.exists(cumulative_data):
        print(f"🚀 Training on LARGE dataset: {cumulative_data} ({os.path.getsize(cumulative_data)//1024//1024}MB)")
        print(train_all(cumulative_data))
    elif os.path.exists(sample):
        print(f"⚠️  Training on small sample: {sample}")
        print(train_all(sample))
    else:
        print("❌ No training data found!")
        print(train_all(None))
