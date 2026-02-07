# Build Overview

This document provides a high-level overview of the build structure and design
flow of the AXI-based stereo delay project.

The design is intentionally structured to be:
- reproducible via TCL scripts
- independent from Vivado GUI state
- suitable for academic review and long-term maintenance

---

## Project Structure

The repository is organized as follows:

- `rtl/`
  - Core RTL modules (`delay_core`, `delay_axis`)
- `sim/`
  - Testbenches and simulation utilities
- `scripts/`
  - TCL scripts for project and block design creation
- `docs/`
  - Design documentation and validation notes
- `result/`
  - Simulation results and analysis based on CSV data

---

## Build Flow Summary

1. **Project Creation**
   - A Vivado project is created via `create_project.tcl`
   - Target board: Kria KV260
   - Board preset is applied to the Processing System

2. **Source Import**
   - RTL sources are added explicitly
   - Simulation sources are added separately

3. **Block Design Generation**
   - Block design is created using `bd.tcl`
   - No GUI-generated layout information is used

4. **Wrapper Generation**
   - HDL wrapper is generated from the block design
   - Wrapper becomes the synthesis top-level

---

## Design Philosophy

- All automation is TCL-based
- Generated files are minimized and excluded from version control
- The repository favors clarity and determinism over tool convenience

This approach ensures that the design can be rebuilt on a clean machine with
minimal manual intervention.
