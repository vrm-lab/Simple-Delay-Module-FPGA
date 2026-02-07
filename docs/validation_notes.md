# Validation Notes

This document summarizes validation activities and observed behavior during
simulation.

---

## Validation Methodology

Validation was performed using:
- standalone testbench for `delay_core`
- AXI-based testbench for `delay_axis`
- CSV-based waveform logging and offline analysis

---

## Key Validation Results

- Delay accuracy matches programmed values
- No memory corruption or illegal access observed
- AXI handshaking behaves as expected
- Reset and enable behavior is deterministic

---

## Stress and Boundary Tests

- Negative delay requests are safely clamped
- Delay values exceeding buffer size are limited
- Bypass mode functions correctly without artifacts

---

## Known Behaviors

- Phase artifacts during rapid delay modulation
- Expected due to lack of fractional delay interpolation

These behaviors are documented and considered acceptable within the design
scope.

---

## Validation Status

The design is considered:
- functionally correct
- stable under tested conditions
- suitable as a reference and educational implementation
