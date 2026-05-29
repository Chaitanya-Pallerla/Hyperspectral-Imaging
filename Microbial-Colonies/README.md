# 🧫 Microbial Colonies — Hyperspectral Imaging

**Target:** Colony-level microbial classification (E. coli, Listeria, Salmonella, and others)  
**Sensor:** VIS Push-broom HSI Camera — 400–1000 nm, 448 bands  
**Lab:** SAFE Lab, University of Arkansas

---

## Overview

This sub-project processes hyperspectral image cubes of agar plates to classify **microbial colonies** by species based on their spectral reflectance signatures. Traditional microbial identification requires 24–72 hours of culturing and biochemical testing. HSI offers a potential pathway to faster, **non-destructive, label-free** colony identification directly from the plate.

Each colony type produces a characteristic spectral profile driven by differences in pigmentation, cell wall composition, and colony morphology — all of which scatter and absorb light differently across 400–1000 nm.

The pipeline covers:
1. Dark/white reference calibration
2. Agar plate background removal and individual colony segmentation
3. Per-colony mean spectrum extraction
4. Savitzky-Golay smoothing and derivative feature computation
5. Export for 7-class classification (SA, ST, EC, F18, K12, LM, LI)

---

## 📸 Sample Outputs

> Place your figures inside the `sample_outputs/` folder and they will render here automatically.

### Agar Plate RGB Preview & Colony Segmentation
| RGB Preview | Colony Mask |
|---|---|
| ![RGB Preview](./sample_outputs/rgb_preview.png) | ![Colony Mask](./sample_outputs/colony_mask.png) |

### Per-Species Mean Reflectance Spectra
![Colony Spectra](./sample_outputs/colony_spectra.png)
*Mean calibrated reflectance (400–1000 nm) for all 7 microbial classes. Shaded bands show ± 1 standard deviation across colonies of each class.*

### False-Colour Colony Map
![False Colour](./sample_outputs/false_colour_plate.png)
*False-colour composite image of the agar plate, highlighting spectral differences between colony types that are invisible in standard RGB.*

### Classification Confusion Matrix
![Confusion Matrix](./sample_outputs/confusion_matrix.png)

---

## 📄 Scripts

| Script | Description |
|---|---|
| `spectral_extraction_calibration.m` | Loads ENVI cube, applies calibration, extracts per-colony mean spectra using the labelled colony mask, exports feature matrix with class labels |
| `image_segmentation.m` | Removes agar background using HSV-space thresholding; detects individual colonies via DBSCAN clustering or connected-component analysis; assigns unique colony labels |

---

## 🗂️ Expected Data Structure

```
<DATA_ROOT>/
└── <SAMPLE_NAME>/
    ├── <SAMPLE_NAME>.png
    └── capture/
        ├── <SAMPLE_NAME>.hdr
        ├── <SAMPLE_NAME>.raw
        ├── DARKREF_<REF_NAME>.hdr
        ├── DARKREF_<REF_NAME>.raw
        ├── WHITEREF_<REF_NAME>.hdr
        └── WHITEREF_<REF_NAME>.raw
```

---

## ⚙️ Configuration

```matlab
% =========================================================================
%  USER CONFIGURATION
% =========================================================================

DATA_ROOT   = "C:\Your\Data\Path\";          % <-- your local data folder
SAMPLE_NAME = "your_sample_name_here";        % <-- sample dataset name
REF_NAME    = "your_reference_name_here";     % <-- dark/white ref dataset name

% Class labels — update to match your experimental species
CLASS_LABELS = {'SA', 'ST', 'EC', 'F18', 'K12', 'LM', 'LI'};  % <-- 7 classes

% Minimum colony area in pixels — smaller blobs discarded as noise
MIN_COLONY_AREA = 200;   % <-- adjust based on imaging resolution
```

---

## 🚀 Quick Start

```matlab
cd('path/to/Hyperspectral-Imaging/Microbial-Colonies')
run('image_segmentation.m')               % verify colony masks
run('spectral_extraction_calibration.m')  % extract per-colony spectra
```

---

## 📊 Output Variables

| Variable | Size | Description |
|---|---|---|
| `colony_labels` | H × W | Integer-labelled colony mask (0 = background/agar) |
| `calibrated_data` | H × W × Bands | Calibrated reflectance cube |
| `colony_spectra` | N_colonies × Bands | Mean spectrum per colony |
| `colony_class` | N_colonies × 1 | Class label string per colony |

---

## 🔗 Related Work

- **NEAT-WaveFormer** — NEAT-evolved TransformerMLP with confidence-gated dual-channel fusion (VIS + NIR) for 7-class microbial classification (journal submission in preparation)
- **MATLAB hyperspectral batch pipeline** — Batch processing of ENVI cubes for colony spectra with Savitzky-Golay filtering and calibration validation

---

## 📬 Contact

Chaitanya Pallerla — `pallerla@uark.edu`  
[← Back to main repository](../README.md)
