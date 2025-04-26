from typing import Literal

import numpy as np
import mif


class GenericI2CMemConfig:
    init_sequence: np.ndarray[np.uint8]
    i2c_address: np.uint8

    def __init__(self, i2c_address: int, init_sequence: list[tuple[int, int]]):
        assert 0 <= i2c_address <= 0xFF, "Invalid I2C address"
        assert all(0 <= subaddress <= 0xFF and 0 <= value <= 0xFF for subaddress, value in
                   init_sequence), "Invalid subaddress or value"
        self.i2c_address = np.uint8(i2c_address)

        self.init_sequence = np.array(init_sequence, dtype=np.uint8).flatten()

    def init_to_array(self):
        memory = np.zeros(2 + len(self.init_sequence), dtype=np.uint8)
        memory[0] = self.i2c_address
        memory[1] = len(self.init_sequence.flatten())
        memory[2:] = self.init_sequence
        return memory


class ADV7393MemConfig(GenericI2CMemConfig):
    """
    Table 71. 10-Bit 525i YCrCb In, CVBS/Y-C Out
        Subaddress Setting Description
        0x17 0x02 Software reset.
        0x00 0x1C All DACs enabled. PLL enabled (16×).
        0x01 0x00 SD input mode.
        0x80 0x10 NTSC standard. SSAF luma filter
        enabled. 1.3 MHz chroma filter enabled.
        0x82 0xCB Pixel data valid. CVBS/Y-C (S-Video) out.
        SSAF PrPb filter enabled. Active video
        edge control enabled. Pedestal enabled.
        0x88 0x10 10-bit input enabled.
        0x8A 0x0C Timing Mode 2 (slave). HSYNC/VSYNC
        synchronization.

    Table 88. 10-Bit 625i YCrCb In, CVBS/Y-C Out
        Subaddress Setting Description
        0x17 0x02 Software reset.
        0x00 0x1C All DACs enabled. PLL enabled (16×).
        0x01 0x00 SD input mode.
        0x80 0x11 PAL standard. SSAF luma filter enabled.
        1.3 MHz chroma filter enabled.
        0x82 0xC3 Pixel Data Valid. CVBS/Y-C (S-Video)
        Out. SSAF PrPb filter enabled. Active
        video edge control enabled.
        0x88 0x10 10-bit input enabled.
        0x8A 0x0C Timing Mode 2 (slave). HSYNC/VSYNC
        synchronization.
        0x8C 0xCB Subcarrier frequency register values
        for CVBS and/or S-Video (Y-C) output
        in PAL mode (27 MHz input clock).
        0x8D 0x8A
        0x8E 0x09
        0x8F 0x2A
    """

    def __init__(self, mode: Literal["NTSC", "PAL"] = "NTSC"):
        match mode:
            case "NTSC":
                init_sequence = [
                    (0x17, 0x02),  # Software reset.
                    (0x00, 1 << 4),  # DAC 1 enabled (CVBS). PLL enabled (16×).
                    (0x01, 0x00),  # SD input mode.
                    (0x80, 0x10),  # NTSC standard. SSAF luma filter enabled. 1.3 MHz chroma filter enabled.
                    (0x82, 0xCB),
                    # SSAF PrPb filter enabled.  CVBS/Y-C (S-Video) Out. Pixel Data Valid.  Active video edge control enabled.
                    (0x88, 0x10),  # 10-bit input enabled.
                    (0x8A, 0x0C),  # Timing Mode 2 (slave). HSYNC/VSYNC synchronization.
                ]
            case "PAL":
                init_sequence = [
                    (0x17, 0x02),  # Software reset.
                    (0x00, 1 << 4),  # DAC 1 enabled (CVBS). PLL enabled (16×).
                    (0x01, 0x00),  # SD input mode.
                    (0x80, 0x11),  # PAL standard. SSAF luma filter enabled. 1.3 MHz chroma filter enabled.
                    (0x82, 0xC3),
                    # SSAF PrPb filter enabled.  CVBS/Y-C (S-Video) Out. Pixel Data Valid.  Active video edge control enabled.
                    (0x88, 0x10),  # 10-bit input enabled.
                    (0x8A, 0x0C),  # Timing Mode 2 (slave). HSYNC/VSYNC synchronization.
                    (0x8C, 0xCB),
                    # Subcarrier frequency register values for CVBS and/or S-Video (Y-C) output in PAL mode (27 MHz input clock).
                    (0x8D, 0x8A),
                    (0x8E, 0x09),
                    (0x8F, 0x2A),
                ]
            case _:
                raise ValueError("Invalid mode")

        super().__init__(0x54, init_sequence)  # ALSB = 0, ADDR = 0x54; ALSB = 1, ADDR = 0x56


class TVP5147M1MemConfig(GenericI2CMemConfig):
    """
    4.1 Example 1
        4.1.1 Assumptions
            Input connector: Composite (VI_1_A) (default)
            Video format: NTSC (J, M), PAL (B, G, H, I, N) or SECAM (default)
            Note: NTSC-443, PAL-Nc, PAL-M, and PAL-60 are masked from the autoswitch process by default. See
            the autoswitch mask register at address 04h.
            Output format: 10-bit ITU-R BT.656 with embedded syncs (default)
        4.1.2 Recommended Settings
            Recommended I2C writes: For the given assumptions, only one write is required. All other registers are set
            up by default.
            I2C register address 08h = Luminance processing control 3 register
            I2C data 00h = Optimizes the trap filter selection for NTSC and PAL
            I2C register address 0Eh = Chrominance processing control 2 register
            I2C data 04h = Optimizes the chrominance filter selection for NTSC and PAL
            I2C register address 34h = Output formatter 2 register
            I2C data 11h = Enables YCbCr output and the clock output
            Note: HS/CS, VS/VBLK, AVID, FID, and GLCO are logic inputs by default. See output formatter 3 and 4
            registers at addresses 35h and 36h, respectively.
    """

    def __init__(self):
        init_sequence = [
            (0x03, 0x01),  # manufacturer init sequence: power save mode (On)
            (0x03, 0x00),  # manufacturer init sequence: power save mode (Off)
            (0x08, 0x00),
            # Luminance processing control 3 register: Optimizes the trap filter selection for NTSC and PAL
            (0x0E, 0x04),
            # Chrominance processing control 2 register: Optimizes the chrominance filter selection for NTSC and PAL
            (0x34, 0x11),  # Output formatter 2 register: Enables YCbCr output and the clock output
        ]
        super().__init__(0xB8, init_sequence)  # I2CA = 0, ADDR = 0xB8; I2CA = 1, ADDR = 0xBA


class FPGAConfig:
    PERIPHERAL_OFFSET = 0x10

    def __init__(self, adv7393: ADV7393MemConfig, tvp5147m1: TVP5147M1MemConfig):
        self.adv7393 = adv7393
        self.tvp5147m1 = tvp5147m1

    def to_array(self):
        return np.concatenate(
            [np.zeros(self.PERIPHERAL_OFFSET, np.uint8), self.adv7393.init_to_array(), self.tvp5147m1.init_to_array()])


def main():
    adv7393 = ADV7393MemConfig()
    tvp5147m1 = TVP5147M1MemConfig()
    fpga_config = FPGAConfig(adv7393, tvp5147m1)
    memory = fpga_config.to_array()


    print(f"Mapped memory size: {len(memory)} bytes")
    bit_mem = np.unpackbits(memory, bitorder="little").reshape(-1, 8)
    with open("config.mif", 'w') as fp:
        mif.dump(bit_mem, fp)
    print("Memory dumped to 'scrambler.mif'")


if __name__ == "__main__":
    main()
