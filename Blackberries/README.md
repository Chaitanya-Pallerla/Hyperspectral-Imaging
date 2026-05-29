# 🫐 Blackberries — Hyperspectral Imaging

**Target:** Fruit quality — Total Soluble Solids (TSS / °Brix) prediction  
**Sensor:** VIS + NIR Push-broom HSI Camera — 400–1700 nm  
**Lab:** SAFE Lab, University of Arkansas

---

## Overview

This sub-project processes hyperspectral image cubes of blackberry fruit to predict **Total Soluble Solids (TSS)**, measured in °Brix, as a proxy for ripeness and sweetness. TSS is a key quality metric in berry production and is traditionally measured destructively with a refractometer.

HSI enables **non-destructive, spatially resolved** TSS mapping across the fruit surface, supporting both research and inline grading applications.

The pipeline covers:
1. Dark/white reference calibration across the full VIS–NIR range
2. Fruit segmentation from the conveyor/tray background
3. Per-pixel spectral extraction and SNV (Standard Normal Variate) normalisation
4. Physics-informed feature engineering (spectral indices, FOD — First-Order Derivative)
5. Export for regression modelling (PLSR, SVR, PINN)

---

## 📸 Sample Outputs

> Place your figures inside the `sample_outputs/` folder and they will render here automatically.

### RGB Preview & Segmentation Mask
| RGB Preview | Fruit Mask |
|---|---|
| ![RGB Preview](./sample_outputs/rgb_preview.png) | ![Fruit Mask](./sample_outputs/fruit_mask.png) |

### Mean Reflectance Spectrum (VIS–NIR)
![Reflectance Spectra](./sample_outputs/reflectance_spectra.png)
*Mean calibrated reflectance across the 400–1700 nm range for blackberries at different ripeness stages.*

### TSS Prediction Map
![TSS Map](./sample_outputs/tss_map.png)
*Spatial °Brix prediction map overlaid on the fruit surface (false-colour, warm = higher TSS).*

---

## 📄 Scripts

| Script | Description |
|---|---|
| `spectral_extraction_calibration.m` | Loads ENVI cube, applies dark/white calibration, SNV normalisation, extracts ROI spectra, exports for regression |
| `image_segmentation.m` | Segments individual berries using colour thresholding in HSV space and morphological operations; handles overlapping fruit via watershed separation |

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

% TSS reference values (from refractometer, one per fruit)
% Used to pair spectral data with ground truth for regression
TSS_REFERENCE = [12.3, 14.1, 11.8, 13.5];    % <-- °Brix values, one per sample
```

---

## 🚀 Quick Start

```matlab
cd('path/to/Hyperspectral-Imaging/Blackberries')
run('image_segmentation.m')          % verify fruit masks
run('spectral_extraction_calibration.m')   % extract + export spectra
```

---

## 📊 Output Variables

| Variable | Size | Description |
|---|---|---|
| `BW` | H × W | Binary mask (1 = fruit pixels) |
| `calibrated_data` | H × W × Bands | Calibrated reflectance cube |
| `spectra_snv` | Bands × N_pixels | SNV-normalised per-pixel spectra |
| `E_smoothed` | Bands × 1 | Mean smoothed spectrum |

---

## 🔗 Related Work

- **Physics-Informed Spectral Transformer (PI-SpecTF)** — PINN-based TSS prediction from NIR spectral data with 9 physics loss terms

---

## 📬 Contact

Chaitanya Pallerla — `pallerla@uark.edu`  
[← Back to main repository](../README.md)
