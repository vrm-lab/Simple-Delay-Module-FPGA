# Design Rationale

This document explains the architectural and design decisions behind the AXI
stereo delay implementation.

---

## Motivation

The primary goal of this design is to implement a **deterministic and stable**
audio delay engine suitable for FPGA-based systems and academic research.

The design intentionally avoids:
- overly complex DSP techniques
- high-fidelity audio effects requiring fractional delay
- tightly coupled, monolithic architectures

---

## Core Design Choices

### 1. Integer-Sample Delay
- Delay is implemented using integer sample offsets only
- Simplifies control logic and verification
- Ensures predictable timing behavior

### 2. BRAM-Based Circular Buffer
- Efficient use of FPGA memory resources
- Natural wrap-around behavior
- Constant-time read/write access

### 3. Separation of Concerns
- `delay_core`: pure signal processing logic
- `delay_axis`: AXI integration and system-level control

This separation improves reusability and testability.

---

## AXI Integration Rationale

- AXI4-Stream is used for continuous audio data flow
- AXI4-Lite is used for low-bandwidth control and configuration
- AXI DMA enables efficient data transfer between PS memory and PL logic

This architecture mirrors common industry and research FPGA workflows.

---

## Accepted Limitations

- No fractional delay interpolation
- Audible artifacts may occur under fast delay modulation
- Not intended for production-grade audio effects

These limitations are acknowledged design trade-offs rather than defects.
