----------------------------------------------------------------------------------
-- MiSTer2MEGA65 Framework
--
-- Global constants
--
-- MiSTer2MEGA65 done by sy2002 and MJoergen in 2022 and licensed under GPL v3
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.NUMERIC_STD_UNSIGNED.ALL;

library work;
use work.qnice_tools.all;
use work.video_modes_pkg.all;

package globals is

----------------------------------------------------------------------------------------------------------
-- QNICE Firmware
----------------------------------------------------------------------------------------------------------

-- QNICE Firmware: Use the regular QNICE "operating system" called "Monitor" while developing and
-- debugging the firmware/ROM itself. If you are using the M2M ROM (the "Shell") as provided by the
-- framework, then always use the release version of the M2M firmware: QNICE_FIRMWARE_M2M
--
-- Hint: You need to run QNICE/tools/make-toolchain.sh to obtain "monitor.rom" and
-- you need to run CORE/m2m-rom/make_rom.sh to obtain the .rom file
constant QNICE_FIRMWARE_MONITOR   : string  := "../../../M2M/QNICE/monitor/monitor.rom";    -- debug/development
constant QNICE_FIRMWARE_M2M       : string  := "../../../CORE/m2m-rom/m2m-rom.rom";         -- release

-- Select firmware here
constant QNICE_FIRMWARE           : string  := QNICE_FIRMWARE_M2M;

----------------------------------------------------------------------------------------------------------
-- Clock Speed(s)
--
-- Important: Make sure that you use very exact numbers - down to the actual Hertz - because some cores
-- rely on these exact numbers. By default M2M supports one core clock speed. In case you need more,
-- then add all the clocks speeds here by adding more constants.
----------------------------------------------------------------------------------------------------------

-- Galaga core's clock speed
-- Actual clock is 18_432 Mhz ( see MAME driver - galaga.cpp ).
-- MiSTer uses 18Mhz
constant CORE_CLK_SPEED       : natural := 36_000_000;   -- Bank Panic's main clock is 36 MHz 

-- System clock speed (crystal that is driving the FPGA) and QNICE clock speed
-- !!! Do not touch !!!
constant BOARD_CLK_SPEED      : natural := 100_000_000;
constant QNICE_CLK_SPEED      : natural := 50_000_000;   -- a change here has dependencies in qnice_globals.vhd

----------------------------------------------------------------------------------------------------------
-- Video Mode
----------------------------------------------------------------------------------------------------------

-- Rendering constants (in pixels)
--    VGA_*   size of the core's target output post scandoubler
--    FONT_*  size of one OSM character
constant VGA_DX               : natural := 448;
constant VGA_DY               : natural := 448;
constant FONT_FILE            : string  := "../font/Anikki-16x16-m2m.rom";
constant FONT_DX              : natural := 16;
constant FONT_DY              : natural := 16;

-- Constants for the OSM screen memory
constant CHARS_DX             : natural := VGA_DX / FONT_DX;
constant CHARS_DY             : natural := VGA_DY / FONT_DY;
constant CHAR_MEM_SIZE        : natural := CHARS_DX * CHARS_DY;
constant VRAM_ADDR_WIDTH      : natural := f_log2(CHAR_MEM_SIZE);

----------------------------------------------------------------------------------------------------------
-- HyperRAM memory map (in units of 4kW)
----------------------------------------------------------------------------------------------------------

constant C_HMAP_M2M           : std_logic_vector(15 downto 0) := x"0000";     -- Reserved for the M2M framework
constant C_HMAP_DEMO          : std_logic_vector(15 downto 0) := x"0200";     -- Start address reserved for core

----------------------------------------------------------------------------------------------------------
-- Virtual Drive Management System
----------------------------------------------------------------------------------------------------------

-- Virtual drive management system (handled by vdrives.vhd and the firmware)
-- If you are not using virtual drives, make sure that:
--    C_VDNUM        is 0
--    C_VD_DEVICE    is x"EEEE"
--    C_VD_BUFFER    is (x"EEEE", x"EEEE")
-- Otherwise make sure that you wire C_VD_DEVICE in the qnice_ramrom_devices process and that you
-- have as many appropriately sized RAM buffers for disk images as you have drives
type vd_buf_array is array(natural range <>) of std_logic_vector;
constant C_VDNUM              : natural := 0;
constant C_VD_DEVICE          : std_logic_vector(15 downto 0) := x"EEEE";
constant C_VD_BUFFER          : vd_buf_array := (x"EEEE", x"EEEE");

----------------------------------------------------------------------------------------------------------
-- System for handling simulated cartridges and ROM loaders
----------------------------------------------------------------------------------------------------------

type crtrom_buf_array is array(natural range<>) of std_logic_vector;
constant ENDSTR : character := character'val(0);

-- Cartridges and ROMs can be stored into QNICE devices, HyperRAM and SDRAM
constant C_CRTROMTYPE_DEVICE     : std_logic_vector(15 downto 0) := x"0000";
constant C_CRTROMTYPE_HYPERRAM   : std_logic_vector(15 downto 0) := x"0001";
constant C_CRTROMTYPE_SDRAM      : std_logic_vector(15 downto 0) := x"0002";           -- @TODO/RESERVED for future R4 boards

-- Types of automatically loaded ROMs:
-- If a mandatory file is missing, then the core outputs the missing file and goes fatal
constant C_CRTROMTYPE_MANDATORY  : std_logic_vector(15 downto 0) := x"0003";
constant C_CRTROMTYPE_OPTIONAL   : std_logic_vector(15 downto 0) := x"0004";


-- Manually loadable ROMs and cartridges as defined in config.vhd
-- If you are not using this, then make sure that:
--    C_CRTROM_MAN_NUM    is 0
--    C_CRTROMS_MAN       is (x"EEEE", x"EEEE", x"EEEE")
-- Each entry of the array consists of two constants:
--    1) Type of CRT or ROM: Load to a QNICE device, load into HyperRAM, load into SDRAM
--    2) If (1) = QNICE device, then this is the device ID
--       else it is a 4k window in HyperRAM or in SDRAM
-- In case we are loading to a QNICE device, then the control and status register is located at the 4k window 0xFFFF.
-- @TODO: See @TODO for more details about the control and status register
constant C_CRTROMS_MAN_NUM       : natural := 0;                                       -- amount of manually loadable ROMs and carts, if more than 3: also adjust CRTROM_MAN_MAX in M2M/rom/shell_vars.asm, Needs to be in sync with config.vhd. Maximum is 16
constant C_CRTROMS_MAN           : crtrom_buf_array := ( x"EEEE", x"EEEE",
                                                         x"EEEE");                     -- Always finish the array using x"EEEE"

-- Automatically loaded ROMs: These ROMs are loaded before the core starts
--
-- Works similar to manually loadable ROMs and cartridges and each line item has two additional parameters:
--    1) and 2) see above
--    3) Mandatory or optional ROM
--    4) Start address of ROM file name within C_CRTROM_AUTO_NAMES
-- If you are not using this, then make sure that:
--    C_CRTROMS_AUTO_NUM  is 0
--    C_CRTROMS_AUTO      is (x"EEEE", x"EEEE", x"EEEE", x"EEEE", x"EEEE")
-- How to pass the filenames of the ROMs to the framework:
-- C_CRTROMS_AUTO_NAMES is a concatenation of all filenames (see config.vhd's WHS_DATA for an example of how to concatenate)
--    The start addresses of the filename can be determined similarly to how it is done in config.vhd's HELP_x_START
--    using a concatenated addition and VHDL's string length operator.
--    IMPORTANT: a) The framework is not doing any consistency or error check when it comes to C_CRTROMS_AUTO_NAMES, so you
--                  need to be extra careful that the string itself plus the start position of the namex are correct.
--               b) Don't forget to zero-terminate each of your substrings of C_CRTROMS_AUTO_NAMES by adding "& ENDSTR;"
--               c) Don't forget to finish the C_CRTROMS_AUTO array with x"EEEE"


constant C_DEV_BP_CPU_ROM1           : std_logic_vector(15 downto 0) := x"0100";     -- CPU1 ROM 
constant C_DEV_BP_CPU_ROM2           : std_logic_vector(15 downto 0) := x"0101";     -- CPU2 ROM 
constant C_DEV_BP_CPU_ROM3           : std_logic_vector(15 downto 0) := x"0102";     -- CPU3 ROM 
constant C_DEV_BP_CPU_ROM4           : std_logic_vector(15 downto 0) := x"0103";     -- CPU4 ROM
constant C_DEV_BP_FG1_GFX1           : std_logic_vector(15 downto 0) := x"0104";     -- FG GFX 1
constant C_DEV_BP_FG2_GFX1           : std_logic_vector(15 downto 0) := x"0105";     -- FG GFX 2
constant C_DEV_BP_BG1_GFX2           : std_logic_vector(15 downto 0) := x"0106";     -- BG GFX 1
constant C_DEV_BP_BG2_GFX2           : std_logic_vector(15 downto 0) := x"0107";     -- BG GFX 2
constant C_DEV_BP_BG3_GFX2           : std_logic_vector(15 downto 0) := x"0108";     -- BG GFX 3
constant C_DEV_BP_BG4_GFX2           : std_logic_vector(15 downto 0) := x"0109";     -- BG GFX 4
constant C_DEV_BP_BG5_GFX2           : std_logic_vector(15 downto 0) := x"010A";     -- BG GFX 5
constant C_DEV_BP_BG6_GFX2           : std_logic_vector(15 downto 0) := x"010B";     -- BG GFX 6
constant C_DEV_BP_PALETTE            : std_logic_vector(15 downto 0) := x"010C";     -- PALETTE
constant C_DEV_BP_FGLUT              : std_logic_vector(15 downto 0) := x"010D";     -- FG LUT
constant C_DEV_BP_BGLUT              : std_logic_vector(15 downto 0) := x"010E";     -- BG LUT

constant ROM1_MAIN_CPU_ROM            : string  := "arcade/bankp/epr-6175.7e" & ENDSTR; -- z80 cpu rom 1
constant ROM2_MAIN_CPU_ROM            : string  := "arcade/bankp/epr-6174.7f" & ENDSTR; -- z80 cpu rom 2
constant ROM3_MAIN_CPU_ROM            : string  := "arcade/bankp/epr-6173.7h" & ENDSTR; -- z80 cpu rom 3
--constant ROM4_MAIN_CPU_ROM            : string  := "arcade/bankp/epr-6176.7d_" & ENDSTR; -- z80 cpu rom 4 -- 16kb with 8kb padded.
constant ROM4_MAIN_CPU_ROM            : string  := "arcade/bankp/epr-6176.7d" & ENDSTR; -- z80 cpu rom 4  - non padded 8kb binary
constant GFX1_FG1_ROM                 : string  := "arcade/bankp/epr-6165.5l" & ENDSTR; -- Foreground tiles 1
constant GFX1_FG2_ROM                 : string  := "arcade/bankp/epr-6166.5k" & ENDSTR; -- Foreground tiles 2
constant GFX2_BG1_ROM                 : string  := "arcade/bankp/epr-6172.5b" & ENDSTR; -- Background tiles 1
constant GFX2_BG2_ROM                 : string  := "arcade/bankp/epr-6171.5d" & ENDSTR; -- Background tiles 2
constant GFX2_BG3_ROM                 : string  := "arcade/bankp/epr-6170.5e" & ENDSTR; -- Background tiles 3
constant GFX2_BG4_ROM                 : string  := "arcade/bankp/epr-6169.5f" & ENDSTR; -- Background tiles 4
constant GFX2_BG5_ROM                 : string  := "arcade/bankp/epr-6168.5h" & ENDSTR; -- Background tiles 5
constant GFX2_BG6_ROM                 : string  := "arcade/bankp/epr-6167.5i" & ENDSTR; -- Background tiles 6
constant PALETTE_ROM                  : string  := "arcade/bankp/palettep"    & ENDSTR; -- Palette rom -- padded from 0x1f-0xff
constant FGLUT_ROM                    : string  := "arcade/bankp/pr-6178.6f"  & ENDSTR; -- Fgtile lookup table
constant BGLUT_ROM                    : string  := "arcade/bankp/pr-6179.5a"  & ENDSTR; -- Bgtile lookup table


constant CPU_ROM1_MAIN_START          : std_logic_vector(15 downto 0) := X"0000";                                           -- 0X0000 - 0X3FFF
constant CPU_ROM2_MAIN_START          : std_logic_vector(15 downto 0) := CPU_ROM1_MAIN_START + ROM1_MAIN_CPU_ROM'length;    -- 0X4000 - 0X7FFF
constant CPU_ROM3_MAIN_START          : std_logic_vector(15 downto 0) := CPU_ROM2_MAIN_START + ROM2_MAIN_CPU_ROM'length;    -- 0X8000 - 0XBFFF
constant CPU_ROM4_MAIN_START          : std_logic_vector(15 downto 0) := CPU_ROM3_MAIN_START + ROM3_MAIN_CPU_ROM'length;    -- 0XC000 - 0XDFFF
constant GFX1_MAIN1_START             : std_logic_vector(15 downto 0) := CPU_ROM4_MAIN_START + ROM4_MAIN_CPU_ROM'length;    --0X10000 - 0X11FFF
constant GFX1_MAIN2_START             : std_logic_vector(15 downto 0) := GFX1_MAIN1_START    + GFX1_FG1_ROM'length;         --0X12000 - 0X13FFF
constant GFX2_MAIN1_START             : std_logic_vector(15 downto 0) := GFX1_MAIN2_START    + GFX1_FG2_ROM'length;         --0X14000 - 0X15FFF
constant GFX2_MAIN2_START             : std_logic_vector(15 downto 0) := GFX2_MAIN1_START    + GFX2_BG1_ROM'length;         --0X16000 - 0X17FFF
constant GFX2_MAIN3_START             : std_logic_vector(15 downto 0) := GFX2_MAIN2_START    + GFX2_BG2_ROM'length;         --0X18000 - 0X19FFF
constant GFX2_MAIN4_START             : std_logic_vector(15 downto 0) := GFX2_MAIN3_START    + GFX2_BG3_ROM'length;         --0X1A000 - 0X1BFFF
constant GFX2_MAIN5_START             : std_logic_vector(15 downto 0) := GFX2_MAIN4_START    + GFX2_BG4_ROM'length;         --0X1C000 - 0X1DFFF
constant GFX2_MAIN6_START             : std_logic_vector(15 downto 0) := GFX2_MAIN5_START    + GFX2_BG5_ROM'length;         --0X1E000 - 0X1FFFF
-- Palette was padded to 256 bytes to make this work and subsequent LUTs moved to the nearest 0x100th
constant PALETTE_START                : std_logic_vector(15 downto 0) := GFX2_MAIN6_START    + GFX2_BG6_ROM'length;         --0X20000 - 0X200FF - padded to 256 bytes
constant FGLUT_START                  : std_logic_vector(15 downto 0) := PALETTE_START       + PALETTE_ROM'length;          --0X20100 - 0x201FF
constant BGLUT_START                  : std_logic_vector(15 downto 0) := FGLUT_START         + FGLUT_ROM'length;            --0x20200 - 0x202FF

constant C_CRTROMS_AUTO_NUM      : natural := 15;  -- Amount of automatically loadable ROMs and carts, if more than 3: also adjust CRTROM_MAN_MAX in M2M/rom/shell_vars.asm, Needs to be in sync with config.vhd. Maximum is 16
constant C_CRTROMS_AUTO_NAMES    : string  := ROM1_MAIN_CPU_ROM & ROM2_MAIN_CPU_ROM & ROM3_MAIN_CPU_ROM & ROM4_MAIN_CPU_ROM &
                                              GFX1_FG1_ROM & GFX1_FG2_ROM &
                                              GFX2_BG1_ROM & GFX2_BG2_ROM & GFX2_BG3_ROM & GFX2_BG4_ROM & GFX2_BG5_ROM & GFX2_BG6_ROM &
                                              PALETTE_ROM &
                                              FGLUT_ROM & BGLUT_ROM &
                                              ENDSTR;

constant C_CRTROMS_AUTO          : crtrom_buf_array := ( 
      C_CRTROMTYPE_DEVICE, C_DEV_BP_CPU_ROM1, C_CRTROMTYPE_MANDATORY, CPU_ROM1_MAIN_START,
      C_CRTROMTYPE_DEVICE, C_DEV_BP_CPU_ROM2, C_CRTROMTYPE_MANDATORY, CPU_ROM2_MAIN_START,
      C_CRTROMTYPE_DEVICE, C_DEV_BP_CPU_ROM3, C_CRTROMTYPE_MANDATORY, CPU_ROM3_MAIN_START,
      C_CRTROMTYPE_DEVICE, C_DEV_BP_CPU_ROM4, C_CRTROMTYPE_MANDATORY, CPU_ROM4_MAIN_START,
      C_CRTROMTYPE_DEVICE, C_DEV_BP_FG1_GFX1, C_CRTROMTYPE_MANDATORY, GFX1_MAIN1_START,
      C_CRTROMTYPE_DEVICE, C_DEV_BP_FG2_GFX1, C_CRTROMTYPE_MANDATORY, GFX1_MAIN2_START,
      C_CRTROMTYPE_DEVICE, C_DEV_BP_BG1_GFX2, C_CRTROMTYPE_MANDATORY, GFX2_MAIN1_START,
      C_CRTROMTYPE_DEVICE, C_DEV_BP_BG2_GFX2, C_CRTROMTYPE_MANDATORY, GFX2_MAIN2_START,
      C_CRTROMTYPE_DEVICE, C_DEV_BP_BG3_GFX2, C_CRTROMTYPE_MANDATORY, GFX2_MAIN3_START,
      C_CRTROMTYPE_DEVICE, C_DEV_BP_BG4_GFX2, C_CRTROMTYPE_MANDATORY, GFX2_MAIN4_START,
      C_CRTROMTYPE_DEVICE, C_DEV_BP_BG5_GFX2, C_CRTROMTYPE_MANDATORY, GFX2_MAIN5_START,
      C_CRTROMTYPE_DEVICE, C_DEV_BP_BG6_GFX2, C_CRTROMTYPE_MANDATORY, GFX2_MAIN6_START,
      C_CRTROMTYPE_DEVICE, C_DEV_BP_PALETTE,  C_CRTROMTYPE_MANDATORY, PALETTE_START,
      C_CRTROMTYPE_DEVICE, C_DEV_BP_FGLUT,    C_CRTROMTYPE_MANDATORY, FGLUT_START,
      C_CRTROMTYPE_DEVICE, C_DEV_BP_BGLUT,    C_CRTROMTYPE_MANDATORY, BGLUT_START,
                                                         x"EEEE");                     -- Always finish the array using x"EEEE"


----------------------------------------------------------------------------------------------------------
-- Audio filters
--
-- If you use audio filters, then you need to copy the correct values from the MiSTer core
-- that you are porting: sys/sys_top.v
----------------------------------------------------------------------------------------------------------

-- Sample values from the C64: @TODO: Adjust to your needs
constant audio_flt_rate : std_logic_vector(31 downto 0) := std_logic_vector(to_signed(7056000, 32));
constant audio_cx       : std_logic_vector(39 downto 0) := std_logic_vector(to_signed(4258969, 40));
constant audio_cx0      : std_logic_vector( 7 downto 0) := std_logic_vector(to_signed(3, 8));
constant audio_cx1      : std_logic_vector( 7 downto 0) := std_logic_vector(to_signed(2, 8));
constant audio_cx2      : std_logic_vector( 7 downto 0) := std_logic_vector(to_signed(1, 8));
constant audio_cy0      : std_logic_vector(23 downto 0) := std_logic_vector(to_signed(-6216759, 24));
constant audio_cy1      : std_logic_vector(23 downto 0) := std_logic_vector(to_signed( 6143386, 24));
constant audio_cy2      : std_logic_vector(23 downto 0) := std_logic_vector(to_signed(-2023767, 24));
constant audio_att      : std_logic_vector( 4 downto 0) := "00000";
constant audio_mix      : std_logic_vector( 1 downto 0) := "00"; -- 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

end package globals;

