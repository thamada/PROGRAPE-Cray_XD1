-------------------------------------------------------------------------------
-- Title      : User Application Block
-- Project    : Hello World FPGA
-------------------------------------------------------------------------------
-- File       : $RCSfile: user_app.vhd,v $
-- Author     : Cray Canada
-- Company    : Cray Canada Inc.
-- Created    : 2004-12-10
-- Last update: 2005-02-25
-------------------------------------------------------------------------------
-- Description: This block is the top level file of the user application logic.
-- It is instantiated by the 'top.vhd' file.  All design specific code should
-- be contained in this file and any sub blocks it instantiates.
-------------------------------------------------------------------------------
-- Copyright (c) 2004 Cray Canada Inc.
-------------------------------------------------------------------------------
-- Revisions  :
-- $Log: user_app.vhd,v $
-- Revision 1.3  2005/02/26 00:14:43 
-- Cleaned up naming.
--
-- Revision 1.2  2005/01/25 22:49:34 
-- Got rid of s_app_cfg loopback.
--
-- Revision 1.1  2004/12/22 23:55:00 
-- Initial checkin.
--
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_misc.all;
use work.user_pkg.all;

entity user_app is
  port (
    -- Global signals
    reset_n       : in  std_logic;
    user_clk      : in  std_logic;
    user_enable   : in  std_logic;
    rt_ready      : in  std_logic;
    qdr_ready     : in  std_logic;
    -- QDR II RAM Interface (unused/stubbed out in this design)
    -- RAM 1
    dr_1          : in  std_logic_vector(71 downto 0);  -- read data 
    ar_1          : out std_logic_vector(19 downto 0);  -- read address
    aw_1          : out std_logic_vector(19 downto 0);  -- write address
    r_n_1         : out std_logic;      -- Read strobe
    w_n_1         : out std_logic;      -- Write strobe
    bw_n_1        : out std_logic_vector(7 downto 0);   -- byte write
    dw_1          : out std_logic_vector(71 downto 0);  -- write data
    -- RAM 2
    dr_2          : in  std_logic_vector(71 downto 0);  -- read data 
    ar_2          : out std_logic_vector(19 downto 0);  -- read address
    aw_2          : out std_logic_vector(19 downto 0);  -- write address
    r_n_2         : out std_logic;      -- Read strobe
    w_n_2         : out std_logic;      -- Write strobe
    bw_n_2        : out std_logic_vector(7 downto 0);   -- byte write
    dw_2          : out std_logic_vector(71 downto 0);  -- write data
    -- RAM 3
    dr_3          : in  std_logic_vector(71 downto 0);  -- read data 
    ar_3          : out std_logic_vector(19 downto 0);  -- read address
    aw_3          : out std_logic_vector(19 downto 0);  -- write address
    r_n_3         : out std_logic;      -- Read strobe
    w_n_3         : out std_logic;      -- Write strobe
    bw_n_3        : out std_logic_vector(7 downto 0);   -- byte write
    dw_3          : out std_logic_vector(71 downto 0);  -- write data
    -- RAM 4
    dr_4          : in  std_logic_vector(71 downto 0);  -- read data 
    ar_4          : out std_logic_vector(19 downto 0);  -- read address
    aw_4          : out std_logic_vector(19 downto 0);  -- write address
    r_n_4         : out std_logic;      -- Read strobe
    w_n_4         : out std_logic;      -- Write strobe
    bw_n_4        : out std_logic_vector(7 downto 0);   -- byte write
    dw_4          : out std_logic_vector(71 downto 0);  -- write data
    -- RT Interface
    -- User Request Interface
    ureq_srctag   : in  std_logic_vector(4 downto 0);   -- request srctag
    ureq_full     : in  std_logic;      -- request buffer full
    ureq_notag    : in  std_logic;      -- request out of source tags
    ureq_addr     : out std_logic_vector(39 downto 3);  -- request address
    ureq_size     : out std_logic_vector(2 downto 0);   -- request size
    ureq_mask     : out std_logic_vector(7 downto 0);   -- request byte mask
    ureq_rw_n     : out std_logic;      -- request read/write
    ureq_data     : out std_logic_vector(63 downto 0);  -- request write data
    ureq_ts       : out std_logic;      -- request transfer start
    ureq_byte_req : out std_logic;      -- request type (byte or double word)
    -- Fabric Response Interface
    fresp_valid   : in  std_logic;      -- response signals valid
    fresp_ts      : in  std_logic;      -- response transfer start
    fresp_size    : in  std_logic_vector(2 downto 0);   -- response size
    fresp_srctag  : in  std_logic_vector(4 downto 0);   -- response srctag
    fresp_data    : in  std_logic_vector(63 downto 0);  -- response data
    fresp_enable  : out std_logic;      -- enable responses
    -- Fabric Request Interface
    freq_addr     : in  std_logic_vector(39 downto 3);  -- request address
    freq_size     : in  std_logic_vector(3 downto 0);   -- request size
    freq_srctag   : in  std_logic_vector(4 downto 0);   -- request srctag
    freq_mask     : in  std_logic_vector(7 downto 0);   -- request byte mask
    freq_rw_n     : in  std_logic;      -- request read/write 
    freq_ts       : in  std_logic;      -- request transfer start
    freq_valid    : in  std_logic;      -- request valid
    freq_data     : in  std_logic_vector(63 downto 0);  -- request write data
    freq_enable   : out std_logic;      -- enable request interface
    -- User Response Interface
    uresp_full    : in  std_logic;      -- response buffer full
    uresp_ts      : out std_logic;      -- response transfer start
    uresp_size    : out std_logic_vector(3 downto 0);   -- response size
    uresp_srctag  : out std_logic_vector(4 downto 0);   -- response srctag
    uresp_data    : out std_logic_vector(63 downto 0)   -- response data
    );

end entity user_app;

architecture rtl of user_app is

  -----------------------------------------------------------------------------
  -- Declare Components.
  -----------------------------------------------------------------------------

  -- The RT Client block contains the processor interface logic (i.e.
  -- address decoding, registers, etc.)  It connects to the fabric request
  -- portion of the RT Core.
  component rt_client is
    port (
      reset_n      : in  std_logic;
      user_clk     : in  std_logic;
      user_enable  : in  std_logic;
      rt_ready     : in  std_logic;
      freq_addr    : in  std_logic_vector(39 downto 3);
      freq_size    : in  std_logic_vector(3 downto 0);
      freq_mask    : in  std_logic_vector(7 downto 0);
      freq_rw_n    : in  std_logic;
      freq_ts      : in  std_logic;
      freq_valid   : in  std_logic;
      freq_data    : in  std_logic_vector(63 downto 0);
      freq_srctag  : in  std_logic_vector(4 downto 0);
      freq_enable  : out std_logic;
      uresp_full   : in  std_logic;
      uresp_ts     : out std_logic;
      uresp_size   : out std_logic_vector(3 downto 0);
      uresp_data   : out std_logic_vector(63 downto 0);
      uresp_srctag : out std_logic_vector(4 downto 0);
      rt_responses : in  t_rt_responses;
      rt_req       : out t_rt_req);
  end component rt_client;

  component reg_if is
    port (
      reset_n   : in  std_logic;
      user_clk  : in  std_logic;
      rt_req    : in  t_rt_req;
      rt_resp   : out t_rt_resp;
      app_latch : in  std_logic_vector(15 downto 0);
      app_cfg   : out std_logic_vector(15 downto 0));
  end component reg_if;

  component bram_if is
    port (
      reset_n  : in  std_logic;
      user_clk : in  std_logic;
      rt_req   : in  t_rt_req;
      rt_resp  : out t_rt_resp);
  end component bram_if;

  component qdr2_if is
    port (
      reset_n   : in  std_logic;
      user_clk  : in  std_logic;
      rt_req    : in  t_rt_req;
      rt_resp   : out t_rt_resp;
      qdr2_dr   : in  std_logic_vector(71 downto 0);
      qdr2_ar   : out std_logic_vector(19 downto 0);
      qdr2_r_n  : out std_logic;
      qdr2_aw   : out std_logic_vector(19 downto 0);
      qdr2_w_n  : out std_logic;
      qdr2_bw_n : out std_logic_vector(7 downto 0);
      qdr2_dw   : out std_logic_vector(71 downto 0);
      qdr2_perr : out std_logic_vector(7 downto 0));
  end component qdr2_if;

  -----------------------------------------------------------------------------
  -- Declare Signals.
  -----------------------------------------------------------------------------

  -- Application configuration and status signals.
  signal s_app_latch : std_logic_vector(15 downto 0);

  -- RT Client Interface signals
  signal s_rt_req       : t_rt_req;
  signal s_rt_responses : t_rt_responses;
  
begin  -- architecture rtl

  -----------------------------------------------------------------------------
  -- Instantiate the RT Client Block.
  -- The RT Client block processes the fabric requests to user logic blocks.
  -----------------------------------------------------------------------------
  rt_client_inst : rt_client
    port map (
      reset_n      => reset_n,
      user_clk     => user_clk,
      user_enable  => user_enable,
      rt_ready     => rt_ready,
      freq_addr    => freq_addr,
      freq_size    => freq_size,
      freq_mask    => freq_mask,
      freq_rw_n    => freq_rw_n,
      freq_ts      => freq_ts,
      freq_valid   => freq_valid,
      freq_data    => freq_data,
      freq_srctag  => freq_srctag,
      freq_enable  => freq_enable,
      uresp_full   => uresp_full,
      uresp_ts     => uresp_ts,
      uresp_size   => uresp_size,
      uresp_data   => uresp_data,
      uresp_srctag => uresp_srctag,
      rt_responses => s_rt_responses,
      rt_req       => s_rt_req);

  -----------------------------------------------------------------------------
  -- Instantiate the Processor Register Block
  -- This block provides read and write registers used by a processor to
  -- control the FPGA and monitor its status.
  -----------------------------------------------------------------------------
 reg_if_inst : reg_if
    port map (
      reset_n   => reset_n,
      user_clk  => user_clk,
      rt_req    => s_rt_req,
      rt_resp   => s_rt_responses(regs),
      app_latch => s_app_latch,
      app_cfg   => open);

  bram_if_inst : bram_if
    port map (
      reset_n  => reset_n,
      user_clk => user_clk,
      rt_req   => s_rt_req,
      rt_resp  => s_rt_responses(bram));

  qdr2_if_inst : qdr2_if
    port map (
      reset_n   => reset_n,
      user_clk  => user_clk,
      rt_req    => s_rt_req,
      rt_resp   => s_rt_responses(qdr2),
      qdr2_dr   => dr_1,
      qdr2_ar   => ar_1,
      qdr2_r_n  => r_n_1,
      qdr2_aw   => aw_1,
      qdr2_w_n  => w_n_1,
      qdr2_bw_n => bw_n_1,
      qdr2_dw   => dw_1,
      qdr2_perr => s_app_latch(7 downto 0));

  -----------------------------------------------------------------------------
  -- Stub Out QDR RAM Interface
  -- Three of the QDR RAMs are unused in this design so we will effectively
  -- 'stub them out' by driving their inputs with constant values.
  -- This has two effects:
  --   1) The synthesizer will reduce all the logic in the unused QDR II
  --   Core to little or nothing (freeing up resources)
  --   2) The inputs to the unused RAMs will be driven to fixed values that
  --   put the RAMs into a powered down state.
  -----------------------------------------------------------------------------
  ar_2   <= (others => '0');
  aw_2   <= (others => '0');
  r_n_2  <= '1';
  w_n_2  <= '1';
  bw_n_2 <= (others => '0');
  dw_2   <= (others => '0');
  ar_3   <= (others => '0');
  aw_3   <= (others => '0');
  r_n_3  <= '1';
  w_n_3  <= '1';
  bw_n_3 <= (others => '0');
  dw_3   <= (others => '0');
  ar_4   <= (others => '0');
  aw_4   <= (others => '0');
  r_n_4  <= '1';
  w_n_4  <= '1';
  bw_n_4 <= (others => '0');
  dw_4   <= (others => '0');

  -----------------------------------------------------------------------------
  -- Stub Out RT Core Interface
  -- The User Request side of the RT Core interface is unused so we will stub
  -- it out like the QDR II interface.
  -----------------------------------------------------------------------------
  ureq_addr     <= (others => '0');
  ureq_size     <= (others => '0');
  ureq_mask     <= (others => '0');
  ureq_rw_n     <= '0';
  ureq_data     <= (others => '0');
  ureq_ts       <= '0';
  ureq_byte_req <= '0';

  -----------------------------------------------------------------------------
  -- Stub Out app_latch inputs.
  -- Only 8 bits of the app_latch register are used (for the QDR parity) so
  -- drive the rest to zero.
  -----------------------------------------------------------------------------
  s_app_latch(15 downto 8) <= (others => '0');
  
end architecture rtl;
