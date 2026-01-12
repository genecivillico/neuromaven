# Neuromaven

**Neuromaven** is an open-source repository of data processing workflows and analytical scripts for neural signal analysis.
It captures a collection of domain-specific procedures used to extract, preprocess, and visualize features from brain electrophysiology recordings, with an emphasis on reproducibility, clarity, and scientific utility.

This code has been developed collaboratively and used in real biomedical research — including brain signal reliability studies at **FDA/CDRH** — and reflects mature practices for handling neural time series data in support of machine-learning-based biomarker development.

---

## 🌟 Why Neuromaven Matters

Neuromaven exists to help researchers and engineers:

* **Understand the structure of neural data**
* **Preprocess complex electrophysiological recordings**
* **Extract and visualize meaningful signal features**
* **Prepare curated features for downstream machine learning models**
  (e.g., biomarker discovery, classification, reliability assessment)

This repository demonstrates practical expertise in neural signal workflows — a core competency for roles in neuro-AI and computational biomarkers such as at *neumarker.ai*.

---

## 📂 Repository Overview

The current structure includes:

```
.
├── analysis protocols/      # Empirical processing and analysis workflows
├── *.ipf files              # Igor Pro scripts for neural data processing
└── documentation & slides   # Instructions and high-level protocol descriptions
```

### Key Script Categories

| Script Group                | Purpose                                              |
| --------------------------- | ---------------------------------------------------- |
| `LoadNeuralynx-v*`          | Import and standardize Neuralynx recordings          |
| `batch*`                    | Batch processing jobs for large datasets             |
| `coherencepolish.ipf`       | Compute and refine coherence measures                |
| `bandfinder.ipf`            | Identify relevant frequency bands in signals         |
| `aggregatefromdatabase.ipf` | Compile distributed results into analyzable datasets |
| `quickchecker.ipf`          | Rapid data sanity checks and quality control         |

These routines embody real analytical steps from raw signal to research-ready features.

---

## 🧠 What You *Can* Do With This Code

### ✅ Neural Data Preparation

* Load continuous neural time series (e.g. LFP, EEG, depth electrodes)
* Standardize signal formats across subjects and sessions
* Clean artifacts systematically

### ✅ Feature Extraction

* Compute spectral, coherence, and band-specific metrics
* Extract features with statistical and neuroscientific relevance
* Organize multi-session results for modeling

### ✅ Visualization & Validation

* Rapid QC plots and summary metrics to confirm data integrity
* Visualize feature distributions before and after preprocessing
* Support reproducibility with scripted, automated workflows

---

## 🚀 For Open-Source Contributors

We welcome contributions that:

* Add **unit tests** or **example datasets**
* Convert legacy Igor Pro procedures to **Python (e.g., MNE / NumPy / SciPy)**
* Add visualization dashboards (e.g., **Plotly / Seaborn notebooks**)
* Provide ML-ready pipelines (feature matrices + labels)

If you contribute, please:

1. Fork the repo
2. Create a descriptive feature branch
3. Open a pull request with a clear description
4. Include tests and visualization examples where applicable

---

## 📈 For Researchers

Neuromaven is designed as a **research asset**:

* Reproduce key preprocessing steps from external studies
* Validate feature sets against reliability assessments
* Prototype new analysis ideas for neural biomarkers

If your work involves neural time series, you can use these scripts as a **baseline reproducible workflow**, and extend them into statistical modeling or deep learning pipelines.

---

## 🧪 Research Provenance

This repository was actively used in **brain signal reliability studies for FDA/CDRH** evaluations — helping ensure methods were traceable, well-documented, and scientifically grounded.

---

## 🧑‍💻 Licensing & Citation

Please include proper attribution if you reuse or adapt this code in academic or commercial settings.

---
