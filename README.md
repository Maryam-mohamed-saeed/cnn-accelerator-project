

## Team Members
- Malak Waleed
- Maha Yasser
- Menna Moutaz
- Mariam Ahmed
- Mariam Mohamed
- Serag Khaled


# CNN Accelerator — Eyeriss-v2–Based FPGA Implementation

**Team:** SMC26-30  
**Target Model:** LEGNet (Lightweight Edge-Guided Network) for satellite image classification  
**Architecture Inspiration:** Eyeriss v2 (Hierarchical Mesh NoC + CSC Encoding)

## Table of Contents

1. [Project Overview](#project-overview)
2. [Architecture](#architecture)
3. [Repository Structure](#repository-structure)
4. [Module Descriptions](#module-descriptions)
5. [Parameters & Precision](#parameters--precision)
6. [Dataflow Summary](#dataflow-summary)
7. [Getting Started](#getting-started)

---

## Project Overview

This project implements a spatial CNN hardware accelerator on FPGA, optimized for satellite image analysis using the LEGNet backbone. The design follows the Eyeriss v2 architecture, featuring a hierarchical mesh Network-on-Chip (NoC) and Compressed Sparse Column (CSC) encoding to maximize on-chip data reuse and minimize costly off-chip DRAM accesses.

Key design goals:
- **8-bit fixed-point (INT8)** MAC computation per PE
- **On-chip memory hierarchy**: PE-level scratchpads → GLB cluster SRAM → off-chip DRAM
- **Three-data-type routing**: separate routers for input activations (iact), weights, and partial sums (psum)
- **Flexible dataflow**: unicast, multicast, horizontal-cast, vertical-cast, and broadcast modes

---

## Architecture

The accelerator is organized into three main clusters, each instantiated per convolution group:

```
┌─────────────────────────────────────────────┐
│              Cluster Group                  │
│                                             │
│  ┌─────────────┐   ┌──────────────────────┐ │
│  │ GLB Cluster │◄──► Router Cluster        │ │
│  │ (SRAM)      │   │ (iact / weight /psum) │ │
│  └──────┬──────┘   └──────────┬───────────┘ │
│         │                     │             │
│         └──────────┬──────────┘             │
│                    ▼                        │
│           ┌────────────────┐                │
│           │   PE Cluster   │                │
│           │  (9×4 = 36 PEs)│                │
│           └────────────────┘                │
└─────────────────────────────────────────────┘
```

Each **PE Core** contains:
- MAC datapath (INT8 multiply → 20-bit accumulate)
- iact scratchpad (SPad)
- weight scratchpad (SPad)
- psum scratchpad (SPad)

---

## Repository Structure

```
cnn-accelerator/
├── docs/                        # Project documentation & thesis materials
├── rtl/
│   ├── pe_core.v                # Processing Element core (MAC + SPads)
│   ├── pe_cluster.v             # 9×4 PE array with cluster controller
│   ├── iact_spad.v              # Input activation scratchpad
│   ├── Weight_Spad.v            # Weight scratchpad
│   ├── psum_spad.v              # Partial sum scratchpad
│   ├── iact_router.v            # Input activation router
│   ├── weight_router.v          # Weight router
│   ├── psum_router.v            # Partial sum router
│   ├── Router_Cluster_TOP.v     # Top-level router cluster (all 3 routers)
│   ├── GLB_cluster.v            # Global Buffer cluster (iact/weight/psum SRAMs)
│   ├── iact_SRAM_3_read.v       # iact SRAM with 3 read ports
│   ├── weight_SRAM.v            # Weight SRAM with 3 read ports
│   ├── psum_SRAM.v              # Partial sum SRAM bank
│   └── cluster_group_controller.v  # Top-level dataflow controller
├── tb/                          # Testbenches
├── scripts/                     # Synthesis / simulation scripts
└── README.md
```

---

## Module Descriptions

### PE Level

| Module | File | Description |
|--------|------|-------------|
| `PE_core` | `pe_core.v` | Single PE: loads weights & iacts into SPads, runs MAC operations, streams psums out. FSM: IDLE → LOAD_WEIGHTS → LOAD_IACT → MAC → PSUM_STREAM |
| `iact_spad` | `iact_spad.v` | 16-deep register file for input activations. Sequential write, combinatorial read via cycle counter |
| `weight_spad` | `Weight_Spad.v` | 9-deep register file for weights (one per PE row). Supports configurable filter sizes |
| `psum_spad` | `psum_spad.v` | 16-deep register file for partial sums. Supports accumulation and sequential streaming |

### Cluster Level

| Module | File | Description |
|--------|------|-------------|
| `PE_cluster` | `pe_cluster.v` | Instantiates 36 PE cores (9 rows × 4 cols). Cluster controller manages weight/iact loading, MAC start, and psum streaming across all PEs |
| `Iact_Router` | `iact_router.v` | Routes iact data from GLB or neighboring clusters to PEs. Supports unicast, multicast (6 modes), horizontal-cast, vertical-cast, and broadcast |
| `weight_router` | `weight_router.v` | Circuit-switching MUX router for weight distribution across a PE row (GLB → PE, or horizontal pass-through) |
| `Psum_Router` | `psum_router.v` | Accumulates and routes psums along PE columns, between clusters (north/south), and back to GLB |
| `Router_Cluster` | `Router_Cluster_TOP.v` | Top-level wrapper instantiating all iact, weight, and psum routers for one cluster |
| `GLB_CLUSTER` | `GLB_cluster.v` | Global Buffer: iact SRAM (256-deep, 8-bit), weight SRAM (256-deep, 8-bit), psum SRAM (32-deep, 20-bit) |

### Memory

| Module | File | Description |
|--------|------|-------------|
| `iact_SRAM_3_read` | `iact_SRAM_3_read.v` | iact SRAM with 1 write port and 3 independent read ports (one per iact router). 3-cycle read latency |
| `weight_SRAM` | `weight_SRAM.v` | Weight SRAM with 1 write port and 3 independent read ports. Same 3-cycle latency protocol |
| `psum_SRAM_Bank` | `psum_SRAM.v` | Single-port psum SRAM. Stores intermediate and final output feature maps |

### Control

| Module | File | Description |
|--------|------|-------------|
| `cluster_group_controller` | `cluster_group_controller.v` | Top-level dataflow sequencer. Manages iact start addresses, filter-size-dependent tiling, and cluster-group orchestration |

---

## Parameters & Precision

| Parameter | Value | Notes |
|-----------|-------|-------|
| `IACT_SIZE` | 8 bits | INT8 input activations |
| `WEIGHT_SIZE` | 8 bits | INT8 weights |
| `PSUM_SIZE` | 20 bits | Accumulator width (prevents overflow across MAC chain) |
| `PE_NUM` | 36 | 9 rows × 4 columns per cluster |
| `IACT_SPAD_DEPTH` | 16 | Max unique iact values per cluster per cycle |
| `WEIGHT_SPAD_DEPTH` | 9 | One weight per PE row (max filter size = 9) |
| `PSUM_SPAD_DEPTH` | 16 | Max partial sums per cluster per cycle |
| `IACT_SRAM_DEPTH` | 256 | Supports up to 192 iacts for largest conv (filter=9) |
| `WEIGHT_SRAM_DEPTH` | 256 | Weight GLB depth per cluster |
| `PSUM_SRAM_DEPTH` | 32 | Output feature map buffer depth |

---

## Dataflow Summary

The accelerator implements an **input-stationary / weight-stationary hybrid** dataflow inspired by Eyeriss v2:

1. **Weights** are loaded from the GLB weight SRAM → weight routers → weight SPads (held stationary during a convolution pass)
2. **Input activations** are streamed from the GLB iact SRAM → iact routers → iact SPads, with multicast reuse across PE rows
3. **MACs** are performed inside each PE (iact × weight → accumulated into psum SPad)
4. **Partial sums** are streamed out via psum routers, accumulated along PE columns, and written back to the GLB psum SRAM

All three data paths use a **valid/ready handshake** protocol for backpressure control.

---

## Getting Started

### Simulation

```bash
# Example using ModelSim / QuestaSim
vlog rtl/pe_core.v rtl/iact_spad.v rtl/Weight_Spad.v rtl/psum_spad.v
vlog rtl/iact_router.v rtl/weight_router.v rtl/psum_router.v
vlog rtl/Router_Cluster_TOP.v
vlog rtl/iact_SRAM_3_read.v rtl/weight_SRAM.v rtl/psum_SRAM.v
vlog rtl/GLB_cluster.v rtl/pe_cluster.v rtl/cluster_group_controller.v
vlog tb/<your_testbench>.v
vsim tb_top
```


## References

- Eyeriss v2: *"Eyeriss v2: A Flexible Accelerator for Emerging Deep Neural Networks on Mobile Devices"* — Chen et al., IEEE JETCAS 2019
- LEGNet: Lightweight Edge-Guided Network for remote sensing image classification
- Target Dataset: DOTA (Detection in Optical Remote Sensing Images)