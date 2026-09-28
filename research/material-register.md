# Material register and provenance

This register records which in-scope working materials were carried into the research folder and why other WIP categories were not republished. The selected working files contain no reliable author, affiliation, formal publication date, or license metadata. File-system modification times are not treated as authorship or creation dates. No project license is added or implied.

## Included working materials

| Repository path | Source and provenance | Review, changes, and relevance |
|---|---|---|
| [`working/LandMaskProbe.ps1`](working/LandMaskProbe.ps1) | Supplied as `LandMaskProbe.ps1` in the local WIP folder. Source SHA-256: `53F2E9F482A3183443E9E54D2ACFBDA2E6F648ADE88C3DD25C9D7458494AB96B`. No author or license header is present. | Exploratory probe of the embedded Natural Earth land-mask implementation. Its obsolete generated-output paths were changed to resolve the current repository files; its printed result now calls the fixed coordinate a fixture rather than asserting a storm observation. It is not part of the standard validation run and was not executed during publication. |
| [`working/probe_land.py`](working/probe_land.py) | Supplied as `probe_land.py` in the local WIP folder. Source SHA-256: `494FB7E9B0A27E9BC2B7614F5655221AE0B0671BB44D03ED2991C15F912656B5`. No author or license header is present. | Exploratory point-in-polygon check using the Python standard library. Its old generated-output path was changed to locate the already-bundled shapefile relative to the repository. Its coordinate list is a test fixture, not a sourced observation or reported result. The script was not executed during publication. |
| [`working/windy-facing-overlay.ps1`](working/windy-facing-overlay.ps1) | Supplied as `windy-facing-overlay.ps1` in the local WIP folder. Source SHA-256: `19D6F87CAFBFCCEFAF66A990CC4C82653C73B9827E3BEA4C399C6B921511F668`. No author or license header is present. | Preserved unchanged as a Windows-only visual prototype. It draws a schematic overlay on a visible Chrome window and uses visually estimated placement; it does not retrieve the NHC feed or establish geographic accuracy. It is not the supported entry point, is not part of validation, and was not executed during publication. On startup failure it can write a local diagnostic log. |

The files are identified by their supplied WIP location and hashes rather than by an invented personal authorship claim. No third-party source attribution was found in these three files during review; no general reuse license is asserted for them.

## Established project sources

| Material | Provenance and use | Rights and limits |
|---|---|---|
| NHC `CurrentStorms.json` and linked GIS products | [NHC active-storm feed](https://www.nhc.noaa.gov/CurrentStorms.json); the application reads this feed and its linked storm products. The README links NHC's [wind-speed probability graphics](https://www.nhc.noaa.gov/aboutnhcgraphics.shtml) and [cone explanation](https://www.nhc.noaa.gov/aboutcone.shtml). | NHC descriptions support the source meanings stated in the application docs. The validation suite does not download or evaluate live products. |
| Natural Earth 1:10m land | The existing project archive `data\Natural_Earth_ne_10m_land.zip` includes Natural Earth's source README and is described in the [Natural Earth 10m land source page](https://www.naturalearthdata.com/downloads/10m-physical-vectors/10m-land/). | Natural Earth identifies this data as public domain. The duplicate WIP ZIP and `.shp` were hash-checked against the existing project files and were not copied a second time. The geometry is generalized map data, not ground truth. |

## Excluded WIP categories

| Category | Publication decision and reason |
|---|---|
| Desktop, monitor, Windy, and frame-capture images; raw pixel dumps; captured runtime JSON | Excluded as captured screen or machine-state data. The images may include private desktop context and third-party interface material; the JSON describes local display configuration. |
| Runtime/error logs | Excluded. The inspected logs contain a machine-specific local workspace path. That path and log contents are not reproduced here. |
| Military training-document collection | Excluded in full. It contains third-party manuals whose rights and relevance to TOOLANG were not established; no manual text, image, or document file is republished. |
| Screen-capture utilities and address-bar diagnostics | Excluded because they capture the visible desktop or emit current browser address-bar content, creating avoidable privacy risk. |
| Fixed-display overlay variants and time-sensitive live-feed preflight probes | Excluded because they rely on installation-specific display coordinates, hard-coded example locations, obsolete generated-output paths, or a particular active-storm response. They are not repeatable evidence for this repository. |
| Extracted Natural Earth files duplicated from the retained source archive | Not copied separately. The already-included source archive retains its attribution and provenance; the duplicate archive and shapefile matched the project copies by SHA-256. |

The exclusions above are categories, not citations. They provide no basis for claims or findings in this project. Captures, logs, and third-party manuals were not used as research evidence.

## Project license status

No license is specified for TOOLANG source code, documentation, or the included exploratory scripts. Their inclusion does not grant a general reuse license. The Natural Earth data has its separate public-domain provenance described above.
