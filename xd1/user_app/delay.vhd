-------------------------------------------------------------------------------
-- Title      : Pipeline Delay (RAM based)
-- Project    : Hello FPGA
-------------------------------------------------------------------------------
-- File       : $RCSfile: delay.vhd,v $
-- Author     : Cray Canada
-- Company    : Cray Canada Inc.
-- Created    : 2004-11-28
-- Last update: 2004-12-17
-------------------------------------------------------------------------------
-- Description: This block is written such that RAMs can be used build long
-- and/or wide delay elements of the specified size.
-------------------------------------------------------------------------------
-- Copyright (c) 2004 Cray Canada Inc.
-------------------------------------------------------------------------------
-- Revisions  :
-- $Log: delay.vhd,v $
-- Revision 1.1  2004/12/22 23:55:00 
-- Initial checkin.
--
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use work.user_pkg.all;

---------------------------------------------------------------------------

entity delay is
  generic (no_cycles : natural := 15);
  port (
    clk      : in  std_logic;
    reset_n  : in  std_logic;
    data_in  : in  t_byte_array(7 downto 0);
    data_out : out t_byte_array(7 downto 0)
    );
end delay;

---------------------------------------------------------------------------

architecture rtl of delay is

  -----------------------------------------------------------------------------
  -- Declare Types
  -----------------------------------------------------------------------------
  type t_pipe is array (no_cycles-1 downto 0) of t_byte_array(7 downto 0);

  -----------------------------------------------------------------------------
  -- Declare Signals
  -----------------------------------------------------------------------------
  signal s_data  : t_pipe;

begin

  -----------------------------------------------------------------------------
  -- RAM Based Pipeline Process
  -- The following process creates a delay pipeline.  Since the process has no
  -- reset term, the synthesizer is free to put it in a RAM rather than
  -- registers.  It will do this is if the pipeline is sufficiently deep
  -- (rather than chewing up massive numbers of registers).
  -----------------------------------------------------------------------------
  ram_pipe : process (clk)
  begin
    if clk'event and clk = '1' then
      s_data(0) <= data_in;
      for i in no_cycles-1 downto 1 loop
        s_data(i) <= s_data(i-1);
      end loop;  -- i
    end if;
  end process ram_pipe;

  -- Drive output port
  data_out <= s_data(no_cycles-1);
  
end rtl;





