# AXI Stereo Delay (FPGA Reference Implementation)

This repository provides a **reference RTL implementation** of a
**stereo audio delay stage**
implemented in **Verilog** and integrated with **AXI-Stream** and **AXI-Lite**.

Target platform: **AMD Kria KV260**  
Focus: **RTL architecture, deterministic delay behavior, and AXI correctness**

The module is designed for **continuous real-time audio streaming**, not
block-based or offline processing.

---

## Overview

This module implements:

* **Function**: Per-channel audio delay (time-domain)
* **Delay type**: Integer-sample delay using circular buffers
* **Scope**: Minimal, single-purpose DSP building block

The design is intentionally **not generic** and **not feature-rich**.  
It exists to demonstrate **how an audio delay line is implemented in FPGA hardware**,  
not to provide a turnkey audio effects processor.

---

## Key Characteristics

* RTL written in **Verilog**
* **AXI-Stream** data interface (audio path)
* **AXI-Lite** control interface (delay configuration & enable)
* BRAM-based circular buffer
* Deterministic, cycle-accurate behavior
* Designed and verified for **real-time audio streaming**
* No software runtime included

---

## Architecture

High-level structure:

```
AXI-Stream In (Stereo)
|
v
+------------------------+
| Delay Core           |
| - Circular buffer    |
| - Integer delay      |
| - Safe pointer logic |
+------------------------+
|
v
AXI-Stream Out (Stereo)
```


Design notes:

* Processing is **fully synchronous**
* Delay arithmetic is isolated in `delay_core`
* AXI protocol handling is isolated in `delay_axis`
* No hidden state outside the RTL

---

## Data Format

* AXI-Stream width: **32-bit**
* Audio samples:
  * Signed **16-bit**
  * Stereo, interleaved:
    * `[15:0]`  → Left
    * `[31:16]` → Right
* Delay configuration:
  * Integer delay in **samples**
  * Controlled via AXI-Lite registers

---

## Latency

* **Fixed internal latency**: **1 clock cycle**
  * Due to BRAM read latency in the delay core
* Control signals (`tvalid`, `tlast`) are aligned accordingly

Latency is:

* deterministic
* independent of delay value
* independent of input signal

This behavior is intentional and suitable for streaming DSP pipelines.

---

## Control Interface (AXI-Lite)

The control interface exposes three registers:

| Offset | Register | Description |
|-------:|----------|-------------|
| 0x00   | CTRL     | Enable / freeze |
| 0x04   | DELAY_L  | Left-channel delay (samples) |
| 0x08   | DELAY_R  | Right-channel delay (samples) |

* `ENABLE = 1` → delay active  
* `ENABLE = 0` → core frozen (buffer not updated)
* Delay values are integer sample counts
* Upper bits of 32-bit registers are ignored

Detailed documentation is available in `/docs/address_map.md`.

---

## Verification & Validation

Verification was performed at two levels:

### 1. RTL Simulation

Dedicated testbenches verify:

* Circular buffer correctness
* Delay accuracy (static and dynamic)
* Boundary and saturation handling
* AXI-Stream handshake correctness
* AXI-Lite register access

Simulation results are logged as CSV files and analyzed offline  
(see `/result`).

---

### 2. System-Level Validation

The AXI-integrated design was validated using:

* AXI DMA
* Zynq UltraScale+ Processing System
* AXI-Stream end-to-end simulation

This validates correct behavior under realistic streaming conditions.

Hardware-oriented scripts and bitstreams are **intentionally not included**
to keep the repository focused on RTL design and architecture.

---

## Design Rationale (Summary)

Key design decisions:

* **Integer-sample delay only**
* Explicit **safety clamping** for delay bounds
* BRAM-based circular buffer for predictable timing
* Separate core and AXI wrapper modules
* Minimal control register set

These decisions reflect **engineering trade-offs**, not missing features.

More detailed explanations are available in `/docs/design_rationale.md`.

---

## What This Repository Is

* A **clean RTL reference**
* A demonstration of:
  * delay-line design using FPGA BRAM
  * deterministic pointer arithmetic
  * AXI-Stream and AXI-Lite integration
* A reusable building block for larger FPGA audio pipelines

---

## What This Repository Is Not

* ❌ A feature-rich audio effects processor
* ❌ A chorus or flanger with fractional delay
* ❌ A software-driven demo
* ❌ A drop-in commercial IP

The scope is intentionally constrained.

---

## Project Status

This repository is considered **complete**.

* RTL is stable
* Simulation coverage is sufficient
* AXI integration is verified
* No further feature development is planned

The design is published as a **reference implementation**.

---

## Documentation

Additional documentation is available in `/docs`:

* `address_map.md`
* `build_overview.md`
* `design_rationale.md`
* `latency_and_data_format.md`
* `validation_notes.md`

---

## Related Work

This repository is part of a small RTL-focused DSP building block series.

For a reference implementation of a **Quadrature Mirror Filter (QMF)
analysis/synthesis filter bank** using AXI-Stream and fixed-point arithmetic, see:

🔗 https://github.com/vrm-lab/Quadrature-Mirror-Filter-FPGA

That repository focuses on:
- subband analysis and reconstruction behavior
- fixed-point DSP discipline
- AXI-Stream integration correctness

It is provided as a **reference RTL design**, not as a complete system.

---

## License

Licensed under the MIT License.  
Provided as-is, without warranty.

---

## Notes

> **This repository demonstrates design decisions, not design possibilities.**
