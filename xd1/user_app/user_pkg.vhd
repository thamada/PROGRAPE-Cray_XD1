-------------------------------------------------------------------------------
-- Title      : User Application Package File
-- Project    : Hello World FPGA
-------------------------------------------------------------------------------
-- File       : $RCSfile: user_pkg.vhd,v $
-- Author     : Cray Canada
-- Company    : Cray Canada Inc.
-- Created    : 2004-12-10
-- Last update: 2005/01/21
-------------------------------------------------------------------------------
-- Description: This package file is intended to contain constants, types,
-- functions and procedures used in multiple locations throughout the design.
-------------------------------------------------------------------------------
-- Copyright (c) 2004 Cray Canada Inc.
-------------------------------------------------------------------------------
-- Revisions  :
-- $Log: user_pkg.vhd,v $
-- Revision 1.2  2005/01/25 22:51:06 
-- Renamed some types and constants.
--
-- Revision 1.1  2004/12/22 23:55:00 
-- Initial checkin.
--
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

package user_pkg is

  -----------------------------------------------------------------------------
  -- Declare Types.
  -----------------------------------------------------------------------------
  -- The rt_client deals mostly on a 'byte' level.  It is useful to declare
  -- an array of bytes for use as registers and buses.
  type t_byte_array is array(natural range <>) of std_logic_vector(7 downto 0);

  -- Declare a type to enumerate the different blocks to which the rt_client
  -- interfaces.
  type t_rt_blocks is (regs, bram, qdr2);

  -- Declare an array of block select lines.
  type t_rt_sel is array (t_rt_blocks) of std_logic;

  -- Declare type for the block address decoding range.  This type determines
  -- what fabric request address lines are used identify the target block of
  -- the access.
  subtype t_rt_block_decode is std_logic_vector(26 downto 23);

  -- Declare a type for the address bus distributed to the blocks.
  subtype t_rt_block_addr is std_logic_vector(t_rt_block_decode'low-1
                                              downto 3);
  
  -- Declare a record that contains RT request information.
  type t_rt_req is record
    rd    : t_rt_sel;
    wr    : t_rt_sel;
    addr  : t_rt_block_addr;
    wdata : t_byte_array(7 downto 0);
    mask  : std_logic_vector(7 downto 0);
  end record t_rt_req;

  -- Declare a record that contains RT response information
  type t_rt_resp is record
    rdata : t_byte_array(7 downto 0);
    busy  : std_logic;
  end record t_rt_resp;
  
  -- Declare an array of response bus to be driven by the blocks connected
  -- to the rt_client.
  type t_rt_responses is array (t_rt_blocks) of t_rt_resp;

  -- Declare an array of address decoding bits for the blocks.
  type t_rt_decode_addr is array (t_rt_blocks) of t_rt_block_decode;

  -- Declare an array of latency clock cycles for the blocks.
  type t_rt_block_latency is array (t_rt_blocks) of integer;

  -----------------------------------------------------------------------------
  -- Declare Constants
  -----------------------------------------------------------------------------
  -- Create a lookup table of latencies for the blocks.
  constant c_rt_block_latency : t_rt_block_latency := (bram => 2,
                                                       qdr2 => 10,
                                                       regs => 1);

  -- Specify the largest latency.
  constant c_rt_block_max : integer := 10;

  -- Create a lookup table of address values for decoding the blocks.
  constant c_rt_block_match : t_rt_decode_addr := (bram => "0000",
                                                   qdr2 => "0001",
                                                   regs => "1000");

  -- Create a 'zero' value for an rt_req signal (usually used for reset).
  constant c_rt_req_zero : t_rt_req :=
    (rd    => (others => '0'),
     wr    => (others => '0'),
     addr  => (others => '0'),
     wdata => (others => (others => '0')),
     mask  => (others => '0'));

  -----------------------------------------------------------------------------
  -- Declare functions and procedures.
  -----------------------------------------------------------------------------
  -- The following functions interleave the parity bits with the data bits to
  -- facilitate reading and writing the QDR II RAM.
  function insert_parity (
    data : std_logic_vector(63 downto 0))
    return std_logic_vector;

  function generate_parity (
    data : std_logic_vector(63 downto 0))
    return std_logic_vector;

  function extract_parity (
    data : std_logic_vector(71 downto 0))
    return std_logic_vector;

  function extract_data (
    data : std_logic_vector(71 downto 0))
    return std_logic_vector;

end package user_pkg;

package body user_pkg is
  
  -- This function will calculate the parity byte for a 64 bit data word and
  -- return the parity byte.
  function generate_parity (
    data : std_logic_vector(63 downto 0))
    return std_logic_vector is
    variable v_result : std_logic_vector(7 downto 0);
  begin  -- function insert_parity
    v_result := xnor_reduce(data(63 downto 56)) &
                xnor_reduce(data(55 downto 48)) &
                xnor_reduce(data(47 downto 40)) &
                xnor_reduce(data(39 downto 32)) &
                xnor_reduce(data(31 downto 24)) &
                xnor_reduce(data(23 downto 16)) &
                xnor_reduce(data(15 downto 8)) &
                xnor_reduce(data(7 downto 0));
    return v_result;
  end function generate_parity;

  -- This function will calculate and interleave odd parity for a 64 bit data
  -- word.
  function insert_parity (
    data : std_logic_vector(63 downto 0))
    return std_logic_vector is
    variable v_result : std_logic_vector(71 downto 0);
  begin  -- function insert_parity
    v_result := xnor_reduce(data(63 downto 56)) & data(63 downto 56) &
                xnor_reduce(data(55 downto 48)) & data(55 downto 48) &
                xnor_reduce(data(47 downto 40)) & data(47 downto 40) &
                xnor_reduce(data(39 downto 32)) & data(39 downto 32) &
                xnor_reduce(data(31 downto 24)) & data(31 downto 24) &
                xnor_reduce(data(23 downto 16)) & data(23 downto 16) &
                xnor_reduce(data(15 downto 8)) & data(15 downto 8) &
                xnor_reduce(data(7 downto 0)) & data(7 downto 0);
    return v_result;
  end function insert_parity;

  -- This function will extract the interleaved parity bits from a 72 bit data
  -- word.
  function extract_parity (
    data : std_logic_vector(71 downto 0))
    return std_logic_vector is
    variable v_result : std_logic_vector(7 downto 0);
  begin  -- function extract_parity
    v_result := data(71) & data(62) & data(53) & data(44) &
                data(35) & data(26) & data(17) & data(8);
    return v_result;
  end function extract_parity;
  
  -- This function will extract the 64 bit data word from a 72 bit data word
  -- containing interleaved parity.
  function extract_data (
    data : std_logic_vector(71 downto 0))
    return std_logic_vector is
    variable v_result : std_logic_vector(63 downto 0);
  begin  -- function extract_data
    v_result := data(70 downto 63) &
                data(61 downto 54) &
                data(52 downto 45) &
                data(43 downto 36) &
                data(34 downto 27) &
                data(25 downto 18) &
                data(16 downto 9) &
                data(7 downto 0);
    return v_result;
  end function extract_data;

end package body user_pkg;
