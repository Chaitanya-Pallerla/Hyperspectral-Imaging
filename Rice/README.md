# 🌾 Rice — Hyperspectral Imaging

**Target:** Grain chalkiness classification  
**Sensor:** VIS Push-broom HSI Camera — 400–1000 nm, 448 bands  
**Lab:** SAFE Lab, University of Arkansas

---

## Overview

This sub-project processes hyperspectral image cubes of rice grains to classify **chalkiness** — a quality defect caused by loosely packed starch granules that scatter light and reduce grain translucency. Chalky rice commands lower market prices and has inferior milling yield.

HSI provides a **non-destructive** alternative to manual visual scoring by capturing per-grain spectral signatures that correlate with the degree of chalkiness across the full grain surface.

The pipeline covers:
1. Dark/white reference calibration (400–1000 nm)
2. Individual grain segmentation using adaptive thresholding and watershed
3. Superpixel-level feature extraction using **SFRM** (Spatial Feature Region Mapping)
4. Per-grain mean spectrum computation
5. Export for SVM / Random Forest classification

---

## 📸 Sample Outputs

> Place your figures inside the `sample_outputs/` folder and they will render here automatically.

### RGB Preview & Grain Segmentation
| RGB Preview | Segmented Grains |
|---|---|
| ![RGB Preview](./sample_outputs/rgb_preview.png) | ![Grain Segmentation](./sample_outputs/grain_segmentation.png) |

### Per-Grain Reflectance Spectra
![Grain Spectra](./sample_outputs/grain_spectra.png)
*Mean calibrated reflectance for normal (translucent) vs chalky rice grains across 400–1000 nm. Chalky grains exhibit elevated short-wavelength reflectance due to air pocket scattering.*

### Chalkiness Classification Map
![Classification Map](./sample_outputs/classification_map.png)
*Pseudo-colour overlay mapping each segmented grain to its predicted class: Normal (green), Chalky (red), Partially Chalky (orange).*

---

## 📄 Scripts

| Script | Description |
|---|---|
| `spectral_extraction_calibration.m` | Loads ENVI cube, calibrates, extracts per-grain mean spectra using labelled grain masks, exports feature matrix |
| `image_segmentation.m` | Segments individual rice grains using adaptive thresholding, distance transform, and watershed; assigns unique labels to each grain; exports labelled mask |

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

% Minimum grain area in pixels — smaller objects will be discarded as noise
MIN_GRAIN_AREA = 500;    % <-- adjust based on your image resolution
```

---

## 🚀 Quick Start

```matlab
cd('path/to/Hyperspectral-Imaging/Rice')
run('image_segmentation.m')               % verify grain labels
run('spectral_extraction_calibration.m')  % extract per-grain spectra
```

---

## 📊 Output Variables

| Variable | Size | Description |
|---|---|---|
| `grain_labels` | H × W | Integer-labelled grain mask (0 = background) |
| `calibrated_data` | H × W × Bands | Calibrated reflectance cube |
| `grain_spectra` | N_grains × Bands | Mean spectrum per grain |
| `grain_stats` | N_grains × 1 struct | Area, centroid, bounding box per grain |

---

## 🔗 Related Work

- **Rice chalkiness classification** — HSI with SFRM achieving 96.96% 3-class accuracy (manuscript at major revision)

---

## 📬 Contact

Chaitanya Pallerla — `pallerla@uark.edu`  
[← Back to main repository](../README.md)
