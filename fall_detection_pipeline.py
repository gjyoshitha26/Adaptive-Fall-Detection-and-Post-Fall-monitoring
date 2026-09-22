# ============================================================================
# TINYML FALL DETECTION, CLINICAL TRIAGE & RISK ANALYSIS PIPELINE
# Dataset: FallAllD (IMU) | Target: Kaggle Notebook | TF/Keras 3 + Scikit-Learn
# ============================================================================

import os
import re
import glob
import random
import numpy as np
import pandas as pd
from pathlib import Path

import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers

from sklearn.model_selection import GroupShuffleSplit
from sklearn.utils.class_weight import compute_class_weight
from sklearn.metrics import classification_report, confusion_matrix

try:
    from tqdm import tqdm
except ImportError:
    def tqdm(x, **kwargs):
        return x

SEED = 42
np.random.seed(SEED)
random.seed(SEED)
tf.random.set_seed(SEED)

# ============================================================================
# SECTION 1: CONFIG
# ============================================================================

FS = 50                      # Hz
DT = 1.0 / FS                # seconds/sample
WINDOW_SIZE = 100             # 2.0s
STEP = 50                     # 50% overlap
DATA_GLOB = "/kaggle/input/datasets/shusrith/fallalld/sensor_data/*/*.csv"

REQUIRED_COLS = ['AccX', 'AccY', 'AccZ', 'GyrX', 'GyrY', 'GyrZ']

ACTIVITY_CLASSES = ['WALK', 'RUN', 'SIT', 'STAND', 'SLEEP', 'STAIRS']
EVENT_CLASSES = ['NORMAL', 'NEAR_FALL', 'FALL']
ACT2IDX = {n: i for i, n in enumerate(ACTIVITY_CLASSES)}
EVT2IDX = {n: i for i, n in enumerate(EVENT_CLASSES)}
IDX2ACT = {i: n for n, i in ACT2IDX.items()}
IDX2EVT = {i: n for n, i in EVT2IDX.items()}

EPOCHS = 60
BATCH_SIZE = 64
TFLITE_PATH = "/kaggle/working/fall_pipeline_int8.tflite"

# ----------------------------------------------------------------------------
# Task-ID -> (Activity, Event) map, built per spec.
# NOTE: The prompt explicitly names T01-T03, T04, T05-T10, T11/T12/T15/T25/T26,
# T13/T14/T27/T28, T17-T19 (normal); T16,T20,T21,T29 (near-fall);
# T30,T31,T35,T36 (fall, explicitly typed). T32-T34 fall within the T30-T36
# fall range but weren't individually typed in the spec -> assigned here to
# the remaining activities (Trip/Walk, Stand, Stairs) so all 6 activities are
# covered under FALL. Adjust below if your copy of FallAllD differs.
# ----------------------------------------------------------------------------

TASK_MAP = {}
for t in [1, 2, 3]:
    TASK_MAP[t] = ('WALK', 'NORMAL')
TASK_MAP[4] = ('RUN', 'NORMAL')
for t in range(5, 11):
    TASK_MAP[t] = ('SIT', 'NORMAL')
for t in [11, 12, 15, 25, 26]:
    TASK_MAP[t] = ('STAND', 'NORMAL')
for t in [13, 14, 27, 28]:
    TASK_MAP[t] = ('STAIRS', 'NORMAL')
for t in [17, 18, 19]:
    TASK_MAP[t] = ('SLEEP', 'NORMAL')

TASK_MAP[16] = ('WALK', 'NEAR_FALL')
TASK_MAP[20] = ('STAND', 'NEAR_FALL')
TASK_MAP[21] = ('STAIRS', 'NEAR_FALL')
TASK_MAP[29] = ('SIT', 'NEAR_FALL')

TASK_MAP[30] = ('WALK', 'FALL')     # Walk Fall
TASK_MAP[31] = ('RUN', 'FALL')      # Run Fall
TASK_MAP[32] = ('WALK', 'FALL')     # Trip Fall (assigned)
TASK_MAP[33] = ('STAND', 'FALL')    # Stand Fall (assigned)
TASK_MAP[34] = ('STAIRS', 'FALL')   # Stairs Fall (assigned)
TASK_MAP[35] = ('SIT', 'FALL')      # Sit Fall
TASK_MAP[36] = ('SLEEP', 'FALL')    # Sleep/Collapse Fall

# ============================================================================
# SECTION 2: DATA LOADING & WINDOWING
# ============================================================================

def parse_task_id(filepath):
    """Extract Txx task id from filename or parent folder name."""
    name = Path(filepath).stem
    parent = Path(filepath).parent.name
    for s in [name, parent]:
        m = re.search(r'[Tt](\d{1,2})(?!\d)', s)
        if m:
            return int(m.group(1))
    return None


def standardize_columns(df):
    colmap = {}
    for c in df.columns:
        key = c.strip().lower().replace('_', '').replace(' ', '')
        for req in REQUIRED_COLS:
            if key == req.lower():
                colmap[c] = req
    return df.rename(columns=colmap)


def window_signal(arr, window_size, step):
    n = len(arr)
    out = []
    for start in range(0, n - window_size + 1, step):
        out.append(arr[start:start + window_size])
    return out


print("=" * 78)
print("LOADING & WINDOWING FALLALLD DATA")
print("=" * 78)

file_list = glob.glob(DATA_GLOB)
print(f"Found {len(file_list)} candidate CSV files at: {DATA_GLOB}")

all_windows, all_activity, all_event, all_subject = [], [], [], []
unmapped_tasks = set()
skipped_files = 0
bad_columns = 0

for fp in tqdm(file_list, desc="Scanning files"):
    task_id = parse_task_id(fp)
    if task_id is None or task_id not in TASK_MAP:
        if task_id is not None:
            unmapped_tasks.add(task_id)
        skipped_files += 1
        continue

    activity_name, event_name = TASK_MAP[task_id]

    try:
        df = pd.read_csv(fp)
    except Exception:
        skipped_files += 1
        continue

    df = standardize_columns(df)
    if not set(REQUIRED_COLS).issubset(df.columns):
        bad_columns += 1
        continue

    arr = df[REQUIRED_COLS].values.astype(np.float32)
    if len(arr) < WINDOW_SIZE or np.isnan(arr).any():
        arr = arr[~np.isnan(arr).any(axis=1)] if np.isnan(arr).any() else arr
        if len(arr) < WINDOW_SIZE:
            continue

    subject_id = Path(fp).parent.name

    for w in window_signal(arr, WINDOW_SIZE, STEP):
        if np.isnan(w).any():
            continue
        all_windows.append(w)
        all_activity.append(ACT2IDX[activity_name])
        all_event.append(EVT2IDX[event_name])
        all_subject.append(subject_id)

if len(all_windows) == 0:
    raise RuntimeError(
        "No windows were extracted. Check DATA_GLOB path and CSV column names "
        "against your actual Kaggle dataset structure."
    )

X_raw = np.stack(all_windows).astype(np.float32)          # (N, 100, 6) raw units
y_activity = np.array(all_activity, dtype=np.int64)
y_event = np.array(all_event, dtype=np.int64)
subjects = np.array(all_subject)

print(f"Total windows extracted: {len(X_raw)}")
print(f"Skipped files (unmapped task / read error): {skipped_files}")
print(f"Skipped files (missing required columns): {bad_columns}")
if unmapped_tasks:
    print(f"Unmapped task IDs encountered (skipped): {sorted(unmapped_tasks)}")

# ============================================================================
# SECTION 3: SUBJECT-WISE TRAIN / VAL / TEST SPLIT (prevents leakage)
# ============================================================================

gss_outer = GroupShuffleSplit(n_splits=1, test_size=0.20, random_state=SEED)
trainval_idx, test_idx = next(gss_outer.split(X_raw, groups=subjects))

gss_inner = GroupShuffleSplit(n_splits=1, test_size=0.15, random_state=SEED)
tr_sub_idx, val_sub_idx = next(
    gss_inner.split(trainval_idx, groups=subjects[trainval_idx])
)
train_idx = trainval_idx[tr_sub_idx]
val_idx = trainval_idx[val_sub_idx]

print(f"Train windows: {len(train_idx)} | Val windows: {len(val_idx)} | Test windows: {len(test_idx)}")

# ============================================================================
# SECTION 4: NORMALIZATION (channel-wise, fit on TRAIN only)
# ============================================================================

train_flat = X_raw[train_idx].reshape(-1, 6)
scaler_mean = train_flat.mean(axis=0)
scaler_std = train_flat.std(axis=0)
scaler_std[scaler_std == 0] = 1.0

def normalize(x):
    return (x - scaler_mean) / scaler_std

X_norm = normalize(X_raw)

X_train, X_val, X_test = X_norm[train_idx], X_norm[val_idx], X_norm[test_idx]
ya_train, ya_val, ya_test = y_activity[train_idx], y_activity[val_idx], y_activity[test_idx]
ye_train, ye_val, ye_test = y_event[train_idx], y_event[val_idx], y_event[test_idx]
raw_test = X_raw[test_idx]  # kept RAW (de-normalized) for physics/clinical calcs

# ============================================================================
# SECTION 5: CLASS-BALANCED SAMPLE WEIGHTS (event-prioritized, per spec)
# ============================================================================

act_classes_present = np.unique(ya_train)
evt_classes_present = np.unique(ye_train)

wa = np.ones(len(ACTIVITY_CLASSES))
we = np.ones(len(EVENT_CLASSES))

wa_vals = compute_class_weight('balanced', classes=act_classes_present, y=ya_train)
we_vals = compute_class_weight('balanced', classes=evt_classes_present, y=ye_train)
for c, w in zip(act_classes_present, wa_vals):
    wa[c] = w
for c, w in zip(evt_classes_present, we_vals):
    we[c] = w

sw_train = we[ye_train] * 0.7 + wa[ya_train] * 0.3
sw_val = we[ye_val] * 0.7 + wa[ya_val] * 0.3

print("Activity class weights:", dict(zip(ACTIVITY_CLASSES, wa)))
print("Event class weights:", dict(zip(EVENT_CLASSES, we)))

# ============================================================================
# SECTION 6: DUAL-HEAD TINYML 1D-CNN
# ============================================================================

def build_dual_head_cnn(input_shape=(WINDOW_SIZE, 6)):
    inp = keras.Input(shape=input_shape, name="imu_window")

    x = layers.Conv1D(16, 5, padding='same', activation='relu')(inp)
    x = layers.BatchNormalization()(x)
    x = layers.MaxPooling1D(2)(x)

    x = layers.Conv1D(32, 5, padding='same', activation='relu')(x)
    x = layers.BatchNormalization()(x)
    x = layers.MaxPooling1D(2)(x)

    x = layers.Conv1D(64, 3, padding='same', activation='relu')(x)
    x = layers.BatchNormalization()(x)
    x = layers.GlobalAveragePooling1D()(x)

    shared = layers.Dense(32, activation='relu')(x)
    shared = layers.Dropout(0.3)(shared)

    act_branch = layers.Dense(16, activation='relu')(shared)
    activity_output = layers.Dense(len(ACTIVITY_CLASSES), activation='softmax',
                                    name='activity_output')(act_branch)

    evt_branch = layers.Dense(16, activation='relu')(shared)
    event_output = layers.Dense(len(EVENT_CLASSES), activation='softmax',
                                 name='event_output')(evt_branch)

    return keras.Model(inputs=inp, outputs=[activity_output, event_output],
                        name="fall_dual_head_cnn")


model = build_dual_head_cnn()
model.summary()

# ---- KERAS 3 COMPLIANCE: loss / metrics passed as LISTS, matching output order ----
model.compile(
    optimizer=keras.optimizers.Adam(learning_rate=1e-3),
    loss=['sparse_categorical_crossentropy', 'sparse_categorical_crossentropy'],
    loss_weights=[0.3, 0.7],          # reinforces event-head priority alongside sample weights
    metrics=[['accuracy'], ['accuracy']],
)

callbacks = [
    keras.callbacks.EarlyStopping(monitor='val_event_output_accuracy', mode='max',
                                   patience=10, restore_best_weights=True),
    keras.callbacks.ReduceLROnPlateau(monitor='val_loss', factor=0.5, patience=5,
                                       min_lr=1e-6),
]

# ---- KERAS 3 COMPLIANCE: y and sample_weight passed as LISTS, not dicts ----
history = model.fit(
    x=X_train,
    y=[ya_train, ye_train],
    sample_weight=[sw_train, sw_train],
    validation_data=(X_val, [ya_val, ye_val], [sw_val, sw_val]),
    epochs=EPOCHS,
    batch_size=BATCH_SIZE,
    callbacks=callbacks,
    verbose=1,
)

# ============================================================================
# SECTION 7: TEST EVALUATION
# ============================================================================

act_probs_test, evt_probs_test = model.predict(X_test, batch_size=BATCH_SIZE, verbose=0)
act_pred_test = np.argmax(act_probs_test, axis=1)
evt_pred_test = np.argmax(evt_probs_test, axis=1)

print("\n--- ACTIVITY HEAD REPORT ---")
print(classification_report(ya_test, act_pred_test, target_names=ACTIVITY_CLASSES, zero_division=0))
print("\n--- EVENT HEAD REPORT ---")
print(classification_report(ye_test, evt_pred_test, target_names=EVENT_CLASSES, zero_division=0))

# ============================================================================
# SECTION 8: SIGNAL PHYSICS & CLINICAL RISK ANALYSIS FUNCTIONS
# (operate on RAW, de-normalized windows; units: Acc in g, Gyro in deg/s)
# ============================================================================

def resultant_series(window):
    acc = window[:, 0:3]
    gyro = window[:, 3:6]
    acc_mag = np.sqrt(np.sum(acc ** 2, axis=1))
    gyro_mag = np.sqrt(np.sum(gyro ** 2, axis=1))
    return acc_mag, gyro_mag


def compute_fhe(window, g_thresh=0.6, dt=DT):
    """Fall Height Estimation via pre-impact free-fall duration."""
    acc_mag, gyro_mag = resultant_series(window)
    peak_idx = int(np.argmax(acc_mag))
    i = peak_idx - 1
    count = 0
    while i >= 0 and acc_mag[i] < g_thresh:
        count += 1
        i -= 1
    t_ff = count * dt
    h = 0.5 * 9.81 * (t_ff ** 2)
    return h, t_ff, peak_idx, acc_mag, gyro_mag


def compute_fra(h, peak_g, peak_gyro):
    """Fracture Risk Analysis -> Low / Moderate / High / Severe."""
    score = 0.0
    score += min(h / 1.5, 1.0) * 0.40
    score += min(peak_g / 4.0, 1.0) * 0.35
    score += min(peak_gyro / 400.0, 1.0) * 0.25
    if score >= 0.75:
        return "Severe", score
    elif score >= 0.50:
        return "High", score
    elif score >= 0.25:
        return "Moderate", score
    return "Low", score


def squash_0_100(x, k):
    return float(100 * (1 - np.exp(-max(x, 0.0) / k)))


def compute_piii(window, dt=DT):
    """Pre-Impact Instability Index: jerk + gyro divergence over first 40% of window."""
    n = len(window)
    seg = window[:max(int(n * 0.4), 2)]
    acc_mag, gyro_mag = resultant_series(seg)
    jerk = np.diff(acc_mag) / dt
    jerk_energy = float(np.mean(jerk ** 2)) if len(jerk) > 0 else 0.0
    gyro_div = float(np.std(gyro_mag))
    piii_raw = jerk_energy * 0.6 + gyro_div * 0.4
    return squash_0_100(piii_raw, k=25.0)


def compute_cfss7(window, dt=DT):
    """Composite Fall Severity Score (0-100), 7 components."""
    acc_mag, gyro_mag = resultant_series(window)
    n = len(window)

    peak_g = float(np.max(acc_mag))
    peak_gyro = float(np.max(gyro_mag))
    rot_disp = float(np.trapz(gyro_mag, dx=dt))                    # deg (approx)
    impact_thresh = 1.5
    above = acc_mag > impact_thresh
    impact_duration = float(np.sum(above) * dt)

    tail = acc_mag[int(n * 0.8):]
    immobility_var = float(np.var(tail)) if len(tail) > 0 else 0.0

    peak_idx = int(np.argmax(acc_mag))
    post = acc_mag[peak_idx + 1:]
    secondary_impacts = 0
    for i in range(1, len(post) - 1):
        if post[i] > impact_thresh and post[i] > post[i - 1] and post[i] > post[i + 1]:
            secondary_impacts += 1

    recovery_seg = acc_mag[int(n * 0.6):]
    recovery_effort = float(np.std(recovery_seg)) if len(recovery_seg) > 0 else 0.0

    c1 = min(peak_g / 4.0, 1.0)
    c2 = min(peak_gyro / 400.0, 1.0)
    c3 = min(rot_disp / 1800.0, 1.0)
    c4 = min(impact_duration / 0.5, 1.0)
    c5 = 1.0 - min(immobility_var / 2.0, 1.0)     # low variance (immobility) -> higher severity
    c6 = min(secondary_impacts / 3.0, 1.0)
    c7 = min(recovery_effort / 2.0, 1.0)

    weights = [0.20, 0.15, 0.15, 0.15, 0.20, 0.10, 0.05]
    components = [c1, c2, c3, c4, c5, c6, c7]
    cfss = float(np.clip(sum(w * c for w, c in zip(weights, components)) * 100, 0, 100))

    stats = {
        'peak_g': peak_g, 'peak_gyro': peak_gyro, 'rot_disp_deg': rot_disp,
        'impact_duration_s': impact_duration, 'immobility_var': immobility_var,
        'secondary_impacts': secondary_impacts, 'recovery_effort': recovery_effort,
    }
    return cfss, stats


def sleep_vs_collapse(activity_name, event_name, stats):
    if activity_name != 'SLEEP':
        return None
    if event_name == 'NORMAL':
        return "INTENTIONAL_REST"
    if event_name == 'FALL':
        if stats['immobility_var'] < 0.05 and stats['peak_g'] > 1.3:
            return "COLLAPSE_FROM_REST_SUSPECTED_SYNCOPE"
        return "SLEEP_MOVEMENT_FALSE_ALARM_REVIEW"
    return "SLEEP_NEAR_FALL_REVIEW"


def dispatch_triage(event_name, fra_level, cfss, stats):
    immobility_flag = stats['immobility_var'] < 0.05
    recovery_flag = stats['recovery_effort'] > 0.3

    if event_name == 'FALL':
        if fra_level == 'Severe' or cfss >= 75 or immobility_flag:
            return 'CRITICAL'
        elif recovery_flag:
            return 'HIGH'
        return 'HIGH'  # confirmed fall, ambiguous -> default HIGH, never silently downgraded
    elif event_name == 'NEAR_FALL':
        return 'WATCH'
    return 'QUIET'


def full_risk_analysis(raw_window, activity_name, event_name):
    h, t_ff, peak_idx, acc_mag, gyro_mag = compute_fhe(raw_window)
    peak_g = float(np.max(acc_mag))
    peak_gyro = float(np.max(gyro_mag))
    fra_level, fra_score = compute_fra(h, peak_g, peak_gyro)
    cfss, stats = compute_cfss7(raw_window)
    piii = compute_piii(raw_window)
    sleep_status = sleep_vs_collapse(activity_name, event_name, stats)
    triage = dispatch_triage(event_name, fra_level, cfss, stats)
    return {
        'fall_height_m': h, 'freefall_s': t_ff, 'peak_g': peak_g, 'peak_gyro': peak_gyro,
        'fra_level': fra_level, 'fra_score': fra_score, 'cfss7': cfss, 'piii': piii,
        'stats': stats, 'sleep_status': sleep_status, 'triage': triage,
    }

# ============================================================================
# SECTION 9: INT8 TFLITE EXPORT
# ============================================================================

def representative_dataset_gen():
    rng = np.random.default_rng(SEED)
    n = min(200, len(X_train))
    idxs = rng.choice(len(X_train), size=n, replace=False)
    for i in idxs:
        yield [X_train[i:i + 1].astype(np.float32)]

converter = tf.lite.TFLiteConverter.from_keras_model(model)
converter.optimizations = [tf.lite.Optimize.DEFAULT]
converter.representative_dataset = representative_dataset_gen
converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS_INT8]
converter.inference_input_type = tf.int8
converter.inference_output_type = tf.int8

tflite_model = converter.convert()
os.makedirs(os.path.dirname(TFLITE_PATH), exist_ok=True)
with open(TFLITE_PATH, 'wb') as f:
    f.write(tflite_model)

print(f"\nINT8 TFLite model exported: {TFLITE_PATH} ({len(tflite_model)/1024:.1f} KB)")

interpreter = tf.lite.Interpreter(model_path=TFLITE_PATH)
interpreter.allocate_tensors()
input_details = interpreter.get_input_details()
output_details = interpreter.get_output_details()


def tflite_predict(norm_window):
    inp = input_details[0]
    scale, zero_point = inp['quantization']
    scale = scale if scale != 0 else 1.0
    x_q = np.round(norm_window.astype(np.float32) / scale + zero_point).astype(np.int8)
    x_q = np.expand_dims(x_q, axis=0)
    interpreter.set_tensor(inp['index'], x_q)
    interpreter.invoke()

    activity_probs, event_probs = None, None
    for od in output_details:
        s, z = od['quantization']
        s = s if s != 0 else 1.0
        raw = interpreter.get_tensor(od['index'])[0].astype(np.float32)
        deq = (raw - z) * s
        if len(deq) == len(ACTIVITY_CLASSES):
            activity_probs = deq
        elif len(deq) == len(EVENT_CLASSES):
            event_probs = deq
    return activity_probs, event_probs

# ============================================================================
# SECTION 10: FULL TEST-SET BATCH ANALYSIS (for the summary board)
# ============================================================================

print("\n" + "=" * 78)
print("RUNNING FULL TEST-SET RISK ANALYSIS")
print("=" * 78)

board = {
    'total_windows': 0,
    'total_normal': 0,
    'total_near_falls': 0,
    'total_confirmed_falls': 0,
    'total_collapses_from_rest': 0,
    'fall_heights': [],
    'total_critical': 0,
}

for i in tqdm(range(len(test_idx)), desc="Analyzing test windows"):
    activity_name = IDX2ACT[int(act_pred_test[i])]
    event_name = IDX2EVT[int(evt_pred_test[i])]
    result = full_risk_analysis(raw_test[i], activity_name, event_name)

    board['total_windows'] += 1
    if result['triage'] == 'QUIET':
        board['total_normal'] += 1
    if event_name == 'NEAR_FALL':
        board['total_near_falls'] += 1
    if event_name == 'FALL':
        board['total_confirmed_falls'] += 1
        board['fall_heights'].append(result['fall_height_m'])
    if result['sleep_status'] == 'COLLAPSE_FROM_REST_SUSPECTED_SYNCOPE':
        board['total_collapses_from_rest'] += 1
    if result['triage'] == 'CRITICAL':
        board['total_critical'] += 1

# ============================================================================
# SECTION 11: LIVE CLINICAL SIMULATION (20 random samples, INT8 TFLite)
# ============================================================================

print("\n" + "=" * 78)
print("LIVE CLINICAL SIMULATION — 20 RANDOM TEST SAMPLES (INT8 EDGE MODEL)")
print("=" * 78)

sim_rng = np.random.default_rng(SEED + 1)
sample_indices = sim_rng.choice(len(test_idx), size=min(20, len(test_idx)), replace=False)

for n, i in enumerate(sample_indices, 1):
    raw_win = raw_test[i]
    norm_win = X_test[i]

    activity_probs, event_probs = tflite_predict(norm_win)
    activity_name = IDX2ACT[int(np.argmax(activity_probs))]
    event_name = IDX2EVT[int(np.argmax(event_probs))]
    true_activity = IDX2ACT[int(ya_test[i])]
    true_event = IDX2EVT[int(ye_test[i])]

    result = full_risk_analysis(raw_win, activity_name, event_name)
    s = result['stats']

    print(f"\n----- SAMPLE {n:02d}/20 (test idx {i}) -----")
    print(f"1) Activity (AI): {activity_name:8s} | Ground truth: {true_activity}")
    print(f"   Event    (AI): {event_name:10s} | Ground truth: {true_event}")
    print(f"2) Detected Event: {event_name}")
    print(f"3) Physics — Fall Height: {result['fall_height_m']:.3f} m | "
          f"Peak Impact: {result['peak_g']:.2f} g | Free-fall duration: {result['freefall_s']:.3f} s")
    print(f"4) Risk — CFSS-7: {result['cfss7']:.1f}/100 | PIII: {result['piii']:.1f}/100 | "
          f"Fracture Risk: {result['fra_level']} (score {result['fra_score']:.2f})")
    print(f"   Sub-stats — Rotational Disp: {s['rot_disp_deg']:.1f} deg | "
          f"Impact Duration: {s['impact_duration_s']:.2f}s | Immobility Var: {s['immobility_var']:.4f} | "
          f"Secondary Impacts: {s['secondary_impacts']} | Recovery Effort: {s['recovery_effort']:.3f}")
    if result['sleep_status']:
        print(f"   Sleep/Collapse Disambiguation: {result['sleep_status']}")
    print(f"5) ACTION -> TRIAGE PRIORITY: {result['triage']}")

# ============================================================================
# SECTION 12: GLOBAL PATIENT SUMMARY TRACKING BOARD
# ============================================================================

avg_fall_height = float(np.mean(board['fall_heights'])) if board['fall_heights'] else 0.0

print("\n" + "=" * 78)
print("GLOBAL PATIENT SUMMARY TRACKING BOARD")
print("=" * 78)
print(f"Total Windows Analyzed              : {board['total_windows']}")
print(f"Total Normal Activities              : {board['total_normal']}")
print(f"Total Near-Falls / Stumbles          : {board['total_near_falls']}")
print(f"Total Confirmed Falls                : {board['total_confirmed_falls']}")
print(f"Total Collapses from Rest / Fainting : {board['total_collapses_from_rest']}")
print(f"Average Fall Height (confirmed falls): {avg_fall_height:.3f} m")
print(f"Total CRITICAL Alerts Dispatched     : {board['total_critical']}")
print("=" * 78)
