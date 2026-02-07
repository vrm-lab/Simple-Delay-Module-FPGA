# Latency and Data Format

This document specifies data formatting and latency characteristics of the
delay system.

---

## Audio Data Format

- Sample width: 16-bit signed
- Stereo packing:
  - Bits [15:0]  : Left channel
  - Bits [31:16] : Right channel
- Endianness: little-endian within AXI word

---

## Delay Granularity

- Delay resolution: 1 sample
- Maximum delay: determined by BRAM address width
- Delay is applied independently per channel

---

## Latency Analysis

### delay_core
- BRAM read latency: 1 clock cycle
- Write and read occur synchronously
- Output latency is deterministic

### delay_axis
- One additional cycle for control signal alignment
- `tvalid` and `tlast` are delayed to match data latency

---

## End-to-End Latency

Total latency includes:
- AXI DMA buffering
- delay_core internal latency
- AXI stream pipeline alignment

Exact end-to-end latency depends on DMA configuration and is therefore not
fixed, but internal module latency is constant and well-defined.
