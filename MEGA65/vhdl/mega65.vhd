----------------------------------------------------------------------------------
-- MiSTer2MEGA65 Framework  
--
-- MEGA65 main file that contains the whole machine
--
-- MiSTer2MEGA65 done by sy2002 and MJoergen in 2021 and licensed under GPL v3
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.qnice_tools.all;

library work;
use work.types_pkg.all;
use work.video_modes_pkg.all;

library xpm;
use xpm.vcomponents.all;

entity MEGA65_Core is
generic (
   -- @TODO: Add your machine dependent generics of this core here or delete them, if there
   -- are no machine dependencies
   YOUR_GENERIC1  : natural;
   YOUR_GENERIC2  : string; 
   YOUR_GENERICN  : integer
);
port (
   CLK            : in std_logic;                  -- 100 MHz clock
   RESET_N        : in std_logic;                  -- CPU reset button

   -- Serial communication (rxd, txd only; rts/cts are not available)
   -- 115.200 baud, 8-N-1
   UART_RXD       : in std_logic;                  -- receive data
   UART_TXD       : out std_logic;                 -- send data

   -- VGA
   VGA_RED        : out std_logic_vector(7 downto 0);
   VGA_GREEN      : out std_logic_vector(7 downto 0);
   VGA_BLUE       : out std_logic_vector(7 downto 0);
   VGA_HS         : out std_logic;
   VGA_VS         : out std_logic;

   -- VDAC
   vdac_clk       : out std_logic;
   vdac_sync_n    : out std_logic;
   vdac_blank_n   : out std_logic;

   -- Digital Video (HDMI)
   tmds_data_p    : out std_logic_vector(2 downto 0);
   tmds_data_n    : out std_logic_vector(2 downto 0);
   tmds_clk_p     : out std_logic;
   tmds_clk_n     : out std_logic;

   -- MEGA65 smart keyboard controller
   kb_io0         : out std_logic;                 -- clock to keyboard
   kb_io1         : out std_logic;                 -- data output to keyboard
   kb_io2         : in std_logic;                  -- data input from keyboard

   -- SD Card
   SD_RESET       : out std_logic;
   SD_CLK         : out std_logic;
   SD_MOSI        : out std_logic;
   SD_MISO        : in std_logic

   -- 3.5mm analog audio jack
--   pwm_l          : out std_logic;
--   pwm_r          : out std_logic;

--   -- Joysticks
--   joy_1_up_n     : in std_logic;
--   joy_1_down_n   : in std_logic;
--   joy_1_left_n   : in std_logic;
--   joy_1_right_n  : in std_logic;
--   joy_1_fire_n   : in std_logic;

--   joy_2_up_n     : in std_logic;
--   joy_2_down_n   : in std_logic;
--   joy_2_left_n   : in std_logic;
--   joy_2_right_n  : in std_logic;
--   joy_2_fire_n   : in std_logic
);
end MEGA65_Core;

architecture beh of MEGA65_Core is

-- QNICE Firmware: Use the regular QNICE "operating system" called "Monitor" while developing
-- and debugging and use the MiSTer2MEGA65 firmware in the release version
constant QNICE_FIRMWARE       : string  := "../../QNICE/monitor/monitor.rom";
--constant QNICE_FIRMWARE       : string  := "../m2m-rom/m2m-rom.rom";

-- MiSTer2MEGA65 default resolution is HDMI 720p @ 60 Hz
constant VIDEO_MODE           : video_modes_t := C_HDMI_720p_60;  

-- Clock speeds
constant QNICE_CLK_SPEED      : natural := 50_000_000;
constant CORE_CLK_SPEED       : natural := 40_000_000;   -- @TODO YOURCORE expects 40 MHz
constant PIXEL_CLK_SPEED      : natural := VIDEO_MODE.CLK_KHZ * 1000;

-- Rendering constants (in pixels)
--    VGA_*   size of the final output on the screen
--    CORE_*  size of the input resolution coming from the core and scaling factor
--    FONT_*  size of one OSM character
constant VGA_DX               : natural := VIDEO_MODE.H_PIXELS;
constant VGA_DY               : natural := VIDEO_MODE.V_PIXELS;
constant CORE_DX              : natural := 160;
constant CORE_DY              : natural := 144;
constant CORE_TO_VGA_SCALE    : natural := 5;
constant FONT_DX              : natural := 16;
constant FONT_DY              : natural := 16;

-- Constants for the OSM screen memory
constant CHARS_DX             : natural := VGA_DX / FONT_DX;
constant CHARS_DY             : natural := VGA_DY / FONT_DY;
constant CHAR_MEM_SIZE        : natural := CHARS_DX * CHARS_DY;
constant VRAM_ADDR_WIDTH      : natural := f_log2(CHAR_MEM_SIZE);

-- Shell rendering constants (in characters)
-- The Shell uses the OSM mechanism to display itself
constant SHELL_M_X            : natural := 0;
constant SHELL_M_Y            : natural := 0;
constant SHELL_M_DX           : natural := CHARS_DX;
constant SHELL_M_DY           : natural := CHARS_DY;
constant SHELL_O_X            : natural := CHARS_DX - 20;
constant SHELL_O_Y            : natural := 0;
constant SHELL_O_DX           : natural := 20;
constant SHELL_O_DY           : natural := 20;

---------------------------------------------------------------------------------------------
-- Clocks and active high reset signals for each clock domain
---------------------------------------------------------------------------------------------

signal clk_main               : std_logic;               -- @TODO YOUR CORE's main clock @ 40.00 MHz
signal clk_qnice              : std_logic;               -- QNICE main clock @ 50 MHz
signal clk_pixel_1x           : std_logic;               -- pixel clock at normal speed (default: 720p @ 60 Hz = 74.25 MHz)
signal clk_pixel_5x           : std_logic;               -- pixel clock at 5x speed for HDMI (default: 720p @ 60 Hz = 371.25 MHz)

signal main_rst               : std_logic;
signal qnice_rst              : std_logic;
signal pixel_rst              : std_logic;

---------------------------------------------------------------------------------------------
-- clk_main (MiSTer core's clock)
---------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------
-- clk_qnice
---------------------------------------------------------------------------------------------

-- On-Screen-Menu (OSM)
signal qnice_osm_cfg_enable   : std_logic;
signal qnice_osm_cfg_xy       : std_logic_vector(15 downto 0);
signal qnice_osm_cfg_dxdy     : std_logic_vector(15 downto 0);

-- QNICE MMIO 4k-segmented access to RAMs, ROMs and similarily behaving devices
-- ramrom_dev_o: 0 = VRAM data, 1 = VRAM attributes, > 256 = free to be used for any "RAM like" device
-- ramrom_addr_o is 28-bit because we have a 16-bit window selector and a 4k window: 65536*4096 = 268.435.456 = 2^28
signal qnice_ramrom_dev       : std_logic_vector(15 downto 0);
signal qnice_ramrom_addr      : std_logic_vector(27 downto 0);
signal qnice_ramrom_data_o    : std_logic_vector(15 downto 0);
signal qnice_ramrom_data_i    : std_logic_vector(15 downto 0);
signal qnice_ramrom_ce        : std_logic;
signal qnice_ramrom_we        : std_logic;

-- VRAM
signal qnice_vram_we          : std_logic;
signal qnice_vram_data_o      : std_logic_vector(7 downto 0);
signal qnice_vram_attr_we     : std_logic;
signal qnice_vram_attr_data_o : std_logic_vector(7 downto 0);

-- Shell configuration (config.vhd)
signal qnice_config_data      : std_logic_vector(15 downto 0);   

---------------------------------------------------------------------------------------------
-- clk_pixel_1x (VGA pixelclock) and clk_pixel_5x (HDMI)
---------------------------------------------------------------------------------------------

signal vga_de                 : std_logic;            -- VGA data enable (visible pixels)
signal vga_tmds               : slv_9_0_t(0 to 2);    -- parallel TMDS symbol stream x 3 channels

-- Core frame buffer
signal vga_core_vram_addr     : std_logic_vector(14 downto 0);
signal vga_core_vram_data     : std_logic_vector(23 downto 0);

-- On-Screen-Menu (OSM)
signal vga_osm_cfg_enable     : std_logic;
signal vga_osm_cfg_xy         : std_logic_vector(15 downto 0);
signal vga_osm_cfg_dxdy       : std_logic_vector(15 downto 0);
signal vga_osm_vram_addr      : std_logic_vector(15 downto 0);
signal vga_osm_vram_data      : std_logic_vector(7 downto 0);
signal vga_osm_vram_attr      : std_logic_vector(7 downto 0);

begin

   -- MMCME2_ADV clock generators:
   --   @TODO YOURCORE:       40 MHz
   --   QNICE:                50 MHz
   --   HDMI 720p 60 Hz:      74.25 MHz (VGA) and 371.25 MHz (HDMI)
   clk_gen : entity work.clk
      port map (
         sys_clk_i    => CLK,             -- expects 100 MHz
         sys_rstn_i   => RESET_N,         -- Asynchronous, asserted low
         
         main_clk_o   => clk_main,        -- main's @TODO 40 MHz main clock
         main_rst_o   => main_rst,        -- main's reset, synchronized
         
         qnice_clk_o  => clk_qnice,       -- QNICE's 50 MHz main clock
         qnice_rst_o  => qnice_rst,       -- QNICE's reset, synchronized
         
         pixel_clk_o  => clk_pixel_1x,    -- VGA 74.25 MHz pixelclock for 720p @ 60 Hz
         pixel_rst_o  => pixel_rst,       -- VGA's reset, synchronized
         pixel_clk5_o => clk_pixel_5x     -- VGA's 371.25 MHz pixelclock (74.25 MHz x 5) for HDMI         
      );
   
   ---------------------------------------------------------------------------------------------
   -- clk_main (MiSTer core's clock)
   ---------------------------------------------------------------------------------------------

   i_main : entity work.main
      generic map (
         G_CORE_CLK_SPEED     => CORE_CLK_SPEED,
         
         -- Demo core specific generics @TODO not sure if you need them, too
         G_OUTPUT_DX          => VGA_DX,
         G_OUTPUT_DY          => VGA_DY,  
         
         -- @TODO feel free to add as many generics as your core needs
         -- you might also pass MEGA65 model specifics to your core, if needed (e.g. R2 vs. R3 differences) 
         G_YOUR_GENERIC1        => false,
         G_ANOTHER_THING        => 123456
      )
      port map (
         main_clk               => clk_main,
         reset_n                => not main_rst,
         kb_io0                 => kb_io0,
         kb_io1                 => kb_io1,
         kb_io2                 => kb_io2
      );

   ---------------------------------------------------------------------------------------------
   -- clk_qnice
   ---------------------------------------------------------------------------------------------

   -- QNICE Co-Processor (System-on-a-Chip) for ROM loading and On-Screen-Menu
   QNICE_SOC : entity work.QNICE
      generic map (
         G_FIRMWARE              => QNICE_FIRMWARE,
         G_VGA_DX                => VGA_DX,
         G_VGA_DY                => VGA_DY,
         G_FONT_DX               => FONT_DX,
         G_FONT_DY               => FONT_DY,
         G_SHELL_M_X             => SHELL_M_X,
         G_SHELL_M_Y             => SHELL_M_Y,
         G_SHELL_M_DX            => SHELL_M_DX,
         G_SHELL_M_DY            => SHELL_M_DY,
         G_SHELL_O_X             => SHELL_O_X,
         G_SHELL_O_Y             => SHELL_O_Y,
         G_SHELL_O_DX            => SHELL_O_DX,
         G_SHELL_O_DY            => SHELL_O_DY
      )
      port map (
         clk50_i                 => clk_qnice,
         reset_n_i               => not qnice_rst,
      
         -- serial communication (rxd, txd only; rts/cts are not available)
         -- 115.200 baud, 8-N-1      
         uart_rxd_i              => UART_RXD,
         uart_txd_o              => UART_TXD,

         -- SD Card
         sd_reset_o              => SD_RESET,
         sd_clk_o                => SD_CLK,
         sd_mosi_o               => SD_MOSI,
         sd_miso_i               => SD_MISO,
      
         -- QNICE public registers
         csr_reset_o             => open,
         csr_pause_o             => open,
         csr_osm_o               => qnice_osm_cfg_enable,
         csr_keyboard_o          => open,
         csr_joy1_o              => open,
         csr_joy2_o              => open,
         osm_xy_o                => qnice_osm_cfg_xy,
         osm_dxdy_o              => qnice_osm_cfg_dxdy,
      
         -- 256-bit General purpose control flags
         -- "d" = directly controled by the firmware
         -- "m" = indirectly controled by the menu system
         control_d_o             => open,
         control_m_o             => open,

         -- QNICE MMIO 4k-segmented access to RAMs, ROMs and similarily behaving devices
         -- ramrom_dev_o: 0 = VRAM data, 1 = VRAM attributes, > 256 = free to be used for any "RAM like" device
         -- ramrom_addr_o is 28-bit because we have a 16-bit window selector and a 4k window: 65536*4096 = 268.435.456 = 2^28
         ramrom_dev_o            => qnice_ramrom_dev,
         ramrom_addr_o           => qnice_ramrom_addr,
         ramrom_data_o           => qnice_ramrom_data_o,
         ramrom_data_i           => qnice_ramrom_data_i,
         ramrom_ce_o             => qnice_ramrom_ce,
         ramrom_we_o             => qnice_ramrom_we         
      );
      
   shell_cfg : entity work.config
      port map (
         -- bits 27 .. 12:    select configuration data block; called "Selector" hereafter
         -- bits 11 downto 0: address the up to 4k the configuration data
         address_i               => qnice_ramrom_addr,
         
         -- config data
         data_o                  => qnice_config_data         
      );
      
   -- The device selector qnice_ramrom_dev decides, which RAM/ROM-like device QNICE is writing to.
   -- Device numbers < 256 are reserved for QNICE; everything else can be used by your MiSTer core.
   qnice_ramrom_devices : process(all)
   variable strpos : integer;
   begin
      qnice_vram_we <= '0';
      qnice_vram_attr_we <= '0';
      qnice_ramrom_data_i <= x"EEEE";
   
      case qnice_ramrom_dev is
         -- OSM VRAM data and attributes with device numbers < 0x0100
         -- (refer to M2M/rom/sysdef.asm for a memory map and more details)
         when x"0000" =>
            qnice_vram_we <= qnice_ramrom_we;
            qnice_ramrom_data_i <= x"00" & qnice_vram_data_o;
         when x"0001" =>
            qnice_vram_attr_we <= qnice_ramrom_we;
            qnice_ramrom_data_i <= x"00" & qnice_vram_attr_data_o;
            
         -- Shell configuration data (config.vhd)
         when x"0002" =>
            qnice_ramrom_data_i <= qnice_config_data;
         
         -- @TODO YOUR RAMs or ROMs (e.g. for cartridges) and other RAM/ROM-like devices
         -- Device numbers need to be >= 0x0100         
         when others => null;            
      end case;
   end process;
      
   ---------------------------------------------------------------------------------------------
   -- clk_pixel_1x (VGA pixelclock) and clk_pixel_5x (HDMI)
   ---------------------------------------------------------------------------------------------

   i_vga : entity work.vga
      generic map (
         G_VIDEO_MODE         => VIDEO_MODE,
         G_CORE_DX            => CORE_DX,
         G_CORE_DY            => CORE_DY,
         G_CORE_TO_VGA_SCALE  => CORE_TO_VGA_SCALE,
         G_FONT_DX            => FONT_DX,
         G_FONT_DY            => FONT_DY
      )
      port map (
         clk_i                => clk_pixel_1x,     -- pixel clock at frequency of VGA mode being used
         rstn_i               => not pixel_rst,    -- active low reset
         vga_osm_cfg_enable_i => vga_osm_cfg_enable,
         vga_osm_cfg_xy_i     => vga_osm_cfg_xy,
         vga_osm_cfg_dxdy_i   => vga_osm_cfg_dxdy,
         vga_osm_vram_addr_o  => vga_osm_vram_addr,
         vga_osm_vram_data_i  => vga_osm_vram_data,
         vga_osm_vram_attr_i  => vga_osm_vram_attr,
         vga_core_vram_addr_o => vga_core_vram_addr,
         vga_core_vram_data_i => vga_core_vram_data,
         vga_red_o            => vga_red,
         vga_green_o          => vga_green,
         vga_blue_o           => vga_blue,
         vga_hs_o             => vga_hs,
         vga_vs_o             => vga_vs,
         vga_de_o             => vga_de,
         vdac_clk_o           => vdac_clk,
         vdac_sync_n_o        => vdac_sync_n,
         vdac_blank_n_o       => vdac_blank_n
      );

   i_vga_to_hdmi : entity work.vga_to_hdmi
      port map (
         select_44100 => '0',
         dvi          => '0',                         -- DVI mode: if activated, HDMI extensions like sound are deactivated
         vic          => std_logic_vector(to_unsigned(VIDEO_MODE.CEA_CTA_VIC, 8)),  -- CEA/CTA VIC 4=720p @ 60 Hz
         aspect       => VIDEO_MODE.ASPECT,           -- "10" which means 16:9 at fits for 720p
         pix_rep      => VIDEO_MODE.PIXEL_REP,        -- no pixel repetition for 720p
         vs_pol       => VIDEO_MODE.V_POL,            -- horizontal polarity: negative
         hs_pol       => VIDEO_MODE.H_POL,            -- vertaical polarity: negative

         vga_rst      => pixel_rst,                   -- active high reset
         vga_clk      => clk_pixel_1x,                -- VGA pixel clock
         vga_vs       => vga_vs,
         vga_hs       => vga_hs,
         vga_de       => vga_de,
         vga_r        => vga_red,
         vga_g        => vga_green,
         vga_b        => vga_blue,

         -- PCM audio
         pcm_rst      => main_rst,
         pcm_clk      => clk_main,
         pcm_clken    => '0',
         pcm_l        => (others => '0'),
         pcm_r        => (others => '0'),
         pcm_acr      => '0',
         pcm_n        => (others => '0'),
         pcm_cts      => (others => '0'),

         -- TMDS output (parallel)
         tmds         => vga_tmds
      ); -- i_vga_to_hdmi: entity work.vga_to_hdmi

   -- serialiser: in this design we use TMDS SelectIO outputs
   GEN_HDMI_DATA: for i in 0 to 2 generate
   begin
      HDMI_DATA: entity work.serialiser_10to1_selectio
      port map (
         rst     => pixel_rst,
         clk     => clk_pixel_1x,
         clk_x5  => clk_pixel_5x,
         d       => vga_tmds(i),
         out_p   => TMDS_data_p(i),
         out_n   => TMDS_data_n(i)
      ); -- HDMI_DATA: entity work.serialiser_10to1_selectio
   end generate GEN_HDMI_DATA;

   HDMI_CLK: entity work.serialiser_10to1_selectio
   port map (
         rst     => pixel_rst,
         clk     => clk_pixel_1x,
         clk_x5  => clk_pixel_5x,
         d       => "0000011111",
         out_p   => TMDS_clk_p,
         out_n   => TMDS_clk_n
      ); -- HDMI_CLK: entity work.serialiser_10to1_selectio

   ---------------------------------------------------------------------------------------------
   -- Dual Clocks
   ---------------------------------------------------------------------------------------------

   -- IMPORTANT THING TO PONDER AROUND DUAL-CLOCK / DUAL-PORT DEVICES SUCH AS BRAMs:
   --
   -- We might want to make sure, that all dual port dual clock RAMs here that are interacting
   -- with QNICE are rising-edge only, so that we have 20ns time versus the 10ns that are
   -- available due to the "mixed mode" of QNICE needing falling-edge and other parts of
   -- M2M need rising-edge.
   --
   -- Example: gbc4mega65 Cartridge RAM, where we ran into timing closure problems due to this.
   -- Back then, this was solved by adjusting the FPGA speed grade to the right value (-2) and
   -- "luck" due to Vivado picking the right routing optimization strategy.
   --
   -- Possible solution that does not need QNICE changes: In the MMIO-MUX part, introduce
   -- a delay for QNICE when accessing anything via the "0x7000 device system" using the
   -- WAIT_FOR_DATA mechanism. Something like this untested/unproven sketech of code:
   --     process delay_cart_rom : process (clk50)
   --     begin
   --        if rising_edge(clk50) then
   --          if WAIT = '1' then
   --              WAIT <= '0';
   --         elsif gbc_cart_en = '1' then
   --              WAIT <= '1';
   --         end if;
   --     end process;
   -- When doing this, one needs to check QNICE's internal address bus timing to see, if
   -- gbc_cart_en is asserted long enough to still work after this delay. And if not,
   -- some mechanism to compensate for this needs to be found. And of course it might be
   -- that the above-mentioned code is "too slow" (setting WAIT one cycle too late). The
   -- whole thing needs some serious brain-power-investment to be solved.
   --
   -- Advantage: Will make the whole design more robust and less prone to timing closure problems.
   --
   -- Disadvantage: Slower QNICE access to "0x7000 devices"; but as it can be seen at the time
   -- of writing this, this should not be a problem because most of the tasks QNICE does outside
   -- SD card access for mounted floppies and other devices is not realtime and therefore not
   -- timing critical. If this changed, we might introduce "high-speed" devices that are using
   -- the falling-edge and that work without WAIT_FOR_DATA.

--   i_qnice2main: xpm_cdc_array_single
--      generic map (
--         WIDTH => 56
--      )
--      port map (
--         src_clk                => qnice_clk,
--         src_in(0)              => qnice_qngbc_reset,
--         src_in(1)              => qnice_qngbc_pause,
--         src_in(2)              => qnice_qngbc_keyboard,
--         src_in(3)              => qnice_qngbc_joystick,
--         src_in(4)              => qnice_qngbc_color,
--         src_in(6 downto 5)     => qnice_qngbc_joy_map,
--         src_in(7)              => qnice_qngbc_color_mode,
--         src_in(15 downto 8)    => qnice_cart_cgb_flag,
--         src_in(23 downto 16)   => qnice_cart_sgb_flag,
--         src_in(31 downto 24)   => qnice_cart_mbc_type,
--         src_in(39 downto 32)   => qnice_cart_rom_size,
--         src_in(47 downto 40)   => qnice_cart_ram_size,
--         src_in(55 downto 48)   => qnice_cart_old_licensee,
--         dest_clk               => main_clk,
--         dest_out(0)            => main_qngbc_reset,
--         dest_out(1)            => main_qngbc_pause,
--         dest_out(2)            => main_qngbc_keyboard,
--         dest_out(3)            => main_qngbc_joystick,
--         dest_out(4)            => main_qngbc_color,
--         dest_out(6 downto 5)   => main_qngbc_joy_map,
--         dest_out(7)            => main_qngbc_color_mode,
--         dest_out(15 downto 8)  => main_cart_cgb_flag,
--         dest_out(23 downto 16) => main_cart_sgb_flag,
--         dest_out(31 downto 24) => main_cart_mbc_type,
--         dest_out(39 downto 32) => main_cart_rom_size,
--         dest_out(47 downto 40) => main_cart_ram_size,
--         dest_out(55 downto 48) => main_cart_old_licensee
--      );

--   i_main2qnice: xpm_cdc_array_single
--      generic map (
--         WIDTH => 16
--      )
--      port map (
--         src_clk                => main_clk,
--         src_in(15 downto 0)    => main_qngbc_keyb_matrix,
--         dest_clk               => qnice_clk,
--         dest_out(15 downto 0)  => qnice_qngbc_keyb_matrix
--      );

   i_qnice2vga: xpm_cdc_array_single
      generic map (
         WIDTH => 33
      )
      port map (
         src_clk                => clk_qnice,
         src_in(15 downto 0)    => qnice_osm_cfg_xy,
         src_in(31 downto 16)   => qnice_osm_cfg_dxdy,
         src_in(32)             => qnice_osm_cfg_enable,
         dest_clk               => clk_pixel_1x,
         dest_out(15 downto 0)  => vga_osm_cfg_xy,
         dest_out(31 downto 16) => vga_osm_cfg_dxdy,
         dest_out(32)           => vga_osm_cfg_enable
      );
      
   -- Dual clock & dual port RAM that acts as framebuffer: the LCD display of the gameboy is
   -- written here by the GB core (using its local clock) and the VGA/HDMI display is being fed
   -- using the pixel clock
   core_frame_buffer : entity work.dualport_2clk_ram
      generic map (
         ADDR_WIDTH   => 15,
         DATA_WIDTH   => 24
      )
      port map (
--         clock_a      => main_clk,
--         address_a    => std_logic_vector(to_unsigned(main_pixel_out_ptr, 15)),
--         data_a       => main_pixel_out_data,
--         wren_a       => main_pixel_out_we,
--         q_a          => open,

         clock_b      => clk_pixel_1x,
         address_b    => vga_core_vram_addr,
         data_b       => (others => '0'),
         wren_b       => '0',
         q_b          => vga_core_vram_data
      );

   -- Dual port & dual clock screen RAM / video RAM: contains the "ASCII" codes of the characters
   osm_vram : entity work.dualport_2clk_ram
      generic map (
         ADDR_WIDTH   => VRAM_ADDR_WIDTH,
         DATA_WIDTH   => 8,
         FALLING_A    => true              -- QNICE expects read/write to happen at the falling clock edge
      )
      port map (
         clock_a      => clk_qnice,
         address_a    => qnice_ramrom_addr(VRAM_ADDR_WIDTH-1 downto 0),
         data_a       => qnice_ramrom_data_o(7 downto 0),
         wren_a       => qnice_vram_we,
         q_a          => qnice_vram_data_o,

         clock_b      => clk_pixel_1x,
         address_b    => vga_osm_vram_addr(VRAM_ADDR_WIDTH-1 downto 0),
         q_b          => vga_osm_vram_data
      );

   -- Dual port & dual clock attribute RAM: contains inverse attribute, light/dark attrib. and colors of the chars
   -- bit 7: 1=inverse
   -- bit 6: 1=dark, 0=bright
   -- bit 5: background red
   -- bit 4: background green
   -- bit 3: background blue
   -- bit 2: foreground red
   -- bit 1: foreground green
   -- bit 0: foreground blue
   osm_vram_attr : entity work.dualport_2clk_ram
      generic map (
         ADDR_WIDTH   => VRAM_ADDR_WIDTH,
         DATA_WIDTH   => 8,
         FALLING_A    => true
      )
      port map (
         clock_a      => clk_qnice,
         address_a    => qnice_ramrom_addr(VRAM_ADDR_WIDTH-1 downto 0),
         data_a       => qnice_ramrom_data_o(7 downto 0),
         wren_a       => qnice_vram_attr_we,
         q_a          => qnice_vram_attr_data_o,

         clock_b      => clk_pixel_1x,
         address_b    => vga_osm_vram_addr(VRAM_ADDR_WIDTH-1 downto 0),       -- same address as VRAM
         q_b          => vga_osm_vram_attr
      );

end beh;

