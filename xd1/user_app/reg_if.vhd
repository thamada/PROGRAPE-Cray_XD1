-------------------------------------------------------------------------------
-- Title      : Processor Register Interface
-- Project    : Hello World FPGA
-------------------------------------------------------------------------------
-- File       : $RCSfile: reg_if.vhd,v $
-- Author     : Cray Canada
-- Company    : Cray Canada Inc.
-- Created    : 2004-12-16
-- Last update: 2004-12-22
-------------------------------------------------------------------------------
-- Description: The processor registers block provides a set of eight 64 bit
-- read/write registers that can be used by a processor to configure and
-- monitor the status of the FPGA.
-------------------------------------------------------------------------------
-- Copyright (c) 2004 Cray Canada Inc.
-------------------------------------------------------------------------------
-- Revisions  :
-- $Log: reg_if.vhd,v $
-- Revision 1.1  2004/12/22 23:55:00 
-- Initial checkin.
--
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_misc.all;
use work.user_pkg.all;

entity reg_if is
  port (
    reset_n   : in  std_logic;
    user_clk  : in  std_logic;
    rt_req    : in  t_rt_req;
    app_latch : in  std_logic_vector(15 downto 0);
    app_cfg   : out std_logic_vector(15 downto 0);
    rt_resp   : out t_rt_resp
    );
end entity reg_if;

architecture rtl of reg_if is

  -----------------------------------------------------------------------------
  -- Declare Types
  -----------------------------------------------------------------------------
  -- Define a subtype that determines which request address bits are used to
  -- select between registers.
  subtype t_reg_addr is std_logic_vector(5 downto 3);
  
  -----------------------------------------------------------------------------
  -- Declare Constants
  -----------------------------------------------------------------------------
  -- Define the Hello design base number, version number, and compile
  -- number.  They are placed in the first readable register.
  constant c_hello_base : std_logic_vector(15 downto 0) := x"0036";
  constant c_hello_conf : std_logic_vector(7 downto 0)  := x"01";
  constant c_hello_ver  : std_logic_vector(7 downto 0)  := x"00";
  constant c_hello_comp : std_logic_vector(7 downto 0)  := x"03";

  -- Register addresses.
  -- A subset of the request address bus is used to select between
  -- registers. These constants determine which register is at which address.
  constant c_app_id_addr    : t_reg_addr := "000";
  constant c_app_cfg_addr   : t_reg_addr := "001";
  constant c_app_latch_addr : t_reg_addr := "010";
  constant c_ureg1_addr     : t_reg_addr := "011";
  constant c_ureg2_addr     : t_reg_addr := "100";
  constant c_ureg3_addr     : t_reg_addr := "101";
  constant c_ureg4_addr     : t_reg_addr := "110";
  constant c_ureg5_addr     : t_reg_addr := "111";

  -----------------------------------------------------------------------------
  -- Declare Signals
  -----------------------------------------------------------------------------

  -- These signals form the physical registers.  Each register can be from 1
  -- to 8 bytes wide as determined by the t_byte_array() range.
  signal s_app_cfg_r   : t_byte_array(1 downto 0);
  signal s_app_latch_r : t_byte_array(1 downto 0);
  signal s_ureg1_r     : t_byte_array(7 downto 0);
  signal s_ureg2_r     : t_byte_array(7 downto 0);
  signal s_ureg3_r     : t_byte_array(7 downto 0);
  signal s_ureg4_r     : t_byte_array(7 downto 0);
  signal s_ureg5_r     : t_byte_array(7 downto 0);

  -- This signal is used to multiplex the various registers onto the read
  -- response bus.
  signal s_reg_mux : t_byte_array(7 downto 0);

begin  -- architecture rtl

  -----------------------------------------------------------------------------
  -- Read Access Process
  -- The read access process handles read requsts for registers from the RT
  -- Client.  It uses a case statement to decode the lower bits of the request
  -- address and select which register to drive onto the response data bus.
  -----------------------------------------------------------------------------
  read_access : process (user_clk, reset_n) is
  begin  -- process read_access
    if reset_n = '0' then               -- asynchronous reset (active low)
      s_reg_mux <= (others => (others => '0'));
    elsif user_clk'event and user_clk = '1' then  -- rising clock edge

      -- Assign all the s_reg_mux bits to zero.  This is a default assignment
      -- that can be overridden for specific bits by the following case
      -- statement.
      s_reg_mux <= (others => (others => '0'));

      -- The following case statement forms a multiplexor to select between the
      -- various internal registers.  The multiplexor is controlled by bits 5:3
      -- of the request address bus.  The address bus bits are compared against
      -- the addresses defined for each register.  Note that 'for' loops are
      -- used to conveniently map each byte of the register to each byte of
      -- the response data multiplexer.
      case rt_req.addr(t_reg_addr'range) is
        when c_app_id_addr =>           -- Application ID Register
          s_reg_mux(0) <= c_hello_ver;
          s_reg_mux(1) <= c_hello_conf;
          s_reg_mux(2) <= c_hello_base(7 downto 0);
          s_reg_mux(3) <= c_hello_base(15 downto 8);
          s_reg_mux(4) <= c_hello_comp;
        when c_app_cfg_addr =>          -- Example Configuration Register
          for byte in s_app_cfg_r'range loop
            s_reg_mux(byte) <= s_app_cfg_r(byte);
          end loop;
        when c_app_latch_addr =>        -- Example Latch Register
          for byte in s_app_latch_r'range loop
            s_reg_mux(byte) <= s_app_latch_r(byte);
          end loop;
        when c_ureg1_addr =>            -- Some more example registers ...
          for byte in s_ureg1_r'range loop
            s_reg_mux(byte) <= s_ureg1_r(byte);
          end loop;
        when c_ureg2_addr =>
          for byte in s_ureg2_r'range loop
            s_reg_mux(byte) <= s_ureg2_r(byte);
          end loop;
        when c_ureg3_addr =>
          for byte in s_ureg3_r'range loop
            s_reg_mux(byte) <= s_ureg3_r(byte);
          end loop;
        when c_ureg4_addr =>
          for byte in s_ureg4_r'range loop
            s_reg_mux(byte) <= s_ureg4_r(byte);
          end loop;
        when c_ureg5_addr =>
          for byte in s_ureg5_r'range loop
            s_reg_mux(byte) <= s_ureg5_r(byte);
          end loop;
        when others =>
          s_reg_mux <= (others => (others => '0'));
      end case;

    end if;
  end process read_access;

  -----------------------------------------------------------------------------
  -- Write Access Process
  -- The write access process handles write requsts for registers from the RT
  -- Client.  It uses a case statement to decode the lower bits of the request
  -- address and select which register is the target for the write.  The case
  -- statement is only processed when the write strobe (rt_req.wr(regs) is
  -- active.  Additionally, each byte of the write data is only latched if the
  -- corresponding mask bit is set.
  -----------------------------------------------------------------------------
  write_access : process (user_clk, reset_n) is
  begin  -- process write_access
    if reset_n = '0' then               -- asynchronous reset (active low)
      s_app_cfg_r   <= (others => (others => '0'));
      s_app_latch_r <= (others => (others => '0'));
      s_ureg1_r     <= (others => x"AA");
      s_ureg2_r     <= (others => x"BB");
      s_ureg3_r     <= (others => x"CC");
      s_ureg4_r     <= (others => x"DD");
      s_ureg5_r     <= (others => x"EE");
    elsif user_clk'event and user_clk = '1' then  -- rising clock edge
      -- The application latch is an example of a register that contains
      -- 'sticky' bits.  Sticky bits retain their state once set until
      -- explicitly cleared by a write to the register.
      -- The following loop creates this latching effect by 'OR'ing the
      -- contents of the register with the app_latch input.  This will be the
      -- the general state of the register unless overridden in the case
      -- statement below (i.e. a write to clear the register).
      for byte in s_app_latch_r'range loop
        s_app_latch_r(byte) <= s_app_latch_r(byte) or
                               app_latch(byte*8+7 downto byte*8);
      end loop;

      -- The following if statement detects a write to the internal registers.
      if (rt_req.wr(regs) = '1') then
        -- The following 'case' statement decodes the bottom three bits of the
        -- address to determine the target register for the write. Within
        -- each case option, a for loop is used to update the bytes of the
        -- register with the bytes of the write data word from the RT Core.
        case rt_req.addr(t_reg_addr'range) is
          when c_app_cfg_addr =>        -- Application configuration reg.
            for byte in s_app_cfg_r'range loop
              if (rt_req.mask(byte) = '1') then
                s_app_cfg_r(byte) <= rt_req.wdata(byte);
              end if;
            end loop;
          when c_app_latch_addr =>      -- Application latch reg. (sticky)
            for byte in s_app_latch_r'range loop
              if (rt_req.mask(byte) = '1') then
                s_app_latch_r(byte) <= (s_app_latch_r(byte) and
                                        not rt_req.wdata(byte))
                                       or app_latch(byte*8+7 downto byte*8);
              end if;
            end loop;
          when c_ureg1_addr =>          -- Example user register #1
            for byte in s_ureg1_r'range loop
              if (rt_req.mask(byte) = '1') then
                s_ureg1_r(byte) <= rt_req.wdata(byte);
              end if;
            end loop;
          when c_ureg2_addr =>          -- Example user register #2
            for byte in s_ureg2_r'range loop
              if (rt_req.mask(byte) = '1') then
                s_ureg2_r(byte) <= rt_req.wdata(byte);
              end if;
            end loop;
          when c_ureg3_addr =>          -- Example user register #3
            for byte in s_ureg3_r'range loop
              if (rt_req.mask(byte) = '1') then
                s_ureg3_r(byte) <= rt_req.wdata(byte);
              end if;
            end loop;
          when c_ureg4_addr =>          -- Example user register #4
            for byte in s_ureg4_r'range loop
              if (rt_req.mask(byte) = '1') then
                s_ureg4_r(byte) <= rt_req.wdata(byte);
              end if;
            end loop;
          when c_ureg5_addr =>          -- Example user register #5
            for byte in s_ureg5_r'range loop
              if (rt_req.mask(byte) = '1') then
                s_ureg5_r(byte) <= rt_req.wdata(byte);
              end if;
            end loop;
          when others =>
            null;
        end case;
      end if;
    end if;
  end process write_access;

  -- Drive output ports with internal signals.
  app_cfg(7 downto 0)  <= s_app_cfg_r(0);
  app_cfg(15 downto 8) <= s_app_cfg_r(0);
  rt_resp.rdata        <= s_reg_mux;
  rt_resp.busy         <= '0';          -- never busy.
  
end architecture rtl;
