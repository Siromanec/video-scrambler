from typing import Literal

import numpy as np


# class I2CRegister(dataclass):
#     name: str
#     address_range: tuple[int, int]
#     values: list[int] | None = None
#     mode: Literal["rw", "r"] | None = None
#
#     def format_value(self):
#         if self.values is None:
#             return 0
#         return self.values
#
#     def is_modified(self):
#         return self.values is not None
#
#
# class GenericI2CMemConfig:
#     def __init__(self, i2c_address: int, init_sequence: list[tuple[int, int]], registers: list[I2CRegister],
#                  size: int = 256):
#         """
#
#         :param i2c_address: address of the I2C device
#         :param init_sequence: subaddresses and values to be written to the device
#         """
#         self.i2c_address = i2c_address
#         self.init_sequence = init_sequence
#         self.registers = registers
#         self.size = size
#         self.register_dict = {register.name: register for register in self.registers}
#
#     def registers_to_np_array(self):
#         memory = np.zeros(self.size, dtype=np.uint8)
#         for register in self.registers:
#             memory[register.address_range[0]:register.address_range[1]] = register.format_value()
#         return memory
#
#     def get_modified_registers_bitmask(self):
#         return np.array([register.is_modified() for register in self.registers], dtype=bool)
#
#
# class __InputSelect(Enum):
#     CVBS = 0b000
#     SVIDEO = 0b001
#     YPbPr = 0b010
#     RGB = 0b011
#     YC = 0b100
#     AUTO = 0b101
#     D = 0b110
#     RESERVED = 0b111
#     DEFAULT = -1
#
# def from_intel_hex_int(string):
#     """
#     XXh -> 0xXX
#     """
#     return int("0x"+string[:-1], 16)
# def raw_address_to_address_range(address):
#     """
#     XXh -> (0xXX, 0xXX + 1)
#     XXh-YYh -> (0xXX, 0xYY + 1)
#     """
#     if "-" not in address:
#         address = from_intel_hex_int(address)
#         address_range = (address, address + 1)
#     else:
#         address_range = address.split("-")
#         address_range = from_intel_hex_int(address_range[0]), from_intel_hex_int(address_range[1]) + 1
#     return address_range
#
# def read_register_config(register_config_file_name: str) -> list[I2CRegister]:
#
#     with open(register_config_file_name, 'r') as file:
#         lines = file.readlines()
#     reserved_counter = 0
#     registers = []
#     for line in lines:
#
#         line = line.strip().split()
#         if line[0].lower() != "reserved":
#             *name, address, default, mode = line
#             if address[-1] != "h":
#                 name.append(address)
#                 address = default
#             mode = mode.lower()
#             if mode == "r/w":
#                 mode = "rw"
#         else:
#
#             name, address = line
#             mode = None
#             name = (name, str(reserved_counter))
#             reserved_counter += 1
#         name = "_".join(name).lower()
#         address_range = raw_address_to_address_range(address)
#         registers.append(I2CRegister(name, address_range, None, mode))
#     return registers
# class TVP5147M1MemConfig(GenericI2CMemConfig):
#     """
#     Do not write to reserved registers. Reserved bits in any defined register must be written with
#     0s, unless otherwise noted.
#     """
#     register_config_file_name = "TVP5147M1_i2c_registers.txt"
#
#     def __init__(self):
#         init_sequence = [
#             (0x03, 0x01),
#             (0x03, 0x00),
#         ]
#         registers = read_register_config(self.register_config_file_name)
#         super().__init__(0b10111000, init_sequence, registers)


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
        return np.concatenate([np.zeros(self.PERIPHERAL_OFFSET, np.uint8), self.adv7393.init_to_array(), self.tvp5147m1.init_to_array()])
def main():
    adv7393 = ADV7393MemConfig()
    tvp5147m1 = TVP5147M1MemConfig()
    fpga_config = FPGAConfig(adv7393, tvp5147m1)
    memory = fpga_config.to_array()

    import mif


    print(f"Mapped memory size: {len(memory)}")
    print(*memory)
    bit_mem = np.unpackbits(memory, bitorder="little").reshape(-1, 8)
    print(bit_mem)

    with open("config.mif", 'w') as fp:
        mif.dump(bit_mem, fp)

if __name__ == "__main__":
    main()