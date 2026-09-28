# Research guide

This repository can be read as an engineering case study of a local map overlay that keeps several weather and geography layers visibly distinct. It is not a paper, a forecast product, or a report of a controlled user or meteorological study. The source tree does not establish a named author, institution, publication date, DOI, or peer-review status, so none is assigned here.

## Questions and scope

The project supports two bounded engineering questions:

1. How can a desktop overlay distinguish current NHC storm motion, forecast-track geometry, the forecast cone, wind-radius products, probability bands, and nearest-land geometry instead of presenting them as interchangeable claims?
2. Which map-view parsing and scale-calculation behaviors can be checked deterministically without starting the UI or relying on a live NHC response?

These are design and software-validation questions, not claims that the overlay improves decisions or predicts impacts accurately.

## Evidence and method

- The application reads the NHC active-storm feed and linked GIS products. It labels current motion separately from forecast geometry and reports cumulative point probabilities as source-provided categories.
- Windy supplies the visible map context. The application reads its visible address-bar URL and, when available, accessible map bounds; it does not use Windy's rendered weather colors as numeric data.
- Nearest-land geometry uses the bundled Natural Earth 1:10m land polygons. The result is generalized cartographic geometry, not ground truth or a landfall forecast.
- The offline validation runner parses the PowerShell source, compiles embedded C#, and exercises the URL parser and map-scale function. Its latest result and explicit limitations are recorded in [`../validation/validation-results.json`](../validation/validation-results.json).
- Selected files under [`working/`](working/) preserve exploratory land-mask and overlay code supplied with the project materials. They are kept separate from the supported application and standard validation runner.

The source links and material-by-material provenance decisions are listed in the [material register](material-register.md). The NHC probability and cone descriptions and the Natural Earth source are also linked in the [application README](../README.md).

## Evaluation limits

The offline checks do not start Chrome, invoke Windows UI Automation or GDI rendering, request NHC data, compare a forecast with observations, assess geolocation accuracy, or conduct a human-subject study. PowerShell parser success is not static type checking. Compiling the embedded C# does not establish the correctness of live rendering or of source data.

Accordingly, the supported result is limited to the checks named in the validation manifest. The prototypes are not production alternatives or independent scientific validation, and their fixture coordinates are not presented as storm observations.

## Interpretation

The overlay is a visual aid. NHC products and Natural Earth geometry have different meanings and spatial limitations; they should remain source-labeled and should not be combined into a claim about where a storm will go or where impacts will occur. This repository does not claim a measured improvement in forecast skill, safety, usability, or decision quality.
