# 🔧 Utils — Shared Helper Functions

Shared MATLAB utility functions used across sub-projects.

---

## Functions (Planned)

| Function | Description |
|---|---|
| `envi_load.m` | Wrapper for `enviinfo` + `multibandread` with path validation and error messages |
| `calibrate_cube.m` | Standalone dark/white calibration — takes raw, dark, white cubes and returns reflectance cube |
| `extract_roi_spectra.m` | Extracts per-pixel spectra from a calibrated cube given a binary or labelled mask |
| `sg_smooth_spectra.m` | Applies Savitzky-Golay filter to a spectra matrix (Bands × N) with configurable window and order |
| `plot_mean_spectrum.m` | Standardised spectral plot with wavelength axis, grid, shaded std band, and legend |
| `export_spectra_csv.m` | Saves extracted spectra + class labels to CSV for downstream ML pipelines in Python or R |
| `false_colour_render.m` | Renders a false-colour RGB composite from three user-selected wavelength bands |

---

## Usage

Once a utility is available, call it from any sub-project script:

```matlab
% Add utils to path (run once per session)
addpath('../utils')

% Example: load an ENVI cube with error handling
[cube, info] = envi_load(hdr_path, raw_path);

% Example: calibrate
reflectance = calibrate_cube(cube, dark_cube, white_cube);

% Example: extract ROI spectra
spectra = extract_roi_spectra(reflectance, BW_mask);
```

---

[← Back to main repository](../README.md)
