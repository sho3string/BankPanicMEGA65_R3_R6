----------------------------------------------------------------------------------
-- MiSTer2MEGA65 Framework
--
-- MEGA65 main file that contains the whole machine
--
-- MiSTer2MEGA65 done by sy2002 and MJoergen in 2022 and licensed under GPL v3
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.globals.all;
use work.types_pkg.all;
use work.video_modes_pkg.all;

library xpm;
use xpm.vcomponents.all;

entity MEGA65_Core is
generic (
   G_BOARD : string                                         -- Which platform are we running on.
);
port (
   --------------------------------------------------------------------------------------------------------
   -- QNICE Clock Domain
   --------------------------------------------------------------------------------------------------------

   -- Get QNICE clock from the framework: for the vdrives as well as for RAMs and ROMs
   qnice_clk_i             : in  std_logic;
   qnice_rst_i             : in  std_logic;

   -- Video and audio mode control
   qnice_dvi_o             : out std_logic;              -- 0=HDMI (with sound), 1=DVI (no sound)
   qnice_video_mode_o      : out video_mode_type;        -- Defined in video_modes_pkg.vhd
   qnice_osm_cfg_scaling_o : out std_logic_vector(8 downto 0);
   qnice_scandoubler_o     : out std_logic;              -- 0 = no scandoubler, 1 = scandoubler
   qnice_audio_mute_o      : out std_logic;
   qnice_audio_filter_o    : out std_logic;
   qnice_zoom_crop_o       : out std_logic;
   qnice_ascal_mode_o      : out std_logic_vector(1 downto 0);
   qnice_ascal_polyphase_o : out std_logic;
   qnice_ascal_triplebuf_o : out std_logic;
   qnice_retro15kHz_o      : out std_logic;              -- 0 = normal frequency, 1 = retro 15 kHz frequency
   qnice_csync_o           : out std_logic;              -- 0 = normal HS/VS, 1 = Composite Sync  

   -- Flip joystick ports
   qnice_flip_joyports_o   : out std_logic;

   -- On-Screen-Menu selections
   qnice_osm_control_i     : in  std_logic_vector(255 downto 0);

   -- QNICE general purpose register
   qnice_gp_reg_i          : in  std_logic_vector(255 downto 0);

   -- Core-specific devices
   qnice_dev_id_i          : in  std_logic_vector(15 downto 0);
   qnice_dev_addr_i        : in  std_logic_vector(27 downto 0);
   qnice_dev_data_i        : in  std_logic_vector(15 downto 0);
   qnice_dev_data_o        : out std_logic_vector(15 downto 0);
   qnice_dev_ce_i          : in  std_logic;
   qnice_dev_we_i          : in  std_logic;
   qnice_dev_wait_o        : out std_logic;

   --------------------------------------------------------------------------------------------------------
   -- HyperRAM Clock Domain
   --------------------------------------------------------------------------------------------------------

   hr_clk_i                : in  std_logic;
   hr_rst_i                : in  std_logic;
   hr_core_write_o         : out std_logic;
   hr_core_read_o          : out std_logic;
   hr_core_address_o       : out std_logic_vector(31 downto 0);
   hr_core_writedata_o     : out std_logic_vector(15 downto 0);
   hr_core_byteenable_o    : out std_logic_vector( 1 downto 0);
   hr_core_burstcount_o    : out std_logic_vector( 7 downto 0);
   hr_core_readdata_i      : in  std_logic_vector(15 downto 0);
   hr_core_readdatavalid_i : in  std_logic;
   hr_core_waitrequest_i   : in  std_logic;
   hr_high_i               : in  std_logic;  -- Core is too fast
   hr_low_i                : in  std_logic;  -- Core is too slow

   --------------------------------------------------------------------------------------------------------
   -- Video Clock Domain
   --------------------------------------------------------------------------------------------------------

   video_clk_o             : out std_logic;
   video_rst_o             : out std_logic;
   video_ce_o              : out std_logic;
   video_ce_ovl_o          : out std_logic;
   video_red_o             : out std_logic_vector(7 downto 0);
   video_green_o           : out std_logic_vector(7 downto 0);
   video_blue_o            : out std_logic_vector(7 downto 0);
   video_vs_o              : out std_logic;
   video_hs_o              : out std_logic;
   video_hblank_o          : out std_logic;
   video_vblank_o          : out std_logic;

   --------------------------------------------------------------------------------------------------------
   -- Core Clock Domain
   --------------------------------------------------------------------------------------------------------

   clk_i                   : in  std_logic;              -- 100 MHz clock

   -- Share clock and reset with the framework
   main_clk_o              : out std_logic;              -- CORE's 54 MHz clock
   main_rst_o              : out std_logic;              -- CORE's reset, synchronized

   -- M2M's reset manager provides 2 signals:
   --    m2m:   Reset the whole machine: Core and Framework
   --    core:  Only reset the core
   main_reset_m2m_i        : in  std_logic;
   main_reset_core_i       : in  std_logic;

   main_pause_core_i       : in  std_logic;

   -- On-Screen-Menu selections
   main_osm_control_i      : in  std_logic_vector(255 downto 0);

   -- QNICE general purpose register converted to main clock domain
   main_qnice_gp_reg_i     : in  std_logic_vector(255 downto 0);

   -- Audio output (Signed PCM)
   main_audio_left_o       : out signed(15 downto 0);
   main_audio_right_o      : out signed(15 downto 0);

   -- M2M Keyboard interface (incl. power led and drive led)
   main_kb_key_num_i       : in  integer range 0 to 79;  -- cycles through all MEGA65 keys
   main_kb_key_pressed_n_i : in  std_logic;              -- low active: debounced feedback: is kb_key_num_i pressed right now?
   main_power_led_o        : out std_logic;
   main_power_led_col_o    : out std_logic_vector(23 downto 0);
   main_drive_led_o        : out std_logic;
   main_drive_led_col_o    : out std_logic_vector(23 downto 0);

   -- Joysticks and paddles input
   main_joy_1_up_n_i       : in  std_logic;
   main_joy_1_down_n_i     : in  std_logic;
   main_joy_1_left_n_i     : in  std_logic;
   main_joy_1_right_n_i    : in  std_logic;
   main_joy_1_fire_n_i     : in  std_logic;
   main_joy_1_up_n_o       : out std_logic;
   main_joy_1_down_n_o     : out std_logic;
   main_joy_1_left_n_o     : out std_logic;
   main_joy_1_right_n_o    : out std_logic;
   main_joy_1_fire_n_o     : out std_logic;
   main_joy_2_up_n_i       : in  std_logic;
   main_joy_2_down_n_i     : in  std_logic;
   main_joy_2_left_n_i     : in  std_logic;
   main_joy_2_right_n_i    : in  std_logic;
   main_joy_2_fire_n_i     : in  std_logic;
   main_joy_2_up_n_o       : out std_logic;
   main_joy_2_down_n_o     : out std_logic;
   main_joy_2_left_n_o     : out std_logic;
   main_joy_2_right_n_o    : out std_logic;
   main_joy_2_fire_n_o     : out std_logic;

   main_pot1_x_i           : in  std_logic_vector(7 downto 0);
   main_pot1_y_i           : in  std_logic_vector(7 downto 0);
   main_pot2_x_i           : in  std_logic_vector(7 downto 0);
   main_pot2_y_i           : in  std_logic_vector(7 downto 0);
   main_rtc_i              : in  std_logic_vector(64 downto 0);

   -- CBM-488/IEC serial port
   iec_reset_n_o           : out std_logic;
   iec_atn_n_o             : out std_logic;
   iec_clk_en_o            : out std_logic;
   iec_clk_n_i             : in  std_logic;
   iec_clk_n_o             : out std_logic;
   iec_data_en_o           : out std_logic;
   iec_data_n_i            : in  std_logic;
   iec_data_n_o            : out std_logic;
   iec_srq_en_o            : out std_logic;
   iec_srq_n_i             : in  std_logic;
   iec_srq_n_o             : out std_logic;

   -- C64 Expansion Port (aka Cartridge Port)
   cart_en_o               : out std_logic;  -- Enable port, active high
   cart_phi2_o             : out std_logic;
   cart_dotclock_o         : out std_logic;
   cart_dma_i              : in  std_logic;
   cart_reset_oe_o         : out std_logic;
   cart_reset_i            : in  std_logic;
   cart_reset_o            : out std_logic;
   cart_game_oe_o          : out std_logic;
   cart_game_i             : in  std_logic;
   cart_game_o             : out std_logic;
   cart_exrom_oe_o         : out std_logic;
   cart_exrom_i            : in  std_logic;
   cart_exrom_o            : out std_logic;
   cart_nmi_oe_o           : out std_logic;
   cart_nmi_i              : in  std_logic;
   cart_nmi_o              : out std_logic;
   cart_irq_oe_o           : out std_logic;
   cart_irq_i              : in  std_logic;
   cart_irq_o              : out std_logic;
   cart_roml_oe_o          : out std_logic;
   cart_roml_i             : in  std_logic;
   cart_roml_o             : out std_logic;
   cart_romh_oe_o          : out std_logic;
   cart_romh_i             : in  std_logic;
   cart_romh_o             : out std_logic;
   cart_ctrl_oe_o          : out std_logic; -- 0 : tristate (i.e. input), 1 : output
   cart_ba_i               : in  std_logic;
   cart_rw_i               : in  std_logic;
   cart_io1_i              : in  std_logic;
   cart_io2_i              : in  std_logic;
   cart_ba_o               : out std_logic;
   cart_rw_o               : out std_logic;
   cart_io1_o              : out std_logic;
   cart_io2_o              : out std_logic;
   cart_addr_oe_o          : out std_logic; -- 0 : tristate (i.e. input), 1 : output
   cart_a_i                : in  unsigned(15 downto 0);
   cart_a_o                : out unsigned(15 downto 0);
   cart_data_oe_o          : out std_logic; -- 0 : tristate (i.e. input), 1 : output
   cart_d_i                : in  unsigned( 7 downto 0);
   cart_d_o                : out unsigned( 7 downto 0)
);
end entity MEGA65_Core;

architecture synthesis of MEGA65_Core is

---------------------------------------------------------------------------------------------
-- Clocks and active high reset signals for each clock domain
---------------------------------------------------------------------------------------------

signal main_clk            : std_logic;               -- Core main clock
signal main_rst            : std_logic;

signal video_clk           : std_logic;               
signal video_rst           : std_logic;

---------------------------------------------------------------------------------------------
-- main_clk (MiSTer core's clock)
---------------------------------------------------------------------------------------------

signal main_video_red      : std_logic_vector(2 downto 0);   
signal main_video_green    : std_logic_vector(2 downto 0);
signal main_video_blue     : std_logic_vector(1 downto 0);
signal main_video_vs       : std_logic;
signal main_video_hs       : std_logic;
signal main_video_hblank   : std_logic;
signal main_video_vblank   : std_logic;
signal main_qnice_dev_id_i : std_logic_vector(15 downto 0);

---------------------------------------------------------------------------------------------
-- qnice_clk
---------------------------------------------------------------------------------------------

constant C_FLIP_JOYS          : natural := 2;
constant C_MENU_CRT_EMULATION : natural := 6;
constant C_MENU_HDMI_16_9_50  : natural := 10;
constant C_MENU_HDMI_16_9_60  : natural := 11;
constant C_MENU_HDMI_4_3_50   : natural := 12;
constant C_MENU_HDMI_5_4_50   : natural := 13;

constant C_MENU_VGA_STD       : natural := 19;
constant C_MENU_VGA_15KHZHSVS : natural := 23;
constant C_MENU_VGA_15KHZCS   : natural := 24;

-- Dipswitch A
constant C_MENU_DSWA_0 : natural := 41;
constant C_MENU_DSWA_1 : natural := 42;
constant C_MENU_DSWA_2 : natural := 43;
constant C_MENU_DSWA_3 : natural := 44;
constant C_MENU_DSWA_4 : natural := 45;
constant C_MENU_DSWA_5 : natural := 46;
constant C_MENU_DSWA_6 : natural := 47;
constant C_MENU_DSWA_7 : natural := 48;

-- BankPanic specific video processing
signal div          : std_logic_vector(2 downto 0);
signal dsw_a_i      : std_logic_vector(7 downto 0);

signal old_clk      : std_logic;
signal ce_vid       : std_logic;
signal video_red    : std_logic_vector(7 downto 0);
signal video_green  : std_logic_vector(7 downto 0);
signal video_blue   : std_logic_vector(7 downto 0);
signal video_vs     : std_logic;
signal video_hs     : std_logic;
signal video_vblank : std_logic;
signal video_hblank : std_logic;
signal video_de     : std_logic;

-- Output from screen_rotate
signal ddram_addr       : std_logic_vector(28 downto 0);
signal ddram_data       : std_logic_vector(63 downto 0);
signal ddram_be         : std_logic_vector( 7 downto 0);
signal ddram_we         : std_logic;

-- ROM devices
signal qnice_dn_addr    : std_logic_vector(26 downto 0);
signal qnice_dn_data    : std_logic_vector(15 downto 0);
signal qnice_dn_wr      : std_logic;

-- Check the rom download state
signal rom_download   : std_logic := '0';

begin
    
   hr_core_write_o      <= '0';
   hr_core_read_o       <= '0';
   hr_core_address_o    <= (others => '0');
   hr_core_writedata_o  <= (others => '0');
   hr_core_byteenable_o <= (others => '0');
   hr_core_burstcount_o <= (others => '0');

   -- Tristate all expansion port drivers that we can directly control
   -- @TODO: As soon as we support modules that can act as busmaster, we need to become more flexible here
   cart_ctrl_oe_o       <= '0';
   cart_addr_oe_o       <= '0';
   cart_data_oe_o       <= '0';
   
   -- Due to a bug in the R5/R6 boards, the cartridge port needs to be enabled for joystick port 2 to work 
   cart_en_o <= '1' when (G_BOARD = "MEGA65_R6") or (G_BOARD = "MEGA65_R5") else '0';
   
   cart_reset_oe_o      <= '0';
   cart_game_oe_o       <= '0';
   cart_exrom_oe_o      <= '0';
   cart_nmi_oe_o        <= '0';
   cart_irq_oe_o        <= '0';
   cart_roml_oe_o       <= '0';
   cart_romh_oe_o       <= '0';
   
    -- Default values for all signals
   cart_phi2_o          <= '0';
   cart_reset_o         <= '1';
   cart_dotclock_o      <= '0';
   cart_game_o          <= '1';
   cart_exrom_o         <= '1';
   cart_nmi_o           <= '1';
   cart_irq_o           <= '1';
   cart_roml_o          <= '0';
   cart_romh_o          <= '0';
   cart_ba_o            <= '0';
   cart_rw_o            <= '0';
   cart_io1_o           <= '0';
   cart_io2_o           <= '0';
   cart_a_o             <= (others => '0');
   cart_d_o             <= (others => '0');
   
   main_joy_1_up_n_o    <= '1';
   main_joy_1_down_n_o  <= '1';
   main_joy_1_left_n_o  <= '1';
   main_joy_1_right_n_o <= '1';
   main_joy_1_fire_n_o  <= '1';
   main_joy_2_up_n_o    <= '1';
   main_joy_2_down_n_o  <= '1';
   main_joy_2_left_n_o  <= '1';
   main_joy_2_right_n_o <= '1';
   main_joy_2_fire_n_o  <= '1';

   -- Configure the LEDs:
   -- Power led on and green, drive led always off
   main_power_led_o       <= '1';
   main_drive_led_o       <= '0';
   main_drive_led_col_o   <= x"00FF00"; 
   
   -- MMCME2_ADV clock generators:
   --   @TODO YOURCORE:       54 MHz
   clk_gen : entity work.clk
      port map (
         sys_clk_i         => clk_i,           -- expects 100 MHz
         sys_rstn_i        => main_rst,        -- Asynchronous, asserted low
         
         main_clk_o        => main_clk,        -- 36 MHz main clock
         main_rst_o        => main_rst         -- reset, synchronized
      ); -- clk_gen
    
   main_clk_o  <= main_clk;
   main_rst_o  <= main_rst;
   video_clk_o <= main_clk;
   video_rst_o <= main_rst;
   main_qnice_dev_id_i <= qnice_dev_id_i;
   
   video_red_o      <= video_red;
   video_green_o    <= video_green;
   video_blue_o     <= video_blue;
   video_vs_o       <= video_vs;
   video_hs_o       <= video_hs;
   video_hblank_o   <= video_hblank;
   video_vblank_o   <= video_vblank;
   
   dsw_a_i <= main_osm_control_i(C_MENU_DSWA_7) &
              main_osm_control_i(C_MENU_DSWA_6) &
              main_osm_control_i(C_MENU_DSWA_5) &
              main_osm_control_i(C_MENU_DSWA_4) &
              main_osm_control_i(C_MENU_DSWA_3) &
              main_osm_control_i(C_MENU_DSWA_2) &
              main_osm_control_i(C_MENU_DSWA_1) &
              main_osm_control_i(C_MENU_DSWA_0); 

   ---------------------------------------------------------------------------------------------
   -- main_clk (MiSTer core's clock)
   ---------------------------------------------------------------------------------------------

   -- main.vhd contains the actual MiSTer core
   i_main : entity work.main
      generic map (
         G_VDNUM              => C_VDNUM
      )
      port map (
         clk_main_i           => main_clk,
         reset_soft_i         => main_reset_core_i,
         reset_hard_i         => main_reset_m2m_i,
        
         clk_main_speed_i     => CORE_CLK_SPEED,
         
         ioctl_download       => rom_download,

         -- Video output
         -- This is PAL 720x576 @ 50 Hz (pixel clock 27 MHz), but synchronized to main_clk (54 MHz).
         video_ce_o           => ce_vid,
         video_ce_ovl_o       => open,
         video_red_o          => main_video_red,
         video_green_o        => main_video_green,
         video_blue_o         => main_video_blue,
         video_vs_o           => main_video_vs,
         video_hs_o           => main_video_hs,
         video_hblank_o       => main_video_hblank,
         video_vblank_o       => main_video_vblank,

         -- audio output (pcm format, signed values)
         audio_left_o         => main_audio_left_o,
         audio_right_o        => main_audio_right_o,

         -- M2M Keyboard interface
         kb_key_num_i         => main_kb_key_num_i,
         kb_key_pressed_n_i   => main_kb_key_pressed_n_i,

         -- MEGA65 joysticks and paddles/mouse/potentiometers
         joy_1_up_n_i         => main_joy_1_up_n_i ,
         joy_1_down_n_i       => main_joy_1_down_n_i,
         joy_1_left_n_i       => main_joy_1_left_n_i,
         joy_1_right_n_i      => main_joy_1_right_n_i,
         joy_1_fire_n_i       => main_joy_1_fire_n_i,

         joy_2_up_n_i         => main_joy_2_up_n_i,
         joy_2_down_n_i       => main_joy_2_down_n_i,
         joy_2_left_n_i       => main_joy_2_left_n_i,
         joy_2_right_n_i      => main_joy_2_right_n_i,
         joy_2_fire_n_i       => main_joy_2_fire_n_i,
         pot1_x_i             => main_pot1_x_i,
         pot1_y_i             => main_pot1_y_i,
         pot2_x_i             => main_pot2_x_i,
         pot2_y_i             => main_pot2_y_i,
         
         dn_clk_i             => qnice_clk_i,
         dn_addr_i            => qnice_dn_addr,
         dn_data_i            => qnice_dn_data,
         dn_wr_i              => qnice_dn_wr,

         osm_control_i        => main_osm_control_i,
         qnice_dev_id_o       => main_qnice_dev_id_i,
         dsw_a_i              => dsw_a_i
         
         
      ); -- i_main

    process (main_clk) -- 36 MHz
    begin
        if rising_edge(main_clk) then
        
            old_clk    <= ce_vid;
            video_ce_o <= old_clk and (not ce_vid);
            div <= std_logic_vector(unsigned(div) + 1); 
            
            if div(0) = '1' then
               video_ce_ovl_o <= '1';
            end if;

            video_red   <= main_video_red   & main_video_red   & main_video_red(2 downto 1);
            video_green <= main_video_green & main_video_green & main_video_green(2 downto 1);
            video_blue  <= main_video_blue  & main_video_blue  & main_video_blue & main_video_blue;

            video_hs     <= main_video_hs;
            video_vs     <= not main_video_vs;
            video_hblank <= main_video_hblank;
            video_vblank <= main_video_vblank;
            video_de     <= not (main_video_hblank or main_video_vblank);
        end if;
    end process;
 
   ---------------------------------------------------------------------------------------------
   -- Audio and video settings (QNICE clock domain)
   ---------------------------------------------------------------------------------------------

   -- Due to a discussion on the MEGA65 discord (https://discord.com/channels/719326990221574164/794775503818588200/1039457688020586507)
   -- we decided to choose a naming convention for the PAL modes that might be more intuitive for the end users than it is
   -- for the programmers: "4:3" means "meant to be run on a 4:3 monitor", "5:4 on a 5:4 monitor".
   -- The technical reality is though, that in our "5:4" mode we are actually doing a 4/3 aspect ratio adjustment
   -- while in the 4:3 mode we are outputting a 5:4 image. This is kind of odd, but it seemed that our 4/3 aspect ratio
   -- adjusted image looks best on a 5:4 monitor and the other way round.
   -- Not sure if this will stay forever or if we will come up with a better naming convention.
   qnice_video_mode_o <= C_VIDEO_HDMI_5_4_50   when qnice_osm_control_i(C_MENU_HDMI_5_4_50)    = '1' else
                         C_VIDEO_HDMI_4_3_50   when qnice_osm_control_i(C_MENU_HDMI_4_3_50)    = '1' else
                         C_VIDEO_HDMI_16_9_60  when qnice_osm_control_i(C_MENU_HDMI_16_9_60)   = '1' else
                         C_VIDEO_HDMI_16_9_50;

   -- Use On-Screen-Menu selections to configure several audio and video settings
   -- Video and audio mode control
   qnice_dvi_o                <= '0';                                         -- 0=HDMI (with sound), 1=DVI (no sound)
   qnice_audio_mute_o         <= '0';                                         -- audio is not muted
   qnice_audio_filter_o       <= '1';
   --qnice_audio_filter_o       <= qnice_osm_control_i(C_MENU_IMPROVE_AUDIO);   -- 0 = raw audio, 1 = use filters from globals.vhd
   --qnice_zoom_crop_o          <= qnice_osm_control_i(C_MENU_HDMI_ZOOM);       -- 0 = no zoom/crop
   
   -- These two signals are often used as a pair (i.e. both '1'), particularly when
   -- you want to run old analog cathode ray tube monitors or TVs (via SCART)
   -- If you want to provide your users a choice, then a good choice is:
   --    "Standard VGA":                     qnice_retro15kHz_o=0 and qnice_csync_o=0
   --    "Retro 15 kHz with HSync and VSync" qnice_retro15kHz_o=1 and qnice_csync_o=0
   --    "Retro 15 kHz with CSync"           qnice_retro15kHz_o=1 and qnice_csync_o=1
   qnice_scandoubler_o        <= (not qnice_osm_control_i(C_MENU_VGA_15KHZHSVS)) and
                                 (not qnice_osm_control_i(C_MENU_VGA_15KHZCS));   
   qnice_retro15kHz_o <= qnice_osm_control_i(C_MENU_VGA_15KHZHSVS) or qnice_osm_control_i(C_MENU_VGA_15KHZCS);
   qnice_csync_o      <= qnice_osm_control_i(C_MENU_VGA_15KHZCS);
   qnice_osm_cfg_scaling_o    <= (others => '1');

   -- ascal filters that are applied while processing the input
   -- 00 : Nearest Neighbour
   -- 01 : Bilinear
   -- 10 : Sharp Bilinear
   -- 11 : Bicubic
   qnice_ascal_mode_o         <= "00";

   -- If polyphase is '1' then the ascal filter mode is ignored and polyphase filters are used instead
   -- @TODO: Right now, the filters are hardcoded in the M2M framework, we need to make them changeable inside m2m-rom.asm
   qnice_ascal_polyphase_o    <= qnice_osm_control_i(C_MENU_CRT_EMULATION);

   -- ascal triple-buffering
   -- @TODO: Right now, the M2M framework only supports OFF, so do not touch until the framework is upgraded
   qnice_ascal_triplebuf_o    <= '0';

   -- Flip joystick ports (i.e. the joystick in port 2 is used as joystick 1 and vice versa)
   qnice_flip_joyports_o      <= qnice_osm_control_i(C_FLIP_JOYS);
   
   ---------------------------------------------------------------------------------------------
   -- Core specific device handling (QNICE clock domain)
   ---------------------------------------------------------------------------------------------
   
   core_specific_devices : process(all)
   begin
      -- make sure that this is x"EEEE" by default and avoid a register here by having this default value
      qnice_dev_data_o <= x"EEEE";
      qnice_dev_wait_o <= '0';
      -- Default values
      --qnice_dn_wr      <= '0';
      qnice_dn_addr    <= (others => '0');
      qnice_dn_data    <= (others => '0');
      --rom_download     <= '0';
      -- Update rom_download based on the condition
      if qnice_dev_id_i >= x"0100" and qnice_dev_id_i <= x"010E" then
        rom_download <= '1';
        main_power_led_col_o <= x"FF0000";
      else
        rom_download <= '0';
        main_power_led_col_o <= x"00FF00";
      end if;
      
      case qnice_dev_id_i is
      
         -- Bank Panic ROMs
        when C_DEV_BP_CPU_ROM1 =>
              qnice_dn_wr   <= qnice_dev_ce_i and qnice_dev_we_i;
              qnice_dn_addr(15 downto 0) <= "00" & qnice_dev_addr_i(13 downto 0);      -- 0000000000000000 - 0011111111111111 [ 0x0000 - 0x3fff ]
              qnice_dn_data(7 downto 0) <= qnice_dev_data_i(7 downto 0);

        when C_DEV_BP_CPU_ROM2 =>
              qnice_dn_wr   <= qnice_dev_ce_i and qnice_dev_we_i;
              qnice_dn_addr(15 downto 0) <= "01" & qnice_dev_addr_i(13 downto 0);      -- 0100000000000000 - 0111111111111111 [ 0x4000 - 0x7fff ]
              qnice_dn_data(7 downto 0) <= qnice_dev_data_i(7 downto 0);
              
        when C_DEV_BP_CPU_ROM3 =>
              qnice_dn_wr   <= qnice_dev_ce_i and qnice_dev_we_i;
              qnice_dn_addr(15 downto 0) <= "10" & qnice_dev_addr_i(13 downto 0);     -- 1000000000000000 - 1011111111111111 [ 0x8000 - 0xBfff ]
              qnice_dn_data(7 downto 0) <= qnice_dev_data_i(7 downto 0);     
         
        when C_DEV_BP_CPU_ROM4 =>
              qnice_dn_wr   <= qnice_dev_ce_i and qnice_dev_we_i;                     -- 1100000000000000 - 1111111111111111 ( 0xC000 - 0xf000 )
              qnice_dn_addr(15 downto 0) <= "11" & qnice_dev_addr_i(13 downto 0); 
              qnice_dn_data(7 downto 0) <= qnice_dev_data_i(7 downto 0);   
              
         when C_DEV_BP_FG1_GFX1 =>
              qnice_dn_wr   <= qnice_dev_ce_i and qnice_dev_we_i;
              qnice_dn_addr(16 downto 0) <= "1000" & qnice_dev_addr_i(12 downto 0);   -- 0001000 0000000000000 - 0001000 1111111111111
              qnice_dn_data(7 downto 0) <= qnice_dev_data_i(7 downto 0);
         
         when C_DEV_BP_FG2_GFX1 =>
              qnice_dn_wr  <= qnice_dev_ce_i and qnice_dev_we_i;
              qnice_dn_addr(16 downto 0) <= "1001" & qnice_dev_addr_i(12 downto 0);   -- 0001001 0000000000000 - 0001001 1111111111111
              qnice_dn_data(7 downto 0) <= qnice_dev_data_i(7 downto 0); 
           
         when C_DEV_BP_BG1_GFX2 =>
              qnice_dn_wr   <= qnice_dev_ce_i and qnice_dev_we_i;
              qnice_dn_addr(16 downto 0) <= "1010" & qnice_dev_addr_i(12 downto 0);   -- 0001010 0000000000000 - 0001010 1111111111111
              qnice_dn_data(7 downto 0) <= qnice_dev_data_i(7 downto 0); 
          
         when C_DEV_BP_BG2_GFX2 =>
              qnice_dn_wr   <= qnice_dev_ce_i and qnice_dev_we_i;
              qnice_dn_addr(16 downto 0) <= "1011" & qnice_dev_addr_i(12 downto 0);   -- 0001011 0000000000000 - 0001011 1111111111111
              qnice_dn_data(7 downto 0) <= qnice_dev_data_i(7 downto 0);
             
         when C_DEV_BP_BG3_GFX2 =>
              qnice_dn_wr   <= qnice_dev_ce_i and qnice_dev_we_i;
              qnice_dn_addr(16 downto 0) <= "1100" & qnice_dev_addr_i(12 downto 0);   -- 0001100 0000000000000 - 0001100 1111111111111
              qnice_dn_data(7 downto 0) <= qnice_dev_data_i(7 downto 0);
         
         when C_DEV_BP_BG4_GFX2 =>
              qnice_dn_wr   <= qnice_dev_ce_i and qnice_dev_we_i;
              qnice_dn_addr(16 downto 0) <= "1101" & qnice_dev_addr_i(12 downto 0);   -- 0001101 0000000000000 - 0001101 1111111111111
              qnice_dn_data(7 downto 0) <= qnice_dev_data_i(7 downto 0);   
         
         when C_DEV_BP_BG5_GFX2 =>
              qnice_dn_wr   <= qnice_dev_ce_i and qnice_dev_we_i;
              qnice_dn_addr(16 downto 0) <= "1110" & qnice_dev_addr_i(12 downto 0);   -- 0001110 0000000000000 - 0001110 1111111111111
              qnice_dn_data(7 downto 0) <= qnice_dev_data_i(7 downto 0);  
         
         when C_DEV_BP_BG6_GFX2 =>
              qnice_dn_wr   <= qnice_dev_ce_i and qnice_dev_we_i;
              qnice_dn_addr(16 downto 0) <= "1111" & qnice_dev_addr_i(12 downto 0);   -- 0001111 0000000000000 - 0001111 1111111111111
              qnice_dn_data(7 downto 0) <= qnice_dev_data_i(7 downto 0);
        
         -- Palette
         -- 0x20000 - 001000000000000 00000
         -- 0x2001f - 001000000000000 11111
        when C_DEV_BP_PALETTE =>
            qnice_dn_wr   <= qnice_dev_ce_i and qnice_dev_we_i;
            qnice_dn_addr(17 downto 0) <= "1000000000" & qnice_dev_addr_i(7 downto 0);
            qnice_dn_data(7 downto 0) <= qnice_dev_data_i(7 downto 0);
    
         -- fg lut
         -- 0x20100 - 001000000001000 00000
         -- 0x201ff - 001000000001000 11111
         when C_DEV_BP_FGLUT => 
            qnice_dn_wr   <= qnice_dev_ce_i and qnice_dev_we_i;
            qnice_dn_addr(17 downto 0) <= "1000000001" & qnice_dev_addr_i(7 downto 0);
            qnice_dn_data(3 downto 0) <= qnice_dev_data_i(3 downto 0);

         
         -- bg lut
         -- 0x20200 - 001000000010000 00000
         -- 0x202ff - 001000000010000 11111
         when C_DEV_BP_BGLUT => 
            qnice_dn_wr   <= qnice_dev_ce_i and qnice_dev_we_i;
            qnice_dn_addr(17 downto 0) <= "1000000010" & qnice_dev_addr_i(7 downto 0);
            qnice_dn_data(3 downto 0) <= qnice_dev_data_i(3 downto 0);

         when others => null;
      end case;
      
      if qnice_rst_i = '1' then
        qnice_dn_wr <= '0';
      end if;
   end process core_specific_devices;

   ---------------------------------------------------------------------------------------------
   -- Dual Clocks
   ---------------------------------------------------------------------------------------------

   -- Put your dual-clock devices such as RAMs and ROMs here
   --
   -- Use the M2M framework's official RAM/ROM: dualport_2clk_ram
   -- and make sure that the you configure the port that works with QNICE as a falling edge
   -- by setting G_FALLING_A or G_FALLING_B (depending on which port you use) to true.
 
end architecture synthesis;

