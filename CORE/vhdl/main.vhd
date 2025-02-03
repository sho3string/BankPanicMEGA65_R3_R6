----------------------------------------------------------------------------------
-- MiSTer2MEGA65 Framework
--
-- Wrapper for the MiSTer core that runs exclusively in the core's clock domanin
--
-- MiSTer2MEGA65 done by sy2002 and MJoergen in 2022 and licensed under GPL v3
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.video_modes_pkg.all;

entity main is
   generic (
      G_VDNUM                 : natural                     -- amount of virtual drives
   );
   port (
      clk_main_i              : in  std_logic;
      reset_soft_i            : in  std_logic;
      reset_hard_i            : in  std_logic;

      ioctl_download          : in  std_logic;
      -- MiSTer core main clock speed:
      -- Make sure you pass very exact numbers here, because they are used for avoiding clock drift at derived clocks
      clk_main_speed_i        : in  natural;

      -- Video output
      video_ce_o              : out std_logic;
      video_ce_ovl_o          : out std_logic;
      video_red_o             : out std_logic_vector(2 downto 0);
      video_green_o           : out std_logic_vector(2 downto 0);
      video_blue_o            : out std_logic_vector(1 downto 0);
      video_vs_o              : out std_logic;
      video_hs_o              : out std_logic;
      video_hblank_o          : out std_logic;
      video_vblank_o          : out std_logic;

      -- Audio output (Signed PCM)
      audio_left_o            : out signed(15 downto 0);
      audio_right_o           : out signed(15 downto 0);

      -- M2M Keyboard interface
      kb_key_num_i            : in  integer range 0 to 79;    -- cycles through all MEGA65 keys
      kb_key_pressed_n_i      : in  std_logic;                -- low active: debounced feedback: is kb_key_num_i pressed right now?

      -- MEGA65 joysticks and paddles/mouse/potentiometers
      joy_1_up_n_i            : in  std_logic;
      joy_1_down_n_i          : in  std_logic;
      joy_1_left_n_i          : in  std_logic;
      joy_1_right_n_i         : in  std_logic;
      joy_1_fire_n_i          : in  std_logic;

      joy_2_up_n_i            : in  std_logic;
      joy_2_down_n_i          : in  std_logic;
      joy_2_left_n_i          : in  std_logic;
      joy_2_right_n_i         : in  std_logic;
      joy_2_fire_n_i          : in  std_logic;

      pot1_x_i                : in  std_logic_vector(7 downto 0);
      pot1_y_i                : in  std_logic_vector(7 downto 0);
      pot2_x_i                : in  std_logic_vector(7 downto 0);
      pot2_y_i                : in  std_logic_vector(7 downto 0);
      
      dsw_a_i                 : in  std_logic_vector(7 downto 0);

      dn_clk_i                : in  std_logic;
      dn_addr_i               : in  std_logic_vector(26 downto 0);
      dn_data_i               : in  std_logic_vector(15 downto 0);
      dn_wr_i                 : in  std_logic;

      osm_control_i           : in  std_logic_vector(255 downto 0);
      qnice_dev_id_o          : out std_logic_vector(15 downto 0)
   );
end entity main;

architecture synthesis of main is

signal keyboard_n        : std_logic_vector(79 downto 0);
signal status            : signed(31 downto 0);
signal forced_scandoubler: std_logic;
signal gamma_bus         : std_logic_vector(21 downto 0);
signal audio             : std_logic_vector(15 downto 0);

-- I/O board button press simulation ( active high )
-- b[1]: user button
-- b[0]: osd button

signal buttons           : std_logic_vector(1 downto 0);
signal reset             : std_logic  := reset_hard_i or reset_soft_i;

signal ioctl_index         : std_logic_vector(7 downto 0);

-- Game player inputs
constant m65_1             : integer := 56; --Player 1 Start
constant m65_2             : integer := 59; --Player 2 Start
constant m65_5             : integer := 16; --Insert coin 1
constant m65_6             : integer := 19; --Insert coin 2

-- Offer some keyboard controls in addition to Joy 1 Controls
constant m65_up_crsr       : integer := 73; --Player up
constant m65_vert_crsr     : integer := 7;  --Player down
constant m65_left_crsr     : integer := 74; --Player left
constant m65_horz_crsr     : integer := 2;  --Player right
constant m65_z             : integer := 12; --P1 Push 1
constant m65_x             : integer := 23; --P1 Push 2
constant m65_c             : integer := 20; --P1 Push 3

constant m65_s             : integer := 13; --Service 1
constant m65_help          : integer := 67; --Help key

begin
    audio_left_o(15) <= not audio(15);
    audio_left_o(14 downto 0) <= signed(audio(14 downto 0));
    audio_right_o(15) <= not audio(15);
    audio_right_o(14 downto 0) <= signed(audio(14 downto 0));
  
    i_u_core : entity work.core
    port map (
    
    clk_sys           => clk_main_i,                    -- 36mhz
    reset             => reset,
    
    p1(7)             => not keyboard_n(m65_x),         -- p1_push2
    p1(6)             => '0',                           -- ssw / service.
    p1(5)             => not keyboard_n(m65_5),         -- coin1
    p1(4)             => not keyboard_n(m65_z),         -- p1_push1
    p1(3)             => not keyboard_n(m65_left_crsr), -- p1_left
    p1(2)             => '0',                           -- unused
    p1(1)             => not keyboard_n(m65_horz_crsr), -- p1_right
    p1(0)             => '0',                           -- unused
    
    p2(7)             => not keyboard_n(m65_x),         -- p2_push2 / cocktail
    p2(6)             => not keyboard_n(m65_2),         -- p2_sel
    p2(5)             => not keyboard_n(m65_1),         -- p1_sel
    p2(4)             => not keyboard_n(m65_z),         -- p2_push1 / cocktail
    p2(3)             => not keyboard_n(m65_left_crsr), -- p2_left
    p2(2)             => '0',                           -- unused
    p2(1)             => not keyboard_n(m65_horz_crsr), -- p2_right
    p2(0)             => '0',                           -- unused
    
    p3(7)             => '0',                           -- unused
    p3(6)             => '0',                           -- unused
    p3(5)             => '0',                           -- unused
    p3(4)             => '0',                           -- unused
    p3(3)             => not keyboard_n(m65_s),         -- kw
    p3(2)             => not keyboard_n(m65_6),         -- coin2
    p3(1)             => not keyboard_n(m65_c),         -- p2_push3 / cocktail
    p3(0)             => not keyboard_n(m65_c),         -- p1_push3
    
    dsw               => dsw_a_i,
   
    dn_clk            => dn_clk_i,                      -- rom loading.
    ioctl_index       => ioctl_index,                   
    ioctl_download    => ioctl_download,
    ioctl_wr          => dn_wr_i,
    ioctl_addr        => dn_addr_i,                
    ioctl_dout        => dn_data_i,
  
    red               => video_red_o,
    green             => video_green_o,
    blue              => video_blue_o,
  
    vb                => video_vblank_o,
    hb                => video_hblank_o,
    vs                => video_vs_o,
    hs                => video_hs_o,
    
    ce_pix            => video_ce_o,
    hoffs             => status(27 downto 24), -- to do.
    sound             => audio
);
   i_keyboard : entity work.keyboard
      port map (
         clk_main_i           => clk_main_i,

         -- Interface to the MEGA65 keyboard
         key_num_i            => kb_key_num_i,
         key_pressed_n_i      => kb_key_pressed_n_i,

         -- @TODO: Create the kind of keyboard output that your core needs
         -- "example_n_o" is a low active register and used by the demo core:
         --    bit 0: Space
         --    bit 1: Return
         --    bit 2: Run/Stop
         example_n_o          => keyboard_n
      ); -- i_keyboard

end architecture synthesis;

