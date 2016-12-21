-------------------------------------------------------------------------------
-- Title      : QDR II RAM Interface
-- Project    : Hello World FPGA
-------------------------------------------------------------------------------
-- File       : $RCSfile: qdr2_if.vhd,v $
-- Author     : Cray Canada
-- Company    : Cray Canada Inc.
-- Created    : 2004-12-16
-- Last update: 2005-01-13
-------------------------------------------------------------------------------
-- Description: This block interfaces the RT Client block to one of the QDR II
-- core interfaces.
-------------------------------------------------------------------------------
-- Copyright (c) 2004 Cray Canada Inc.
-------------------------------------------------------------------------------
-- Revisions  :
-- $Log: qdr2_if.vhd,v $
-- Revision 1.2  2005/01/25 22:46:40 
-- Restructured the code a bit.  General clean up.
--
-- Revision 1.1  2004/12/22 23:55:00 
-- Initial checkin.
--
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use work.user_pkg.all;

entity qdr2_if is
  port (
    reset_n   : in  std_logic;
    user_clk  : in  std_logic;
    rt_req    : in  t_rt_req;
    qdr2_dr   : in  std_logic_vector(71 downto 0);
    qdr2_ar   : out std_logic_vector(19 downto 0);
    qdr2_r_n  : out std_logic;
    qdr2_aw   : out std_logic_vector(19 downto 0);
    qdr2_w_n  : out std_logic;
    qdr2_bw_n : out std_logic_vector(7 downto 0);
    qdr2_dw   : out std_logic_vector(71 downto 0);
    qdr2_perr : out std_logic_vector(7 downto 0);
    rt_resp   : out t_rt_resp
    );
end entity qdr2_if;

architecture rtl of qdr2_if is

  -----------------------------------------------------------------------------
  -- Declare Signals
  -----------------------------------------------------------------------------
  signal s_qdr2_ar      : std_logic_vector(19 downto 0);
  signal s_qdr2_r_n     : std_logic;
  signal s_qdr2_aw      : std_logic_vector(19 downto 0);
  signal s_qdr2_w_n     : std_logic;
  signal s_qdr2_bw_n    : std_logic_vector(7 downto 0);
  signal s_qdr2_dw      : std_logic_vector(71 downto 0);
  signal s_rd_delay     : std_logic_vector(c_rt_block_latency(qdr2)-2
                                           downto 0);
  signal s_check_parity : std_logic;
  signal s_resp_data    : std_logic_vector(63 downto 0);
  signal s_resp_prty    : std_logic_vector(7 downto 0);
  signal s_exp_prty     : std_logic_vector(7 downto 0);
  signal s_qdr2_perr    : std_logic_vector(7 downto 0);

begin  -- architecture rtl

  -----------------------------------------------------------------------------
  -- QDR II RAM Read
  -- This process generates the read control signals based on the RT Client
  -- request bus.  The only signal required is the address which is just a
  -- registered version of the RT Client request bus.
  -----------------------------------------------------------------------------

  qdr2_read : process (user_clk, reset_n) is
  begin  -- process qdr2_read
    if reset_n = '0' then               -- asynchronous reset (active low)
      s_qdr2_ar      <= (others => '0');
      s_qdr2_r_n     <= '1';
      s_rd_delay     <= (others => '0');
      s_check_parity <= '0';
      s_resp_data    <= (others => '0');
      s_resp_prty    <= (others => '0');
      s_exp_prty     <= (others => '0');
      s_qdr2_perr    <= (others => '0');
    elsif user_clk'event and user_clk = '1' then  -- rising clock edge
      -- Drive the RAM address.
      s_qdr2_ar <= rt_req.addr(22 downto 3);

      -- Drive the RAM read strobe.
      s_qdr2_r_n <= not rt_req.rd(qdr2);

      -- Delay the read strobe by the amount of latency in the QDR II RAMs.
      -- The delayed strobe can then be used as a data valid flag for the RAMs.
      s_rd_delay <= s_rd_delay(s_rd_delay'high -1 downto 0) & rt_req.rd(qdr2);

      -- Register the returned data.
      if (s_rd_delay(s_rd_delay'high) = '1') then
        -- Extract the 64 bit data word out of the 72 bit QDR RAM bus.
        s_resp_data <= extract_data(qdr2_dr);
        -- Extract the 8 bits of parity out of the 72 bit QDR RAM bus.
        s_resp_prty <= extract_parity(qdr2_dr);
        -- Calculate what the parity should be for the data word read.
        s_exp_prty  <= generate_parity(extract_data(qdr2_dr));
      end if;

      -- If the expected parity for a byte doesn't match the response parity
      -- for that byte then set the corresponding parity error bit.
      s_check_parity <= s_rd_delay(s_rd_delay'high);
      if (s_check_parity = '1') then
        s_qdr2_perr <= s_resp_prty xor s_exp_prty;
      else
        s_qdr2_perr <= (others => '0');
      end if;

    end if;
  end process qdr2_read;

  -----------------------------------------------------------------------------
  -- QDR II RAM Write
  -- This process generates the write control signals based on the RT Client
  -- request bus.  The RAM write strobes are driven if the block's write strobe
  -- (rt_req.wr(qdr2)) is asserted and the corresponding byte mask is asserted.
  -- The RAM address and write data are just registered versions of the RT
  -- client request bus.
  -----------------------------------------------------------------------------

  qdr2_write : process (user_clk, reset_n) is
    variable v_remap : std_logic_vector(63 downto 0);
  begin  -- process qdr2_write
    if reset_n = '0' then               -- asynchronous reset (active low)
      s_qdr2_aw   <= (others => '0');
      s_qdr2_w_n  <= '1';
      s_qdr2_bw_n <= (others => '0');
      s_qdr2_dw   <= (others => '0');
    elsif user_clk'event and user_clk = '1' then  -- rising clock edge
      -- Drive RAM write control signals with the request when the QDR II
      -- is selected, otherwise put the RAM in an inactive state.
      if (rt_req.wr(qdr2) = '1') then
        s_qdr2_w_n  <= '0';
        s_qdr2_bw_n <= not rt_req.mask;
      else
        s_qdr2_w_n  <= '1';
        s_qdr2_bw_n <= (others => '1');
      end if;
      -- Register the RAM address and write data to line it up with the byte
      -- enables and write strobe..
      s_qdr2_aw   <= rt_req.addr(22 downto 3);

      -- A loop is used to assign the wdata bus which is of type t_byte_array
      -- to the write data bus which is a 64 bit std_logic_vector.
      for byte in 7 downto 0 loop
        v_remap(byte*8+7 downto byte*8) := rt_req.wdata(byte);
      end loop;  -- byte
      s_qdr2_dw <= insert_parity(v_remap);
    end if;
  end process qdr2_write;

  -- Drive the QDR II RAM output ports.
  qdr2_ar   <= s_qdr2_ar;
  qdr2_r_n  <= s_qdr2_r_n;
  qdr2_aw   <= s_qdr2_aw;
  qdr2_w_n  <= s_qdr2_w_n;
  qdr2_bw_n <= s_qdr2_bw_n;
  qdr2_dw   <= s_qdr2_dw;

  -- Drive the parity error flag.
  qdr2_perr <= s_qdr2_perr;

  -- Drive the response bus output ports.
  rt_resp.rdata(0) <= s_resp_data(7 downto 0);
  rt_resp.rdata(1) <= s_resp_data(15 downto 8);
  rt_resp.rdata(2) <= s_resp_data(23 downto 16);
  rt_resp.rdata(3) <= s_resp_data(31 downto 24);
  rt_resp.rdata(4) <= s_resp_data(39 downto 32);
  rt_resp.rdata(5) <= s_resp_data(47 downto 40);
  rt_resp.rdata(6) <= s_resp_data(55 downto 48);
  rt_resp.rdata(7) <= s_resp_data(63 downto 56);
  rt_resp.busy     <= '0';              -- never busy right now.

end architecture rtl;
