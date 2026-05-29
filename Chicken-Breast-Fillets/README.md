# 🍗 Chicken Breast Fillets — Hyperspectral Imaging

**Target:** Poultry myopathy classification (Woody Breast, Spaghetti Meat, Normal)  
**Sensor:** VIS Push-broom HSI Camera — 400–1000 nm, 448 bands  
**Lab:** SAFE Lab, University of Arkansas

---

## Overview

This sub-project processes hyperspectral image cubes of raw chicken breast fillets to extract reflectance spectra for myopathy classification. Myopathies such as **Woody Breast (WB)** and **Spaghetti Meat (ST)** alter the muscle fibre structure and biochemical composition of the fillet, producing measurable spectral differences in the visible range.

The pipeline covers:
1. Dark/white reference calibration
2. Binary mask segmentation to isolate the fillet from the conveyor background
3. Per-pixel spectral extraction across the masked ROI
4. Savitzky-Golay smoothing of the mean spectrum
5. Export-ready data for downstream ML classification

---

## 📸 Sample Outputs

> Place your figures inside the `sample_outputs/` folder and they will render here automatically.

### RGB Preview & Binary Mask
| RGB Preview | Segmented Mask |
|---|---|
| ![RGB Preview](./sample_outputs/rgb_preview.png) | ![Binary Mask](./sample_outputs/binary_mask.png) |

### Mean Calibrated Reflectance Spectra
![Reflectance Spectra](./sample_outputs/reflectance_spectra.png)
*Mean calibrated reflectance (400–1000 nm) for Normal, Woody Breast, and Spaghetti Meat fillets after SG smoothing.*

### False-Colour HSI Visualisation
![False Colour](./sample_outputs/false_colour.png)
*Composite false-colour image rendered from three selected wavelength bands.*

---

## 📄 Scripts

| Script | Description |
|---|---|
| `spectral_extraction_calibration.m` | Loads ENVI cube, calibrates with dark/white references, extracts ROI spectra via binary mask, smooths with SG filter, plots mean reflectance |
| `image_segmentation.m` | Segments the fillet from the background using adaptive thresholding, morphological operations, and largest-component extraction; exports the binary mask |

---

## 🗂️ Expected Data Structure

Your local data folder should follow this layout:

```
<DATA_ROOT>/
└── <SAMPLE_NAME>/
    ├── <SAMPLE_NAME>.png              ← RGB preview image (for segmentation)
    └── capture/
        ├── <SAMPLE_NAME>.hdr          ← Raw hyperspectral cube header (ENVI)
        ├── <SAMPLE_NAME>.raw          ← Raw hyperspectral cube data
        ├── DARKREF_<REF_NAME>.hdr     ← Dark reference header
        ├── DARKREF_<REF_NAME>.raw     ← Dark reference data
        ├── WHITEREF_<REF_NAME>.hdr    ← White reference header
        └── WHITEREF_<REF_NAME>.raw    ← White reference data
```

**Naming convention used in this lab:**
```
chai_WB_08_2025-02-20_23-04-36    →  Woody Breast sample 8
chai_NB_01_2025-02-20_23-10-23    →  Normal Breast sample 1
Yang_ST_1_2025-02-28_20-10-22     →  Spaghetti Meat sample 1
```

> Dark and white references may come from a **different dataset** (`REF_NAME`) than the sample itself. This is normal when references are captured once per imaging session and shared across multiple samples.

---

## ⚙️ Configuration

Open either script and edit the **USER CONFIGURATION** block at the top:

```matlab
% =========================================================================
%  USER CONFIGURATION — Edit these three lines only
% =========================================================================

DATA_ROOT   = "C:\Your\Data\Path\";          % <-- your local data folder
SAMPLE_NAME = "your_sample_name_here";        % <-- sample dataset name
REF_NAME    = "your_reference_name_here";     % <-- dark/white ref dataset name
```

---

## 🚀 Quick Start

```matlab
% 1. Open MATLAB and navigate to this folder
cd('path/to/Hyperspectral-Imaging/Chicken-Breast-Fillets')

% 2. Run segmentation first to verify the mask looks correct
run('image_segmentation.m')

% 3. Then run extraction to get the calibrated spectrum
run('spectral_extraction_calibration.m')
```

---

## 📊 Output Variables

| Variable | Size | Description |
|---|---|---|
| `BW` | H × W | Binary mask (1 = fillet ROI, 0 = background) |
| `calibrated_data` | H × W × Bands | Calibrated reflectance cube |
| `extracted_data` | Bands × N_pixels | Per-pixel spectra for all ROI pixels |
| `E_smoothed` | Bands × 1 | Mean smoothed reflectance spectrum |

---

## 🔗 Related Work

- **MyoVision** iOS app — real-time myopathy classification using NEATBoost-Attention ensemble  
- **NAS-WD** — neural architecture search for woody breast detection (AI in Agriculture, 2024)  
- **AS7265x multispectral sensor** — low-cost 18-band system achieving 92% 3-class accuracy  

---

## 📬 Contact

Chaitanya Pallerla — `pallerla@uark.edu`  
[← Back to main repository](../README.md)
