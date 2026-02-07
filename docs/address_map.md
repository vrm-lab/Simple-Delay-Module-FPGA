# AXI-Lite Address Map

This document describes the AXI4-Lite register map for the `delay_axis` module.
The registers are used to control and configure the stereo delay behavior from
the Processing System (PS).

---

## Overview

- Interface: AXI4-Lite slave
- Data width: 32 bits
- Address width: 4 bits
- Addressing: word-aligned (32-bit)

All registers are accessible via memory-mapped I/O from the PS.

---

## Register Summary

| Address | Name         | Access | Description                          |
|--------:|--------------|--------|--------------------------------------|
| 0x00    | CTRL         | R/W    | Core control register                |
| 0x04    | DELAY_L      | R/W    | Left channel delay (samples)         |
| 0x08    | DELAY_R      | R/W    | Right channel delay (samples)        |

---

## Register Descriptions

### 0x00 – Control Register (CTRL)

Controls the global operation of the delay core.

| Bit | Name    | Description                                    |
|----:|---------|------------------------------------------------|
| 0   | ENABLE  | 1 = delay core enabled, 0 = core frozen       |
| 31:1 | —      | Reserved (read as written)                    |

**Reset value:** `0x00000001`  
(Core enabled by default)

---

### 0x04 – Left Channel Delay Register (DELAY_L)

Sets the delay length for the left audio channel.

- Unit: samples
- Effective width: lower `DELAY_ADDR_W` bits
- Valid range: `0` to `2^DELAY_ADDR_W - 1`

Higher bits are ignored by the delay core.

**Reset value:** `0x000000C8` (200 samples)

---

### 0x08 – Right Channel Delay Register (DELAY_R)

Sets the delay length for the right audio channel.

- Unit: samples
- Effective width: lower `DELAY_ADDR_W` bits
- Valid range: `0` to `2^DELAY_ADDR_W - 1`

Higher bits are ignored by the delay core.

**Reset value:** `0x00000190` (400 samples)

---

## Access Notes

- All registers support byte-wise write via `WSTRB`
- Reads return the last written value
- No side effects are triggered by read operations

---

## Address Decoding

The internal address decoding uses word-aligned addressing:

- `ADDR[3:2] = 2'b00` → CTRL
- `ADDR[3:2] = 2'b01` → DELAY_L
- `ADDR[3:2] = 2'b10` → DELAY_R

Lower address bits `[1:0]` are ignored.

---

## Design Notes

- Delay values are interpreted as **integer sample delays**
- No fractional delay is implemented
- Delay values exceeding internal buffer size are safely clamped

This register map is intentionally minimal to simplify software control and
verification.
