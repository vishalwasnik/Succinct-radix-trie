# Succinct Radix Trie on MG82F6D17 (8051 Microcontroller)

This repository contains an embedded implementation of a **Succinct Radix Trie** written for the **MG82F6D17** (8051-core) microcontroller. The system leverages optimized Assembly language (`TRIE_ASM_MODULE`) for high-speed bit-level traversal and a C-based system controller (`MAIN.C`) handling UART, SPI, DMA, and Flash memory IAP.

---

## Features

* **Succinct Radix Trie Traversal (Assembly):** Highly optimized 8051 assembly code for processing incoming bytes against a compressed trie data structure stored in Flash ROM.
* **DMA-Driven SPI Communication:** Utilizes the MG82F6D17's internal DMA channels for efficient background data transfers over SPI.
* **Flash IAP (In-Application Programming):** Direct sector erasure and safe page writing to manage dynamic trie dictionaries/configurations.
* **Bit-to-Byte Conversion & Queueing:** Robust command processing via UART, converting incoming ASCII bit-strings (`0` and `1`) into packed raw byte arrays stored in `XDATA`.

---

## Project Structure

* **`TRIE_ASM_MODULE.A51`**: The core assembly module responsible for RAM table initialization (`INIT_RAM_TABLE`), bit manipulation/counting, and trie matching logic (`_Process_Incoming_Byte_Trie`).
* **`MAIN.C` (System Core):** Handles clock configuration, UART setup, SPI DMA configurations, and interactive serial commands (`S`, `D`).
* **`MAIN_SPI_TX.C`:** Secondary communication handler that converts binary inputs into raw byte queues and drives Master SPI transmissions.

---

## System Configuration & Memory Layout

* **Microcontroller:** MG82F6D17 (8051 Architecture)
* **Clock Source:** Internal High-Speed RC Oscillator (IHRCO 12MHz, SYSCLK Div-1)
* **Dictionary Address:** Flash memory starting at `0x3800`
* **RAM Layout:** Uses `IDATA` for fast buffer operations and `XDATA` for data queues.

---

## How It Works

1. **Initialization:** 
   * `InitSystem()` configures the clock, ports, UART (9600 baud, 2X mode), and SPI interfaces.
   * `INIT_RAM_TABLE()` sets up the structural bit masks inside internal RAM (`40H`-`47H`) from ROM data.
2. **Trie Matching (`_Process_Incoming_Byte_Trie`):**
   * Incoming bytes are processed bit-by-bit using high-speed register rotations and mask checks against Flash-stored configuration bytes.
   * Returns `1` on a successful node match and increments match counters; resets to the root node (`0x3800`) on failure.
3. **Serial Terminal Interaction:**
   * Send **`S`** or **`s`** to check current DMA buffer states and pending bytes.
   * Send **`D`** or **`d`** to dump the stored hexadecimal dictionary slots.

---

## Build and Flashing

1. Open your project workspace in your 8051-compatible IDE (e.g., Keil µVision).
2. Ensure both the assembly file (`TRIE_ASM_MODULE.A51`) and C files are added to the project target group.
3. Compile/Build the project to generate the target Hex file.
4. Flash the binary onto the **MG82F6D17** MCU using your standard ISP programmer.
