-------------------------------------------------------------------------------
-- Title      : Block RAM Interface
-- Project    : Hello World FPGA
-------------------------------------------------------------------------------
-- File       : $RCSfile: bram_if.vhd,v $
-- Author     : Cray Canada
-- Company    : Cray Canada Inc.
-- Created    : 2004-12-16
-- Last update: 2005/05/31
-------------------------------------------------------------------------------
-- Description: This block interfaces the RT Client block to a block RAM
-- generated using Xilinx's Coregen tool.
-------------------------------------------------------------------------------
-- Copyright (c) 2004 Cray Canada Inc.
-------------------------------------------------------------------------------
-- Revisions  :
-- $Log: bram_if.vhd,v $
-- Revision 1.2  2005/01/25 22:45:17 
-- Simplified and made block RAM single port.
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

entity bram_if is
  port (
    reset_n  : in  std_logic;
    user_clk : in  std_logic;
    rt_req   : in  t_rt_req;
    rt_resp  : out t_rt_resp
    );
end entity bram_if;

architecture rtl of bram_if is

  -----------------------------------------------------------------------------
  -- Declare Components
  -----------------------------------------------------------------------------
  attribute box_type : string;

  component block_ram is
    port (
      addr : in  std_logic_vector(10 downto 0);
      clk  : in  std_logic;
      din  : in  std_logic_vector(7 downto 0);
      dout : out std_logic_vector(7 downto 0);
      we   : in  std_logic); 
  end component block_ram;

  -- Apply the 'black box' attribute to the block_ram component to let the
  -- synthesizer know that the logic for the component will be brought in at a
  -- later date (i.e. there is no synthesizable source code).  The block_ram
  -- component was generated with Xilinx's Coregen software.
  attribute box_type of block_ram : component is "black_box";

  component pgpg_mem is
    port (
      RST           : in  std_logic;
      SYS_CLK       : in  std_logic;
      PIPE_CLK      : in  std_logic;
      ADR           : in  std_logic_vector(18 downto 0);
      WE            : in  std_logic;
      DTI           : in  std_logic_vector(63 downto 0);
      DTO           : out std_logic_vector(63 downto 0);
      FPGA_NO       : in std_logic_vector(1 downto 0));
  end component pgpg_mem;

  signal pipe_rst : std_logic;
  signal pipe_we  : std_logic;
  signal pipe_dti : std_logic_vector(63 downto 0);
  signal pipe_dto : std_logic_vector(63 downto 0);
  constant pipe_fpgano : std_logic_vector(1 downto 0) := "00";
  -----------------------------------------------------------------------------
  -- Declare Signals
  -----------------------------------------------------------------------------
--  signal s_bram_addr  : std_logic_vector(10 downto 0);
  signal s_bram_addr  : std_logic_vector(18 downto 0);
  signal s_bram_we    : std_logic_vector(7 downto 0);
  signal s_bram_wdata : t_byte_array(7 downto 0);
  signal s_bram_rdata : t_byte_array(7 downto 0);
  signal s_bram_rdata_tmp : t_byte_array(7 downto 0);

  signal s_bram_addr_tmp0  : std_logic_vector(10 downto 0);
  signal s_bram_addr_tmp1  : std_logic_vector(10 downto 0);
  signal s_bram_addr_tmp2  : std_logic_vector(10 downto 0);
  signal s_bram_addr_tmp3  : std_logic_vector(10 downto 0);
  signal s_bram_addr_tmp4  : std_logic_vector(10 downto 0);

begin  -- architecture rtl

  -----------------------------------------------------------------------------
  -- Block RAM Control
  -- This process generates the write control signals based on the RT Client
  -- request bus.  The RAM write strobes are driven if the block's write strobe
  -- (rt_req.wr(bram)) is asserted and the corresponding byte mask is asserted.
  -- The RAM address and write data are just registered versions of the RT
  -- client request bus.
  -----------------------------------------------------------------------------

  ram_control : process (user_clk, reset_n) is
  begin  -- process ram_control
    if reset_n = '0' then               -- asynchronous reset (active low)
      s_bram_we    <= (others => '0');
      s_bram_wdata <= (others => (others => '0'));
      s_bram_addr  <= (others => '0');
    elsif user_clk'event and user_clk = '1' then  -- rising clock edge
      -- Create the RAM write enable signal.
      if (rt_req.wr(bram) = '1') then
        s_bram_we <= rt_req.mask;
      else
        s_bram_we <= (others => '0');
      end if;
      -- Register the data and address from the request bus to align them
      -- with the write enable.
      s_bram_wdata <= rt_req.wdata;
--      s_bram_addr  <= rt_req.addr(13 downto 3);
      s_bram_addr  <= rt_req.addr(21 downto 3);
    end if;
  end process ram_control;

  -----------------------------------------------------------------------------
  -- Block RAMs
  -- Instantiate eight 2048x8 bit block RAMs.  A 'for .. generate' loop is used
  -- for convenience and to reduce code.  Eight byte wide RAMs are created so
  -- that we can have separate write enables for each byte.  This allows
  -- the processor to do any size of read or write access to the RAMs.
  --
  -- Note: the block RAMs could also be 'inferred'.  The exact code to infer
  -- RAMs tends to depend on the synthesizer used.  Additionally, synthesizers
  -- often only support a subset of the possible block RAM configurations
  -- whereas Coregen allows all configurations (full dual port for example) to
  -- be used.
  -----------------------------------------------------------------------------

  pipe_rst <= not reset_n;
  pipe_we  <= s_bram_we(0) and s_bram_we(1) and s_bram_we(2) and s_bram_we(3) and
              s_bram_we(4) and s_bram_we(5) and s_bram_we(6) and s_bram_we(7);
  pipe_dti <= s_bram_wdata(7) & s_bram_wdata(6) & s_bram_wdata(5) & s_bram_wdata(4) & 
              s_bram_wdata(3) & s_bram_wdata(2) & s_bram_wdata(1) & s_bram_wdata(0);

  s_bram_rdata(0) <= pipe_dto( 7 downto  0);
  s_bram_rdata(1) <= pipe_dto(15 downto  8);
  s_bram_rdata(2) <= pipe_dto(23 downto 16);
  s_bram_rdata(3) <= pipe_dto(31 downto 24);
  s_bram_rdata(4) <= pipe_dto(39 downto 32);
  s_bram_rdata(5) <= pipe_dto(47 downto 40);
  s_bram_rdata(6) <= pipe_dto(55 downto 48);
  s_bram_rdata(7) <= pipe_dto(63 downto 56);

  pgr_inst : pgpg_mem
    port map (
      RST           => pipe_rst,
      SYS_CLK       => user_clk,
      PIPE_CLK      => user_clk,
      ADR           => s_bram_addr,
      WE            => pipe_we,
      DTI           => pipe_dti,
      DTO           => pipe_dto,
      FPGA_NO       => pipe_fpgano);

--  generate_rams : for byte in 0 to 7 generate
--    block_ram_inst : block_ram
--      port map (
--        addr => s_bram_addr(10 downto 0),
--        clk  => user_clk,
--        din  => s_bram_wdata(byte),
--        dout => s_bram_rdata(byte),
--        we   => s_bram_we(byte));
--  end generate generate_rams;

  -- Drive output ports
  rt_resp.rdata <= s_bram_rdata;
  rt_resp.busy  <= '0';                 -- never busy right now.

end architecture rtl;


-- ****************************************************************************
-- ****************************************************************************
-- ****************************************************************************
-- ****************************************************************************
-- ****************************************************************************
-- ****************************************************************************
-- ****************************************************************************
-- ****************************************************************************
-- ****************************************************************************
-- ****************************************************************************
-- ****************************************************************************
-- ****************************************************************************
-- ****************************************************************************
-- ****************************************************************************
-- ****************************************************************************
-- ****************************************************************************
-- ****************************************************************************
-- ****************************************************************************
-- ****************************************************************************
-- ****************************************************************************
-- ****************************************************************************
-- ****************************************************************************
-- ****************************************************************************
-- Last Modifiled at 2004/12/27

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity adr_dec is
  port (
    clk        : in std_logic;
    adr        : in std_logic_vector(18 downto 0);
    is_jpw     : out std_logic;
    is_ipw     : out std_logic;
    is_fo      : out std_logic;
    is_setn    : out std_logic;
    is_run     : out std_logic;
    FPGA_NO    : in std_logic_vector(1 downto 0));
end adr_dec;

architecture rtl of adr_dec is
signal cmd_h : std_logic_vector(6 downto 0);
signal cmd_l : std_logic_vector(11 downto 0);

begin

cmd_h <= adr(18 downto 12);
cmd_l <= adr(11 downto 0);

-- is_jpw ----------------------
process(cmd_h,cmd_l) begin -- BroadCast Only
--if (cmd_h(3) = '1') then -- 4096w * 512bit = 256KByte
--if (cmd_h(4) = '1') then -- 8192w * 512bit = 512KByte
--if (cmd_h(5) = '1') then --16384w * 512bit =   1MByte
  if (cmd_h(6) = '1') then --32768w * 512bit =   2MByte
     is_jpw <= '1';
  else
     is_jpw <= '0';
  end if;
end process;

-- is_ipw ----------------------
process(cmd_h,cmd_l) begin
  if((cmd_h = "0000101") AND (cmd_l(11 downto 10)=FPGA_NO)) then
     is_ipw <= '1';
  else
     is_ipw <= '0';
  end if;
end process;

-- is_fo -----------------------
process(cmd_h,cmd_l) begin
--  if((cmd_h = "0000110") AND (cmd_l(9 downto 8) = FPGA_NO)) then
  if((cmd_h = "0000110") AND (cmd_l(10 downto 9) = FPGA_NO)) then
     is_fo <= '1';
  else
     is_fo <= '0';
  end if;
end process;

-- is_setn ---------------------
process(cmd_h,cmd_l) begin
  if((cmd_h = "0111") AND (cmd_l(11 downto 0) = "000000000000")) then
     is_setn <= '1';
  else
     is_setn <= '0';
  end if;
end process;

-- is_run ----------------------
process(cmd_h,cmd_l) begin
  if((cmd_h = "0000111") AND (cmd_l(11 downto 0) = "000000000011")) then
     is_run <= '1';
  else
     is_run <= '0';
  end if;
end process;


end rtl;
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;                                        
use ieee.std_logic_unsigned.all;                                    

entity calc is
  port (
    start      : in  std_logic;
    clk        : in  std_logic;
    pclk       : in  std_logic;
    n          : in  std_logic_vector(31 downto 0);
    run        : out  std_logic;
    mem_adr    : out  std_logic_vector(31 downto 0));
end calc;

architecture rtl of calc is

signal rst :  std_logic;
signal rstn : std_logic_vector(31 downto 0);
signal start_r : std_logic;
signal mema_dc : std_logic_vector(17 downto 0) := (others=>'0');
begin

-- GENERATE rst PULS ------------------
process(pclk) begin
  if(pclk'event and pclk='1') then
    rst <= rstn(0);
  end if;
end process;

process (clk) begin
  if(clk'event and clk='1') then
    rstn(0) <= start_r AND (NOT start);
    start_r <= start;
  end if;
end process;
---------------------------------------

-- GENERATE run --------------------------
process(pclk,rst) begin
  if(rst = '1') then
    run <= '0';
  elsif(pclk'event and pclk='1') then
    if(mema_dc /= "000000000000000000") then
      run <= '1';
    else
      run <= '0';
    end if;
  end if;
end process;

-- GENERATE mem_adr  ---------------------
process(pclk,rst) begin
  if(rst = '1') then
    mema_dc <=  n(17 downto 0) ;
  elsif(pclk'event and pclk='1') then
    if(mema_dc /= "000000000000000000") then
      mema_dc <= mema_dc - "000000000000000001";
    end if;
  end if;
end process;
--hoge
  mem_adr <= "000000000000000" & mema_dc(15 downto 0) & "0";  -- G5
--mem_adr <= "00000000000000" & mema_dc(15 downto 0) & "00";  -- SPH FirstStage
--mem_adr <= "0000000000000" & mema_dc(15 downto 0) & "000";  -- SPH SecondStage

end rtl;
-----------------------------------------------
--  pgpg-b3 dual port RAM module (for JDIM 16)
--     32 bits
--   8192 entries
--  Copyright(c) 2004- by Tsuyoshi Hamada
--  2004/10/29 by Tsuyoshi Hamada
-----------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;

entity dpram is
  port (
    wadr: in std_logic_vector(13 downto 0);
    radr: in std_logic_vector(13 downto 0);
    wclk: in std_logic;
    rclk: in std_logic;
    din: in std_logic_vector(63 downto 0);
    dout: out std_logic_vector(63 downto 0);
    we: in std_logic);
end dpram;

architecture rtl of dpram is
component RAMB16_S1_S1
  generic (
         INIT_A : bit_vector := X"0";
         INIT_B : bit_vector := X"0";
         SRVAL_A : bit_vector := X"0";
         SRVAL_B : bit_vector := X"0";
         WRITE_MODE_A : string :="WRITE_FIRST";
         WRITE_MODE_B : string :="WRITE_FIRST");
  port ( doa   : out std_logic_vector(0 downto 0);
         addra : in std_logic_vector(13 downto 0);
         clka  : in std_logic;
         dia   : in std_logic_vector(0 downto 0);
         ena   : in std_logic;
         ssra  : in std_logic;
         wea   : in std_logic;

         dob   : out std_logic_vector(0 downto 0);
         addrb : in std_logic_vector(13 downto 0);
         clkb  : in std_logic;
         dib   : in std_logic_vector(0 downto 0);
         enb   : in std_logic;
         ssrb  : in std_logic;
         web   : in std_logic);
end component;

begin

  forgen1: for i in 0 to 63 generate
    u0: RAMB16_S1_S1 -- GENERIC MAP(WRITE_MODE=>"WRITE_FIRST");
	      PORT MAP(-- WRITE SIDE --
                       addra=>wadr(13 downto 0),clka=>wclk,
                       dia=>din(i downto i),
                       doa=>open,
                       ena=>'1',ssra=>'0',
                       wea=>we,
                       -- READ SIDE --
                       addrb=>radr(13 downto 0),clkb=>rclk,
                       dib=>(others=>'0'),
                       dob=>dout(i downto i),
                       enb=>'1',ssrb=>'0',web=>'0');
  end generate forgen1;


end rtl;

-- Copyright (c) by PGR project
-- All rights reserved.
-- Auther Tsuyoshi Hamada
-- for JDIM=4 (JDATA_WIDTH =< 128)
-- but DEPTH=16384
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity jmem is
  port (
    rst        : in  std_logic; -- not used
    we         : in  std_logic;
    wclk       : in  std_logic;
    wadr       : in  std_logic_vector(15 downto 0);
    rclk       : in  std_logic;
    radr       : in  std_logic_vector(15 downto 0);
    idata      : in  std_logic_vector(63 downto 0);
    odata      : out  std_logic_vector(127 downto 0)  -- for G5
--  odata      : out  std_logic_vector(255 downto 0)  -- for SPH FirstStage
--  odata      : out  std_logic_vector(511 downto 0)  -- for SPH SecondStage
  );
end jmem;

architecture rtl of jmem is

component dpram
	port (
	wadr: IN std_logic_VECTOR(13 downto 0);
	radr: IN std_logic_VECTOR(13 downto 0);
	wclk: IN std_logic;
	rclk: IN std_logic;
	din: IN std_logic_VECTOR(63 downto 0);
	dout: OUT std_logic_VECTOR(63 downto 0);
	we: IN std_logic);
end component;

signal we0,we1,we2,we3 : std_logic;
signal adr0,adr1,nadr0,nadr1 : std_logic;

begin

adr0  <= wadr(0);
nadr0 <= NOT wadr(0);

we0  <= we and nadr0;  -- we & wadr(0)="0"
we1  <= we and  adr0;  -- we & wadr(0)="1"

u0 : dpram port map(
      wadr=> wadr(14 downto 1),
      wclk=> wclk,
      radr=> radr(14 downto 1),
      rclk=> rclk,
      din => idata,
      dout=> odata(63 downto 0),
      we  => we0);

u1 : dpram port map(
      wadr=> wadr(14 downto 1),
      wclk=> wclk,
      radr=> radr(14 downto 1),
      rclk=> rclk,
      din => idata, 
      dout=> odata(127 downto 64),
      we  => we1);

end rtl;

--+-------------------------+
--| PGPG Fixed-Point Sub    |
--|      by Tsuyoshi Hamada |
--+-------------------------+
library ieee;
use ieee.std_logic_1164.all;

entity pg_fix_sub_32_1 is
  port(x,y : in std_logic_vector(31 downto 0);
       z : out std_logic_vector(31 downto 0);
       clk : in std_logic);
end pg_fix_sub_32_1;
architecture rtl of pg_fix_sub_32_1 is
  component pg_adder_RCA_SUB_32_1
    port (x,y: in std_logic_vector(31 downto 0);
          z:  out std_logic_vector(31 downto 0);
          clk: in std_logic);
  end component;
begin
  u0: pg_adder_RCA_SUB_32_1
      port map(x=>x,y=>y,z=>z,clk=>clk);
end rtl;

--+--------------------------------+
--| PGPG Ripple-Carry Adder        |
--|  2004/02/12 for Xilinx Devices |
--|      by Tsuyoshi Hamada        |
--+--------------------------------+
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity pg_adder_RCA_SUB_32_1 is
  port(x,y : in std_logic_vector(31 downto 0);
       z : out std_logic_vector(31 downto 0);
       clk : in std_logic);
end pg_adder_RCA_SUB_32_1;

architecture rtl of pg_adder_RCA_SUB_32_1 is

  signal sum : std_logic_vector(31 downto 0);
begin
  sum <= x - y;
  process(clk) begin
    if(clk'event and clk='1') then
      z <= sum;
    end if;
  end process;
end rtl;
-- *************************************************************** 
-- * PGPG FIXED-POINT TO LOGARITHMIC FORMAT CONVERTER            * 
-- *  For Xilinx Devices                                         * 
-- *  AUTHOR: Tsuyoshi Hamada                                    * 
-- *  VERSION: 2.01                                              * 
-- *  LAST MODIFIED AT Fri Feb 06 20:04:00 JST 2004              * 
-- *************************************************************** 
library ieee;                                                      
use ieee.std_logic_1164.all;                                       
                                                                   
entity pg_conv_ftol_32_17_8_2 is         
  port(fixdata : in std_logic_vector(31 downto 0);      
       logdata : out std_logic_vector(16 downto 0);     
       clk : in std_logic);                                        
end pg_conv_ftol_32_17_8_2;              
                                                                   
architecture rtl of pg_conv_ftol_32_17_8_2 is 
                                                                   
  component bram_rom_8408_10_8_1                      
   port (indata: in std_logic_vector(9 downto 0);    
         clk: in std_logic;                           
         outdata: out std_logic_vector(7 downto 0)); 
  end component;                                      

  component unreg_add_sub
    generic (WIDTH: integer;
             DIRECTION: string);
    port (dataa,datab: in std_logic_vector(WIDTH-1 downto 0);
          result: out std_logic_vector(WIDTH-1 downto 0));
  end component;

  component penc_31_5                        
    port( a : in std_logic_vector(30 downto 0);        
          c : out std_logic_vector(4 downto 0));      
  end component;                                                   
                                                                   
  component unreg_shift_ftol_30_10
    port( indata : in std_logic_vector(29 downto 0);   
          control : in std_logic_vector(4 downto 0);  
          outdata : out std_logic_vector(9 downto 0));
  end component;

  signal d1,d0: std_logic_vector(30 downto 0);         
  signal d2: std_logic_vector(30 downto 0);            
  signal d3,d3r: std_logic_vector(30 downto 0);        
  signal one: std_logic_vector(30 downto 0);           
  signal sign: std_logic;                                          
  signal c1: std_logic_vector(4 downto 0);            
  signal d4: std_logic_vector(29 downto 0);            
  signal c2,c3,c4,add: std_logic_vector(4 downto 0);  
  signal d5,d6: std_logic_vector(9 downto 0);         
  signal sign0,sign0r,sign1,sign2,sign3: std_logic;                
  signal nz0,nz1,nz2: std_logic;                                   
                                                                   
begin                                                              
                                                                   
  d1 <=  NOT fixdata(30 downto 0);                     
  one <= "0000000000000000000000000000001";                                              
  u1: unreg_add_sub generic map (WIDTH=>31,DIRECTION=>"ADD")
                  port map(result=>d2,dataa=>d1,datab=>one);
  d0 <= fixdata(30 downto 0);                        
  sign0 <= fixdata(31);                              
                                                                 
  with sign0 select                                              
    d3 <= d0 when '0',                                           
    d2 when others;                                              
                                                                 
  d3r <= d3;                                                   
  sign1 <= sign0;                                              
                                                                 
  u2: penc_31_5 port map (a=>d3r,c=>c1);   
  with d3r select                                                
    nz0 <= '0' when "0000000000000000000000000000000",                                  
           '1' when others;                                      
                                                                 
  process(clk) begin                                             
    if(clk'event and clk='1') then                               
      d4 <= d3r(29 downto 0);                        
      c2 <= c1;                                                  
      sign2 <= sign1;                                            
      nz1 <= nz0;                                                
    end if;                                                      
  end process;                                                   
                                                                 
  u3: unreg_shift_ftol_30_10
            port map (indata=>d4,control=>c2,outdata=>d5);

  d6 <= d5;                                                  
  sign3 <= sign2;                                            
  nz2 <= nz1;                                                
  c3 <= c2;                                                  
                                                                 
  u4: bram_rom_8408_10_8_1
            port map(indata=>d6,outdata=>logdata(7 downto 0),clk=>clk);

  with d6 select                                                 
    add <= "00001" when "1111111111",                          
           "00001" when "1111111110",                        
           "00001" when "1111111101",                        
           "00000" when others;                               
                                                                 
  u5: unreg_add_sub generic map (WIDTH=>5,DIRECTION=>"ADD")
                  port map(result=>c4,dataa=>c3,datab=>add);

  logdata(14 downto 13) <= "00";                    
                                                                 
  process(clk) begin                                             
    if(clk'event and clk='1') then                               
      logdata(16) <= sign3 ;                          
      logdata(15) <= nz2;                             
      logdata(12 downto 8) <= c4;                    
    end if;                                                      
  end process;                                                   

end rtl;

-- The Unregisterd Add/Sub
-- For Xilinx devices
-- Author: Tsuyoshi Hamada
-- Last Modified at Feb 06,2004
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity unreg_add_sub is
  generic(WIDTH : integer :=4; DIRECTION: string :="ADD");
    port (dataa,datab: in std_logic_vector(WIDTH-1 downto 0);
          result: out std_logic_vector(WIDTH-1 downto 0));
end unreg_add_sub;
architecture rtl of unreg_add_sub is
begin
ifgen0 : if (DIRECTION="ADD") generate
  result <= dataa + datab;
end generate;
ifgen1 : if (DIRECTION="SUB") generate
  result <= dataa - datab;
end generate;
end rtl;

                                                                    
library ieee;                                                       
use ieee.std_logic_1164.all;                                        
                                                                    
entity penc_31_5 is                             
port( a : in std_logic_vector(30 downto 0);              
      c : out std_logic_vector(4 downto 0));           
end penc_31_5;                                  
                                                                    
architecture rtl of penc_31_5 is                
begin                                                               
                                                                    
  process(a) begin                                                  
    if(a(30)='1') then                                    
      c <= "11110";                                              
    elsif(a(29)='1') then                                      
      c <= "11101";                                             
    elsif(a(28)='1') then                                      
      c <= "11100";                                             
    elsif(a(27)='1') then                                      
      c <= "11011";                                             
    elsif(a(26)='1') then                                      
      c <= "11010";                                             
    elsif(a(25)='1') then                                      
      c <= "11001";                                             
    elsif(a(24)='1') then                                      
      c <= "11000";                                             
    elsif(a(23)='1') then                                      
      c <= "10111";                                             
    elsif(a(22)='1') then                                      
      c <= "10110";                                             
    elsif(a(21)='1') then                                      
      c <= "10101";                                             
    elsif(a(20)='1') then                                      
      c <= "10100";                                             
    elsif(a(19)='1') then                                      
      c <= "10011";                                             
    elsif(a(18)='1') then                                      
      c <= "10010";                                             
    elsif(a(17)='1') then                                      
      c <= "10001";                                             
    elsif(a(16)='1') then                                      
      c <= "10000";                                             
    elsif(a(15)='1') then                                      
      c <= "01111";                                             
    elsif(a(14)='1') then                                      
      c <= "01110";                                             
    elsif(a(13)='1') then                                      
      c <= "01101";                                             
    elsif(a(12)='1') then                                      
      c <= "01100";                                             
    elsif(a(11)='1') then                                      
      c <= "01011";                                             
    elsif(a(10)='1') then                                      
      c <= "01010";                                             
    elsif(a(9)='1') then                                      
      c <= "01001";                                             
    elsif(a(8)='1') then                                      
      c <= "01000";                                             
    elsif(a(7)='1') then                                      
      c <= "00111";                                             
    elsif(a(6)='1') then                                      
      c <= "00110";                                             
    elsif(a(5)='1') then                                      
      c <= "00101";                                             
    elsif(a(4)='1') then                                      
      c <= "00100";                                             
    elsif(a(3)='1') then                                      
      c <= "00011";                                             
    elsif(a(2)='1') then                                      
      c <= "00010";                                             
    elsif(a(1)='1') then                                      
      c <= "00001";                                             
    else                                                            
      c <= "00000";                                               
    end if;                                                         
  end process;                                                      
                                                                    
end rtl;                                                            

-- The barrel shifter for Fix to Log Converter
-- Author: Tsuyoshi Hamada
-- Last Modified at Feb 6,2003
library ieee;
use ieee.std_logic_1164.all;

entity unreg_shift_ftol_30_10 is
  port( indata : in std_logic_vector(29 downto 0);
        control : in std_logic_vector(4 downto 0);
        outdata : out std_logic_vector(9 downto 0));
end unreg_shift_ftol_30_10;

architecture rtl of unreg_shift_ftol_30_10 is

  signal cntd_4 : std_logic;
  signal d0 : std_logic_vector(39 downto 0);
  signal s0,s1,s2,s3,s4,s5,s6,s7,s8,s9,s10,s11,s12,s13,s14,s15,s16,s17,s18,s19,s20,s21,s22,s23,s24,s25,s26,s27,s28,s29,s30,s31 : std_logic_vector(9 downto 0);
  signal c0xxxx, c1xxxx : std_logic_vector(9 downto 0);
  signal c0xxxxd,c1xxxxd : std_logic_vector(9 downto 0);

begin

  with cntd_4 select               
    outdata <= c0xxxxd when '0',   
               c1xxxxd when others;

  cntd_4 <= control(4);
  c0xxxxd <= c0xxxx;
  c1xxxxd <= c1xxxx;

  d0 <= indata & "0000000000";

  s0 <= d0(9 downto 0);
  s1 <= d0(10 downto 1);
  s2 <= d0(11 downto 2);
  s3 <= d0(12 downto 3);
  s4 <= d0(13 downto 4);
  s5 <= d0(14 downto 5);
  s6 <= d0(15 downto 6);
  s7 <= d0(16 downto 7);
  s8 <= d0(17 downto 8);
  s9 <= d0(18 downto 9);
  s10 <= d0(19 downto 10);
  s11 <= d0(20 downto 11);
  s12 <= d0(21 downto 12);
  s13 <= d0(22 downto 13);
  s14 <= d0(23 downto 14);
  s15 <= d0(24 downto 15);
  s16 <= d0(25 downto 16);
  s17 <= d0(26 downto 17);
  s18 <= d0(27 downto 18);
  s19 <= d0(28 downto 19);
  s20 <= d0(29 downto 20);
  s21 <= d0(30 downto 21);
  s22 <= d0(31 downto 22);
  s23 <= d0(32 downto 23);
  s24 <= d0(33 downto 24);
  s25 <= d0(34 downto 25);
  s26 <= d0(35 downto 26);
  s27 <= d0(36 downto 27);
  s28 <= d0(37 downto 28);
  s29 <= d0(38 downto 29);
  s30 <= d0(39 downto 30);
  s31 <= '0' & d0(39 downto 31);

-- Specified to LCELL 4-bit inputs.
  with control(3 downto 0) select
    c0xxxx <= s0 when "0000",  
           s1 when "0001",     
           s2 when "0010",     
           s3 when "0011",     
           s4 when "0100",     
           s5 when "0101",     
           s6 when "0110",     
           s7 when "0111",     
           s8 when "1000",     
           s9 when "1001",     
           s10 when "1010",    
           s11 when "1011",    
           s12 when "1100",    
           s13 when "1101",    
           s14 when "1110",    
           s15 when others;      

  with control(3 downto 0) select
    c1xxxx <= s16 when "0000", 
           s17 when "0001",    
           s18 when "0010",    
           s19 when "0011",    
           s20 when "0100",    
           s21 when "0101",    
           s22 when "0110",    
           s23 when "0111",    
           s24 when "1000",    
           s25 when "1001",    
           s26 when "1010",    
           s27 when "1011",    
           s28 when "1100",    
           s29 when "1101",    
           s30 when "1110",    
           s31 when others;      

end rtl;

-- ROM using Xilinx BlockRAM       
-- Author: Tsuyoshi Hamada         
-- Last Modified at Jun 2, 2004    
-- In 10 Out 8 Stage 1 Type"8408"
library ieee;                      
use ieee.std_logic_1164.all;       
use ieee.std_logic_arith.all;      
use ieee.std_logic_unsigned.all;   

entity bram_rom_8408_10_8_1 is
  port( indata : in std_logic_vector(9 downto 0);
        clk : in std_logic;
        outdata : out std_logic_vector(7 downto 0));
end bram_rom_8408_10_8_1;

architecture rtl of bram_rom_8408_10_8_1 is

  type romarray is array(0 to 1023) of std_logic_vector(7 downto 0);
  constant brom : romarray :=(
    "00000000",   -- 0x0 : 0x0
    "00000001",   -- 0x1 : 0x1
    "00000001",   -- 0x2 : 0x1
    "00000001",   -- 0x3 : 0x1
    "00000010",   -- 0x4 : 0x2
    "00000010",   -- 0x5 : 0x2
    "00000010",   -- 0x6 : 0x2
    "00000011",   -- 0x7 : 0x3
    "00000011",   -- 0x8 : 0x3
    "00000011",   -- 0x9 : 0x3
    "00000100",   -- 0xA : 0x4
    "00000100",   -- 0xB : 0x4
    "00000100",   -- 0xC : 0x4
    "00000101",   -- 0xD : 0x5
    "00000101",   -- 0xE : 0x5
    "00000110",   -- 0xF : 0x6
    "00000110",   -- 0x10 : 0x6
    "00000110",   -- 0x11 : 0x6
    "00000111",   -- 0x12 : 0x7
    "00000111",   -- 0x13 : 0x7
    "00000111",   -- 0x14 : 0x7
    "00001000",   -- 0x15 : 0x8
    "00001000",   -- 0x16 : 0x8
    "00001000",   -- 0x17 : 0x8
    "00001001",   -- 0x18 : 0x9
    "00001001",   -- 0x19 : 0x9
    "00001001",   -- 0x1A : 0x9
    "00001010",   -- 0x1B : 0xA
    "00001010",   -- 0x1C : 0xA
    "00001010",   -- 0x1D : 0xA
    "00001011",   -- 0x1E : 0xB
    "00001011",   -- 0x1F : 0xB
    "00001100",   -- 0x20 : 0xC
    "00001100",   -- 0x21 : 0xC
    "00001100",   -- 0x22 : 0xC
    "00001101",   -- 0x23 : 0xD
    "00001101",   -- 0x24 : 0xD
    "00001101",   -- 0x25 : 0xD
    "00001110",   -- 0x26 : 0xE
    "00001110",   -- 0x27 : 0xE
    "00001110",   -- 0x28 : 0xE
    "00001111",   -- 0x29 : 0xF
    "00001111",   -- 0x2A : 0xF
    "00001111",   -- 0x2B : 0xF
    "00010000",   -- 0x2C : 0x10
    "00010000",   -- 0x2D : 0x10
    "00010000",   -- 0x2E : 0x10
    "00010001",   -- 0x2F : 0x11
    "00010001",   -- 0x30 : 0x11
    "00010001",   -- 0x31 : 0x11
    "00010010",   -- 0x32 : 0x12
    "00010010",   -- 0x33 : 0x12
    "00010010",   -- 0x34 : 0x12
    "00010011",   -- 0x35 : 0x13
    "00010011",   -- 0x36 : 0x13
    "00010011",   -- 0x37 : 0x13
    "00010100",   -- 0x38 : 0x14
    "00010100",   -- 0x39 : 0x14
    "00010101",   -- 0x3A : 0x15
    "00010101",   -- 0x3B : 0x15
    "00010101",   -- 0x3C : 0x15
    "00010110",   -- 0x3D : 0x16
    "00010110",   -- 0x3E : 0x16
    "00010110",   -- 0x3F : 0x16
    "00010111",   -- 0x40 : 0x17
    "00010111",   -- 0x41 : 0x17
    "00010111",   -- 0x42 : 0x17
    "00011000",   -- 0x43 : 0x18
    "00011000",   -- 0x44 : 0x18
    "00011000",   -- 0x45 : 0x18
    "00011001",   -- 0x46 : 0x19
    "00011001",   -- 0x47 : 0x19
    "00011001",   -- 0x48 : 0x19
    "00011010",   -- 0x49 : 0x1A
    "00011010",   -- 0x4A : 0x1A
    "00011010",   -- 0x4B : 0x1A
    "00011011",   -- 0x4C : 0x1B
    "00011011",   -- 0x4D : 0x1B
    "00011011",   -- 0x4E : 0x1B
    "00011100",   -- 0x4F : 0x1C
    "00011100",   -- 0x50 : 0x1C
    "00011100",   -- 0x51 : 0x1C
    "00011101",   -- 0x52 : 0x1D
    "00011101",   -- 0x53 : 0x1D
    "00011101",   -- 0x54 : 0x1D
    "00011110",   -- 0x55 : 0x1E
    "00011110",   -- 0x56 : 0x1E
    "00011110",   -- 0x57 : 0x1E
    "00011111",   -- 0x58 : 0x1F
    "00011111",   -- 0x59 : 0x1F
    "00011111",   -- 0x5A : 0x1F
    "00100000",   -- 0x5B : 0x20
    "00100000",   -- 0x5C : 0x20
    "00100000",   -- 0x5D : 0x20
    "00100001",   -- 0x5E : 0x21
    "00100001",   -- 0x5F : 0x21
    "00100001",   -- 0x60 : 0x21
    "00100010",   -- 0x61 : 0x22
    "00100010",   -- 0x62 : 0x22
    "00100010",   -- 0x63 : 0x22
    "00100011",   -- 0x64 : 0x23
    "00100011",   -- 0x65 : 0x23
    "00100011",   -- 0x66 : 0x23
    "00100100",   -- 0x67 : 0x24
    "00100100",   -- 0x68 : 0x24
    "00100100",   -- 0x69 : 0x24
    "00100101",   -- 0x6A : 0x25
    "00100101",   -- 0x6B : 0x25
    "00100101",   -- 0x6C : 0x25
    "00100110",   -- 0x6D : 0x26
    "00100110",   -- 0x6E : 0x26
    "00100110",   -- 0x6F : 0x26
    "00100110",   -- 0x70 : 0x26
    "00100111",   -- 0x71 : 0x27
    "00100111",   -- 0x72 : 0x27
    "00100111",   -- 0x73 : 0x27
    "00101000",   -- 0x74 : 0x28
    "00101000",   -- 0x75 : 0x28
    "00101000",   -- 0x76 : 0x28
    "00101001",   -- 0x77 : 0x29
    "00101001",   -- 0x78 : 0x29
    "00101001",   -- 0x79 : 0x29
    "00101010",   -- 0x7A : 0x2A
    "00101010",   -- 0x7B : 0x2A
    "00101010",   -- 0x7C : 0x2A
    "00101011",   -- 0x7D : 0x2B
    "00101011",   -- 0x7E : 0x2B
    "00101011",   -- 0x7F : 0x2B
    "00101100",   -- 0x80 : 0x2C
    "00101100",   -- 0x81 : 0x2C
    "00101100",   -- 0x82 : 0x2C
    "00101101",   -- 0x83 : 0x2D
    "00101101",   -- 0x84 : 0x2D
    "00101101",   -- 0x85 : 0x2D
    "00101110",   -- 0x86 : 0x2E
    "00101110",   -- 0x87 : 0x2E
    "00101110",   -- 0x88 : 0x2E
    "00101111",   -- 0x89 : 0x2F
    "00101111",   -- 0x8A : 0x2F
    "00101111",   -- 0x8B : 0x2F
    "00101111",   -- 0x8C : 0x2F
    "00110000",   -- 0x8D : 0x30
    "00110000",   -- 0x8E : 0x30
    "00110000",   -- 0x8F : 0x30
    "00110001",   -- 0x90 : 0x31
    "00110001",   -- 0x91 : 0x31
    "00110001",   -- 0x92 : 0x31
    "00110010",   -- 0x93 : 0x32
    "00110010",   -- 0x94 : 0x32
    "00110010",   -- 0x95 : 0x32
    "00110011",   -- 0x96 : 0x33
    "00110011",   -- 0x97 : 0x33
    "00110011",   -- 0x98 : 0x33
    "00110100",   -- 0x99 : 0x34
    "00110100",   -- 0x9A : 0x34
    "00110100",   -- 0x9B : 0x34
    "00110101",   -- 0x9C : 0x35
    "00110101",   -- 0x9D : 0x35
    "00110101",   -- 0x9E : 0x35
    "00110101",   -- 0x9F : 0x35
    "00110110",   -- 0xA0 : 0x36
    "00110110",   -- 0xA1 : 0x36
    "00110110",   -- 0xA2 : 0x36
    "00110111",   -- 0xA3 : 0x37
    "00110111",   -- 0xA4 : 0x37
    "00110111",   -- 0xA5 : 0x37
    "00111000",   -- 0xA6 : 0x38
    "00111000",   -- 0xA7 : 0x38
    "00111000",   -- 0xA8 : 0x38
    "00111001",   -- 0xA9 : 0x39
    "00111001",   -- 0xAA : 0x39
    "00111001",   -- 0xAB : 0x39
    "00111001",   -- 0xAC : 0x39
    "00111010",   -- 0xAD : 0x3A
    "00111010",   -- 0xAE : 0x3A
    "00111010",   -- 0xAF : 0x3A
    "00111011",   -- 0xB0 : 0x3B
    "00111011",   -- 0xB1 : 0x3B
    "00111011",   -- 0xB2 : 0x3B
    "00111100",   -- 0xB3 : 0x3C
    "00111100",   -- 0xB4 : 0x3C
    "00111100",   -- 0xB5 : 0x3C
    "00111101",   -- 0xB6 : 0x3D
    "00111101",   -- 0xB7 : 0x3D
    "00111101",   -- 0xB8 : 0x3D
    "00111101",   -- 0xB9 : 0x3D
    "00111110",   -- 0xBA : 0x3E
    "00111110",   -- 0xBB : 0x3E
    "00111110",   -- 0xBC : 0x3E
    "00111111",   -- 0xBD : 0x3F
    "00111111",   -- 0xBE : 0x3F
    "00111111",   -- 0xBF : 0x3F
    "01000000",   -- 0xC0 : 0x40
    "01000000",   -- 0xC1 : 0x40
    "01000000",   -- 0xC2 : 0x40
    "01000001",   -- 0xC3 : 0x41
    "01000001",   -- 0xC4 : 0x41
    "01000001",   -- 0xC5 : 0x41
    "01000001",   -- 0xC6 : 0x41
    "01000010",   -- 0xC7 : 0x42
    "01000010",   -- 0xC8 : 0x42
    "01000010",   -- 0xC9 : 0x42
    "01000011",   -- 0xCA : 0x43
    "01000011",   -- 0xCB : 0x43
    "01000011",   -- 0xCC : 0x43
    "01000100",   -- 0xCD : 0x44
    "01000100",   -- 0xCE : 0x44
    "01000100",   -- 0xCF : 0x44
    "01000100",   -- 0xD0 : 0x44
    "01000101",   -- 0xD1 : 0x45
    "01000101",   -- 0xD2 : 0x45
    "01000101",   -- 0xD3 : 0x45
    "01000110",   -- 0xD4 : 0x46
    "01000110",   -- 0xD5 : 0x46
    "01000110",   -- 0xD6 : 0x46
    "01000111",   -- 0xD7 : 0x47
    "01000111",   -- 0xD8 : 0x47
    "01000111",   -- 0xD9 : 0x47
    "01000111",   -- 0xDA : 0x47
    "01001000",   -- 0xDB : 0x48
    "01001000",   -- 0xDC : 0x48
    "01001000",   -- 0xDD : 0x48
    "01001001",   -- 0xDE : 0x49
    "01001001",   -- 0xDF : 0x49
    "01001001",   -- 0xE0 : 0x49
    "01001010",   -- 0xE1 : 0x4A
    "01001010",   -- 0xE2 : 0x4A
    "01001010",   -- 0xE3 : 0x4A
    "01001010",   -- 0xE4 : 0x4A
    "01001011",   -- 0xE5 : 0x4B
    "01001011",   -- 0xE6 : 0x4B
    "01001011",   -- 0xE7 : 0x4B
    "01001100",   -- 0xE8 : 0x4C
    "01001100",   -- 0xE9 : 0x4C
    "01001100",   -- 0xEA : 0x4C
    "01001100",   -- 0xEB : 0x4C
    "01001101",   -- 0xEC : 0x4D
    "01001101",   -- 0xED : 0x4D
    "01001101",   -- 0xEE : 0x4D
    "01001110",   -- 0xEF : 0x4E
    "01001110",   -- 0xF0 : 0x4E
    "01001110",   -- 0xF1 : 0x4E
    "01001110",   -- 0xF2 : 0x4E
    "01001111",   -- 0xF3 : 0x4F
    "01001111",   -- 0xF4 : 0x4F
    "01001111",   -- 0xF5 : 0x4F
    "01010000",   -- 0xF6 : 0x50
    "01010000",   -- 0xF7 : 0x50
    "01010000",   -- 0xF8 : 0x50
    "01010001",   -- 0xF9 : 0x51
    "01010001",   -- 0xFA : 0x51
    "01010001",   -- 0xFB : 0x51
    "01010001",   -- 0xFC : 0x51
    "01010010",   -- 0xFD : 0x52
    "01010010",   -- 0xFE : 0x52
    "01010010",   -- 0xFF : 0x52
    "01010011",   -- 0x100 : 0x53
    "01010011",   -- 0x101 : 0x53
    "01010011",   -- 0x102 : 0x53
    "01010011",   -- 0x103 : 0x53
    "01010100",   -- 0x104 : 0x54
    "01010100",   -- 0x105 : 0x54
    "01010100",   -- 0x106 : 0x54
    "01010101",   -- 0x107 : 0x55
    "01010101",   -- 0x108 : 0x55
    "01010101",   -- 0x109 : 0x55
    "01010101",   -- 0x10A : 0x55
    "01010110",   -- 0x10B : 0x56
    "01010110",   -- 0x10C : 0x56
    "01010110",   -- 0x10D : 0x56
    "01010111",   -- 0x10E : 0x57
    "01010111",   -- 0x10F : 0x57
    "01010111",   -- 0x110 : 0x57
    "01010111",   -- 0x111 : 0x57
    "01011000",   -- 0x112 : 0x58
    "01011000",   -- 0x113 : 0x58
    "01011000",   -- 0x114 : 0x58
    "01011001",   -- 0x115 : 0x59
    "01011001",   -- 0x116 : 0x59
    "01011001",   -- 0x117 : 0x59
    "01011001",   -- 0x118 : 0x59
    "01011010",   -- 0x119 : 0x5A
    "01011010",   -- 0x11A : 0x5A
    "01011010",   -- 0x11B : 0x5A
    "01011011",   -- 0x11C : 0x5B
    "01011011",   -- 0x11D : 0x5B
    "01011011",   -- 0x11E : 0x5B
    "01011011",   -- 0x11F : 0x5B
    "01011100",   -- 0x120 : 0x5C
    "01011100",   -- 0x121 : 0x5C
    "01011100",   -- 0x122 : 0x5C
    "01011101",   -- 0x123 : 0x5D
    "01011101",   -- 0x124 : 0x5D
    "01011101",   -- 0x125 : 0x5D
    "01011101",   -- 0x126 : 0x5D
    "01011110",   -- 0x127 : 0x5E
    "01011110",   -- 0x128 : 0x5E
    "01011110",   -- 0x129 : 0x5E
    "01011110",   -- 0x12A : 0x5E
    "01011111",   -- 0x12B : 0x5F
    "01011111",   -- 0x12C : 0x5F
    "01011111",   -- 0x12D : 0x5F
    "01100000",   -- 0x12E : 0x60
    "01100000",   -- 0x12F : 0x60
    "01100000",   -- 0x130 : 0x60
    "01100000",   -- 0x131 : 0x60
    "01100001",   -- 0x132 : 0x61
    "01100001",   -- 0x133 : 0x61
    "01100001",   -- 0x134 : 0x61
    "01100010",   -- 0x135 : 0x62
    "01100010",   -- 0x136 : 0x62
    "01100010",   -- 0x137 : 0x62
    "01100010",   -- 0x138 : 0x62
    "01100011",   -- 0x139 : 0x63
    "01100011",   -- 0x13A : 0x63
    "01100011",   -- 0x13B : 0x63
    "01100011",   -- 0x13C : 0x63
    "01100100",   -- 0x13D : 0x64
    "01100100",   -- 0x13E : 0x64
    "01100100",   -- 0x13F : 0x64
    "01100101",   -- 0x140 : 0x65
    "01100101",   -- 0x141 : 0x65
    "01100101",   -- 0x142 : 0x65
    "01100101",   -- 0x143 : 0x65
    "01100110",   -- 0x144 : 0x66
    "01100110",   -- 0x145 : 0x66
    "01100110",   -- 0x146 : 0x66
    "01100110",   -- 0x147 : 0x66
    "01100111",   -- 0x148 : 0x67
    "01100111",   -- 0x149 : 0x67
    "01100111",   -- 0x14A : 0x67
    "01101000",   -- 0x14B : 0x68
    "01101000",   -- 0x14C : 0x68
    "01101000",   -- 0x14D : 0x68
    "01101000",   -- 0x14E : 0x68
    "01101001",   -- 0x14F : 0x69
    "01101001",   -- 0x150 : 0x69
    "01101001",   -- 0x151 : 0x69
    "01101001",   -- 0x152 : 0x69
    "01101010",   -- 0x153 : 0x6A
    "01101010",   -- 0x154 : 0x6A
    "01101010",   -- 0x155 : 0x6A
    "01101011",   -- 0x156 : 0x6B
    "01101011",   -- 0x157 : 0x6B
    "01101011",   -- 0x158 : 0x6B
    "01101011",   -- 0x159 : 0x6B
    "01101100",   -- 0x15A : 0x6C
    "01101100",   -- 0x15B : 0x6C
    "01101100",   -- 0x15C : 0x6C
    "01101100",   -- 0x15D : 0x6C
    "01101101",   -- 0x15E : 0x6D
    "01101101",   -- 0x15F : 0x6D
    "01101101",   -- 0x160 : 0x6D
    "01101110",   -- 0x161 : 0x6E
    "01101110",   -- 0x162 : 0x6E
    "01101110",   -- 0x163 : 0x6E
    "01101110",   -- 0x164 : 0x6E
    "01101111",   -- 0x165 : 0x6F
    "01101111",   -- 0x166 : 0x6F
    "01101111",   -- 0x167 : 0x6F
    "01101111",   -- 0x168 : 0x6F
    "01110000",   -- 0x169 : 0x70
    "01110000",   -- 0x16A : 0x70
    "01110000",   -- 0x16B : 0x70
    "01110000",   -- 0x16C : 0x70
    "01110001",   -- 0x16D : 0x71
    "01110001",   -- 0x16E : 0x71
    "01110001",   -- 0x16F : 0x71
    "01110010",   -- 0x170 : 0x72
    "01110010",   -- 0x171 : 0x72
    "01110010",   -- 0x172 : 0x72
    "01110010",   -- 0x173 : 0x72
    "01110011",   -- 0x174 : 0x73
    "01110011",   -- 0x175 : 0x73
    "01110011",   -- 0x176 : 0x73
    "01110011",   -- 0x177 : 0x73
    "01110100",   -- 0x178 : 0x74
    "01110100",   -- 0x179 : 0x74
    "01110100",   -- 0x17A : 0x74
    "01110100",   -- 0x17B : 0x74
    "01110101",   -- 0x17C : 0x75
    "01110101",   -- 0x17D : 0x75
    "01110101",   -- 0x17E : 0x75
    "01110101",   -- 0x17F : 0x75
    "01110110",   -- 0x180 : 0x76
    "01110110",   -- 0x181 : 0x76
    "01110110",   -- 0x182 : 0x76
    "01110111",   -- 0x183 : 0x77
    "01110111",   -- 0x184 : 0x77
    "01110111",   -- 0x185 : 0x77
    "01110111",   -- 0x186 : 0x77
    "01111000",   -- 0x187 : 0x78
    "01111000",   -- 0x188 : 0x78
    "01111000",   -- 0x189 : 0x78
    "01111000",   -- 0x18A : 0x78
    "01111001",   -- 0x18B : 0x79
    "01111001",   -- 0x18C : 0x79
    "01111001",   -- 0x18D : 0x79
    "01111001",   -- 0x18E : 0x79
    "01111010",   -- 0x18F : 0x7A
    "01111010",   -- 0x190 : 0x7A
    "01111010",   -- 0x191 : 0x7A
    "01111010",   -- 0x192 : 0x7A
    "01111011",   -- 0x193 : 0x7B
    "01111011",   -- 0x194 : 0x7B
    "01111011",   -- 0x195 : 0x7B
    "01111011",   -- 0x196 : 0x7B
    "01111100",   -- 0x197 : 0x7C
    "01111100",   -- 0x198 : 0x7C
    "01111100",   -- 0x199 : 0x7C
    "01111101",   -- 0x19A : 0x7D
    "01111101",   -- 0x19B : 0x7D
    "01111101",   -- 0x19C : 0x7D
    "01111101",   -- 0x19D : 0x7D
    "01111110",   -- 0x19E : 0x7E
    "01111110",   -- 0x19F : 0x7E
    "01111110",   -- 0x1A0 : 0x7E
    "01111110",   -- 0x1A1 : 0x7E
    "01111111",   -- 0x1A2 : 0x7F
    "01111111",   -- 0x1A3 : 0x7F
    "01111111",   -- 0x1A4 : 0x7F
    "01111111",   -- 0x1A5 : 0x7F
    "10000000",   -- 0x1A6 : 0x80
    "10000000",   -- 0x1A7 : 0x80
    "10000000",   -- 0x1A8 : 0x80
    "10000000",   -- 0x1A9 : 0x80
    "10000001",   -- 0x1AA : 0x81
    "10000001",   -- 0x1AB : 0x81
    "10000001",   -- 0x1AC : 0x81
    "10000001",   -- 0x1AD : 0x81
    "10000010",   -- 0x1AE : 0x82
    "10000010",   -- 0x1AF : 0x82
    "10000010",   -- 0x1B0 : 0x82
    "10000010",   -- 0x1B1 : 0x82
    "10000011",   -- 0x1B2 : 0x83
    "10000011",   -- 0x1B3 : 0x83
    "10000011",   -- 0x1B4 : 0x83
    "10000011",   -- 0x1B5 : 0x83
    "10000100",   -- 0x1B6 : 0x84
    "10000100",   -- 0x1B7 : 0x84
    "10000100",   -- 0x1B8 : 0x84
    "10000100",   -- 0x1B9 : 0x84
    "10000101",   -- 0x1BA : 0x85
    "10000101",   -- 0x1BB : 0x85
    "10000101",   -- 0x1BC : 0x85
    "10000101",   -- 0x1BD : 0x85
    "10000110",   -- 0x1BE : 0x86
    "10000110",   -- 0x1BF : 0x86
    "10000110",   -- 0x1C0 : 0x86
    "10000110",   -- 0x1C1 : 0x86
    "10000111",   -- 0x1C2 : 0x87
    "10000111",   -- 0x1C3 : 0x87
    "10000111",   -- 0x1C4 : 0x87
    "10000111",   -- 0x1C5 : 0x87
    "10001000",   -- 0x1C6 : 0x88
    "10001000",   -- 0x1C7 : 0x88
    "10001000",   -- 0x1C8 : 0x88
    "10001000",   -- 0x1C9 : 0x88
    "10001001",   -- 0x1CA : 0x89
    "10001001",   -- 0x1CB : 0x89
    "10001001",   -- 0x1CC : 0x89
    "10001001",   -- 0x1CD : 0x89
    "10001010",   -- 0x1CE : 0x8A
    "10001010",   -- 0x1CF : 0x8A
    "10001010",   -- 0x1D0 : 0x8A
    "10001010",   -- 0x1D1 : 0x8A
    "10001011",   -- 0x1D2 : 0x8B
    "10001011",   -- 0x1D3 : 0x8B
    "10001011",   -- 0x1D4 : 0x8B
    "10001011",   -- 0x1D5 : 0x8B
    "10001100",   -- 0x1D6 : 0x8C
    "10001100",   -- 0x1D7 : 0x8C
    "10001100",   -- 0x1D8 : 0x8C
    "10001100",   -- 0x1D9 : 0x8C
    "10001101",   -- 0x1DA : 0x8D
    "10001101",   -- 0x1DB : 0x8D
    "10001101",   -- 0x1DC : 0x8D
    "10001101",   -- 0x1DD : 0x8D
    "10001110",   -- 0x1DE : 0x8E
    "10001110",   -- 0x1DF : 0x8E
    "10001110",   -- 0x1E0 : 0x8E
    "10001110",   -- 0x1E1 : 0x8E
    "10001111",   -- 0x1E2 : 0x8F
    "10001111",   -- 0x1E3 : 0x8F
    "10001111",   -- 0x1E4 : 0x8F
    "10001111",   -- 0x1E5 : 0x8F
    "10010000",   -- 0x1E6 : 0x90
    "10010000",   -- 0x1E7 : 0x90
    "10010000",   -- 0x1E8 : 0x90
    "10010000",   -- 0x1E9 : 0x90
    "10010001",   -- 0x1EA : 0x91
    "10010001",   -- 0x1EB : 0x91
    "10010001",   -- 0x1EC : 0x91
    "10010001",   -- 0x1ED : 0x91
    "10010010",   -- 0x1EE : 0x92
    "10010010",   -- 0x1EF : 0x92
    "10010010",   -- 0x1F0 : 0x92
    "10010010",   -- 0x1F1 : 0x92
    "10010010",   -- 0x1F2 : 0x92
    "10010011",   -- 0x1F3 : 0x93
    "10010011",   -- 0x1F4 : 0x93
    "10010011",   -- 0x1F5 : 0x93
    "10010011",   -- 0x1F6 : 0x93
    "10010100",   -- 0x1F7 : 0x94
    "10010100",   -- 0x1F8 : 0x94
    "10010100",   -- 0x1F9 : 0x94
    "10010100",   -- 0x1FA : 0x94
    "10010101",   -- 0x1FB : 0x95
    "10010101",   -- 0x1FC : 0x95
    "10010101",   -- 0x1FD : 0x95
    "10010101",   -- 0x1FE : 0x95
    "10010110",   -- 0x1FF : 0x96
    "10010110",   -- 0x200 : 0x96
    "10010110",   -- 0x201 : 0x96
    "10010110",   -- 0x202 : 0x96
    "10010111",   -- 0x203 : 0x97
    "10010111",   -- 0x204 : 0x97
    "10010111",   -- 0x205 : 0x97
    "10010111",   -- 0x206 : 0x97
    "10011000",   -- 0x207 : 0x98
    "10011000",   -- 0x208 : 0x98
    "10011000",   -- 0x209 : 0x98
    "10011000",   -- 0x20A : 0x98
    "10011001",   -- 0x20B : 0x99
    "10011001",   -- 0x20C : 0x99
    "10011001",   -- 0x20D : 0x99
    "10011001",   -- 0x20E : 0x99
    "10011001",   -- 0x20F : 0x99
    "10011010",   -- 0x210 : 0x9A
    "10011010",   -- 0x211 : 0x9A
    "10011010",   -- 0x212 : 0x9A
    "10011010",   -- 0x213 : 0x9A
    "10011011",   -- 0x214 : 0x9B
    "10011011",   -- 0x215 : 0x9B
    "10011011",   -- 0x216 : 0x9B
    "10011011",   -- 0x217 : 0x9B
    "10011100",   -- 0x218 : 0x9C
    "10011100",   -- 0x219 : 0x9C
    "10011100",   -- 0x21A : 0x9C
    "10011100",   -- 0x21B : 0x9C
    "10011101",   -- 0x21C : 0x9D
    "10011101",   -- 0x21D : 0x9D
    "10011101",   -- 0x21E : 0x9D
    "10011101",   -- 0x21F : 0x9D
    "10011101",   -- 0x220 : 0x9D
    "10011110",   -- 0x221 : 0x9E
    "10011110",   -- 0x222 : 0x9E
    "10011110",   -- 0x223 : 0x9E
    "10011110",   -- 0x224 : 0x9E
    "10011111",   -- 0x225 : 0x9F
    "10011111",   -- 0x226 : 0x9F
    "10011111",   -- 0x227 : 0x9F
    "10011111",   -- 0x228 : 0x9F
    "10100000",   -- 0x229 : 0xA0
    "10100000",   -- 0x22A : 0xA0
    "10100000",   -- 0x22B : 0xA0
    "10100000",   -- 0x22C : 0xA0
    "10100001",   -- 0x22D : 0xA1
    "10100001",   -- 0x22E : 0xA1
    "10100001",   -- 0x22F : 0xA1
    "10100001",   -- 0x230 : 0xA1
    "10100001",   -- 0x231 : 0xA1
    "10100010",   -- 0x232 : 0xA2
    "10100010",   -- 0x233 : 0xA2
    "10100010",   -- 0x234 : 0xA2
    "10100010",   -- 0x235 : 0xA2
    "10100011",   -- 0x236 : 0xA3
    "10100011",   -- 0x237 : 0xA3
    "10100011",   -- 0x238 : 0xA3
    "10100011",   -- 0x239 : 0xA3
    "10100100",   -- 0x23A : 0xA4
    "10100100",   -- 0x23B : 0xA4
    "10100100",   -- 0x23C : 0xA4
    "10100100",   -- 0x23D : 0xA4
    "10100100",   -- 0x23E : 0xA4
    "10100101",   -- 0x23F : 0xA5
    "10100101",   -- 0x240 : 0xA5
    "10100101",   -- 0x241 : 0xA5
    "10100101",   -- 0x242 : 0xA5
    "10100110",   -- 0x243 : 0xA6
    "10100110",   -- 0x244 : 0xA6
    "10100110",   -- 0x245 : 0xA6
    "10100110",   -- 0x246 : 0xA6
    "10100111",   -- 0x247 : 0xA7
    "10100111",   -- 0x248 : 0xA7
    "10100111",   -- 0x249 : 0xA7
    "10100111",   -- 0x24A : 0xA7
    "10100111",   -- 0x24B : 0xA7
    "10101000",   -- 0x24C : 0xA8
    "10101000",   -- 0x24D : 0xA8
    "10101000",   -- 0x24E : 0xA8
    "10101000",   -- 0x24F : 0xA8
    "10101001",   -- 0x250 : 0xA9
    "10101001",   -- 0x251 : 0xA9
    "10101001",   -- 0x252 : 0xA9
    "10101001",   -- 0x253 : 0xA9
    "10101010",   -- 0x254 : 0xAA
    "10101010",   -- 0x255 : 0xAA
    "10101010",   -- 0x256 : 0xAA
    "10101010",   -- 0x257 : 0xAA
    "10101010",   -- 0x258 : 0xAA
    "10101011",   -- 0x259 : 0xAB
    "10101011",   -- 0x25A : 0xAB
    "10101011",   -- 0x25B : 0xAB
    "10101011",   -- 0x25C : 0xAB
    "10101100",   -- 0x25D : 0xAC
    "10101100",   -- 0x25E : 0xAC
    "10101100",   -- 0x25F : 0xAC
    "10101100",   -- 0x260 : 0xAC
    "10101100",   -- 0x261 : 0xAC
    "10101101",   -- 0x262 : 0xAD
    "10101101",   -- 0x263 : 0xAD
    "10101101",   -- 0x264 : 0xAD
    "10101101",   -- 0x265 : 0xAD
    "10101110",   -- 0x266 : 0xAE
    "10101110",   -- 0x267 : 0xAE
    "10101110",   -- 0x268 : 0xAE
    "10101110",   -- 0x269 : 0xAE
    "10101111",   -- 0x26A : 0xAF
    "10101111",   -- 0x26B : 0xAF
    "10101111",   -- 0x26C : 0xAF
    "10101111",   -- 0x26D : 0xAF
    "10101111",   -- 0x26E : 0xAF
    "10110000",   -- 0x26F : 0xB0
    "10110000",   -- 0x270 : 0xB0
    "10110000",   -- 0x271 : 0xB0
    "10110000",   -- 0x272 : 0xB0
    "10110001",   -- 0x273 : 0xB1
    "10110001",   -- 0x274 : 0xB1
    "10110001",   -- 0x275 : 0xB1
    "10110001",   -- 0x276 : 0xB1
    "10110001",   -- 0x277 : 0xB1
    "10110010",   -- 0x278 : 0xB2
    "10110010",   -- 0x279 : 0xB2
    "10110010",   -- 0x27A : 0xB2
    "10110010",   -- 0x27B : 0xB2
    "10110011",   -- 0x27C : 0xB3
    "10110011",   -- 0x27D : 0xB3
    "10110011",   -- 0x27E : 0xB3
    "10110011",   -- 0x27F : 0xB3
    "10110011",   -- 0x280 : 0xB3
    "10110100",   -- 0x281 : 0xB4
    "10110100",   -- 0x282 : 0xB4
    "10110100",   -- 0x283 : 0xB4
    "10110100",   -- 0x284 : 0xB4
    "10110101",   -- 0x285 : 0xB5
    "10110101",   -- 0x286 : 0xB5
    "10110101",   -- 0x287 : 0xB5
    "10110101",   -- 0x288 : 0xB5
    "10110101",   -- 0x289 : 0xB5
    "10110110",   -- 0x28A : 0xB6
    "10110110",   -- 0x28B : 0xB6
    "10110110",   -- 0x28C : 0xB6
    "10110110",   -- 0x28D : 0xB6
    "10110111",   -- 0x28E : 0xB7
    "10110111",   -- 0x28F : 0xB7
    "10110111",   -- 0x290 : 0xB7
    "10110111",   -- 0x291 : 0xB7
    "10110111",   -- 0x292 : 0xB7
    "10111000",   -- 0x293 : 0xB8
    "10111000",   -- 0x294 : 0xB8
    "10111000",   -- 0x295 : 0xB8
    "10111000",   -- 0x296 : 0xB8
    "10111000",   -- 0x297 : 0xB8
    "10111001",   -- 0x298 : 0xB9
    "10111001",   -- 0x299 : 0xB9
    "10111001",   -- 0x29A : 0xB9
    "10111001",   -- 0x29B : 0xB9
    "10111010",   -- 0x29C : 0xBA
    "10111010",   -- 0x29D : 0xBA
    "10111010",   -- 0x29E : 0xBA
    "10111010",   -- 0x29F : 0xBA
    "10111010",   -- 0x2A0 : 0xBA
    "10111011",   -- 0x2A1 : 0xBB
    "10111011",   -- 0x2A2 : 0xBB
    "10111011",   -- 0x2A3 : 0xBB
    "10111011",   -- 0x2A4 : 0xBB
    "10111100",   -- 0x2A5 : 0xBC
    "10111100",   -- 0x2A6 : 0xBC
    "10111100",   -- 0x2A7 : 0xBC
    "10111100",   -- 0x2A8 : 0xBC
    "10111100",   -- 0x2A9 : 0xBC
    "10111101",   -- 0x2AA : 0xBD
    "10111101",   -- 0x2AB : 0xBD
    "10111101",   -- 0x2AC : 0xBD
    "10111101",   -- 0x2AD : 0xBD
    "10111101",   -- 0x2AE : 0xBD
    "10111110",   -- 0x2AF : 0xBE
    "10111110",   -- 0x2B0 : 0xBE
    "10111110",   -- 0x2B1 : 0xBE
    "10111110",   -- 0x2B2 : 0xBE
    "10111111",   -- 0x2B3 : 0xBF
    "10111111",   -- 0x2B4 : 0xBF
    "10111111",   -- 0x2B5 : 0xBF
    "10111111",   -- 0x2B6 : 0xBF
    "10111111",   -- 0x2B7 : 0xBF
    "11000000",   -- 0x2B8 : 0xC0
    "11000000",   -- 0x2B9 : 0xC0
    "11000000",   -- 0x2BA : 0xC0
    "11000000",   -- 0x2BB : 0xC0
    "11000001",   -- 0x2BC : 0xC1
    "11000001",   -- 0x2BD : 0xC1
    "11000001",   -- 0x2BE : 0xC1
    "11000001",   -- 0x2BF : 0xC1
    "11000001",   -- 0x2C0 : 0xC1
    "11000010",   -- 0x2C1 : 0xC2
    "11000010",   -- 0x2C2 : 0xC2
    "11000010",   -- 0x2C3 : 0xC2
    "11000010",   -- 0x2C4 : 0xC2
    "11000010",   -- 0x2C5 : 0xC2
    "11000011",   -- 0x2C6 : 0xC3
    "11000011",   -- 0x2C7 : 0xC3
    "11000011",   -- 0x2C8 : 0xC3
    "11000011",   -- 0x2C9 : 0xC3
    "11000011",   -- 0x2CA : 0xC3
    "11000100",   -- 0x2CB : 0xC4
    "11000100",   -- 0x2CC : 0xC4
    "11000100",   -- 0x2CD : 0xC4
    "11000100",   -- 0x2CE : 0xC4
    "11000101",   -- 0x2CF : 0xC5
    "11000101",   -- 0x2D0 : 0xC5
    "11000101",   -- 0x2D1 : 0xC5
    "11000101",   -- 0x2D2 : 0xC5
    "11000101",   -- 0x2D3 : 0xC5
    "11000110",   -- 0x2D4 : 0xC6
    "11000110",   -- 0x2D5 : 0xC6
    "11000110",   -- 0x2D6 : 0xC6
    "11000110",   -- 0x2D7 : 0xC6
    "11000110",   -- 0x2D8 : 0xC6
    "11000111",   -- 0x2D9 : 0xC7
    "11000111",   -- 0x2DA : 0xC7
    "11000111",   -- 0x2DB : 0xC7
    "11000111",   -- 0x2DC : 0xC7
    "11001000",   -- 0x2DD : 0xC8
    "11001000",   -- 0x2DE : 0xC8
    "11001000",   -- 0x2DF : 0xC8
    "11001000",   -- 0x2E0 : 0xC8
    "11001000",   -- 0x2E1 : 0xC8
    "11001001",   -- 0x2E2 : 0xC9
    "11001001",   -- 0x2E3 : 0xC9
    "11001001",   -- 0x2E4 : 0xC9
    "11001001",   -- 0x2E5 : 0xC9
    "11001001",   -- 0x2E6 : 0xC9
    "11001010",   -- 0x2E7 : 0xCA
    "11001010",   -- 0x2E8 : 0xCA
    "11001010",   -- 0x2E9 : 0xCA
    "11001010",   -- 0x2EA : 0xCA
    "11001010",   -- 0x2EB : 0xCA
    "11001011",   -- 0x2EC : 0xCB
    "11001011",   -- 0x2ED : 0xCB
    "11001011",   -- 0x2EE : 0xCB
    "11001011",   -- 0x2EF : 0xCB
    "11001011",   -- 0x2F0 : 0xCB
    "11001100",   -- 0x2F1 : 0xCC
    "11001100",   -- 0x2F2 : 0xCC
    "11001100",   -- 0x2F3 : 0xCC
    "11001100",   -- 0x2F4 : 0xCC
    "11001101",   -- 0x2F5 : 0xCD
    "11001101",   -- 0x2F6 : 0xCD
    "11001101",   -- 0x2F7 : 0xCD
    "11001101",   -- 0x2F8 : 0xCD
    "11001101",   -- 0x2F9 : 0xCD
    "11001110",   -- 0x2FA : 0xCE
    "11001110",   -- 0x2FB : 0xCE
    "11001110",   -- 0x2FC : 0xCE
    "11001110",   -- 0x2FD : 0xCE
    "11001110",   -- 0x2FE : 0xCE
    "11001111",   -- 0x2FF : 0xCF
    "11001111",   -- 0x300 : 0xCF
    "11001111",   -- 0x301 : 0xCF
    "11001111",   -- 0x302 : 0xCF
    "11001111",   -- 0x303 : 0xCF
    "11010000",   -- 0x304 : 0xD0
    "11010000",   -- 0x305 : 0xD0
    "11010000",   -- 0x306 : 0xD0
    "11010000",   -- 0x307 : 0xD0
    "11010000",   -- 0x308 : 0xD0
    "11010001",   -- 0x309 : 0xD1
    "11010001",   -- 0x30A : 0xD1
    "11010001",   -- 0x30B : 0xD1
    "11010001",   -- 0x30C : 0xD1
    "11010001",   -- 0x30D : 0xD1
    "11010010",   -- 0x30E : 0xD2
    "11010010",   -- 0x30F : 0xD2
    "11010010",   -- 0x310 : 0xD2
    "11010010",   -- 0x311 : 0xD2
    "11010010",   -- 0x312 : 0xD2
    "11010011",   -- 0x313 : 0xD3
    "11010011",   -- 0x314 : 0xD3
    "11010011",   -- 0x315 : 0xD3
    "11010011",   -- 0x316 : 0xD3
    "11010011",   -- 0x317 : 0xD3
    "11010100",   -- 0x318 : 0xD4
    "11010100",   -- 0x319 : 0xD4
    "11010100",   -- 0x31A : 0xD4
    "11010100",   -- 0x31B : 0xD4
    "11010101",   -- 0x31C : 0xD5
    "11010101",   -- 0x31D : 0xD5
    "11010101",   -- 0x31E : 0xD5
    "11010101",   -- 0x31F : 0xD5
    "11010101",   -- 0x320 : 0xD5
    "11010110",   -- 0x321 : 0xD6
    "11010110",   -- 0x322 : 0xD6
    "11010110",   -- 0x323 : 0xD6
    "11010110",   -- 0x324 : 0xD6
    "11010110",   -- 0x325 : 0xD6
    "11010111",   -- 0x326 : 0xD7
    "11010111",   -- 0x327 : 0xD7
    "11010111",   -- 0x328 : 0xD7
    "11010111",   -- 0x329 : 0xD7
    "11010111",   -- 0x32A : 0xD7
    "11011000",   -- 0x32B : 0xD8
    "11011000",   -- 0x32C : 0xD8
    "11011000",   -- 0x32D : 0xD8
    "11011000",   -- 0x32E : 0xD8
    "11011000",   -- 0x32F : 0xD8
    "11011001",   -- 0x330 : 0xD9
    "11011001",   -- 0x331 : 0xD9
    "11011001",   -- 0x332 : 0xD9
    "11011001",   -- 0x333 : 0xD9
    "11011001",   -- 0x334 : 0xD9
    "11011010",   -- 0x335 : 0xDA
    "11011010",   -- 0x336 : 0xDA
    "11011010",   -- 0x337 : 0xDA
    "11011010",   -- 0x338 : 0xDA
    "11011010",   -- 0x339 : 0xDA
    "11011011",   -- 0x33A : 0xDB
    "11011011",   -- 0x33B : 0xDB
    "11011011",   -- 0x33C : 0xDB
    "11011011",   -- 0x33D : 0xDB
    "11011011",   -- 0x33E : 0xDB
    "11011100",   -- 0x33F : 0xDC
    "11011100",   -- 0x340 : 0xDC
    "11011100",   -- 0x341 : 0xDC
    "11011100",   -- 0x342 : 0xDC
    "11011100",   -- 0x343 : 0xDC
    "11011101",   -- 0x344 : 0xDD
    "11011101",   -- 0x345 : 0xDD
    "11011101",   -- 0x346 : 0xDD
    "11011101",   -- 0x347 : 0xDD
    "11011101",   -- 0x348 : 0xDD
    "11011110",   -- 0x349 : 0xDE
    "11011110",   -- 0x34A : 0xDE
    "11011110",   -- 0x34B : 0xDE
    "11011110",   -- 0x34C : 0xDE
    "11011110",   -- 0x34D : 0xDE
    "11011111",   -- 0x34E : 0xDF
    "11011111",   -- 0x34F : 0xDF
    "11011111",   -- 0x350 : 0xDF
    "11011111",   -- 0x351 : 0xDF
    "11011111",   -- 0x352 : 0xDF
    "11100000",   -- 0x353 : 0xE0
    "11100000",   -- 0x354 : 0xE0
    "11100000",   -- 0x355 : 0xE0
    "11100000",   -- 0x356 : 0xE0
    "11100000",   -- 0x357 : 0xE0
    "11100000",   -- 0x358 : 0xE0
    "11100001",   -- 0x359 : 0xE1
    "11100001",   -- 0x35A : 0xE1
    "11100001",   -- 0x35B : 0xE1
    "11100001",   -- 0x35C : 0xE1
    "11100001",   -- 0x35D : 0xE1
    "11100010",   -- 0x35E : 0xE2
    "11100010",   -- 0x35F : 0xE2
    "11100010",   -- 0x360 : 0xE2
    "11100010",   -- 0x361 : 0xE2
    "11100010",   -- 0x362 : 0xE2
    "11100011",   -- 0x363 : 0xE3
    "11100011",   -- 0x364 : 0xE3
    "11100011",   -- 0x365 : 0xE3
    "11100011",   -- 0x366 : 0xE3
    "11100011",   -- 0x367 : 0xE3
    "11100100",   -- 0x368 : 0xE4
    "11100100",   -- 0x369 : 0xE4
    "11100100",   -- 0x36A : 0xE4
    "11100100",   -- 0x36B : 0xE4
    "11100100",   -- 0x36C : 0xE4
    "11100101",   -- 0x36D : 0xE5
    "11100101",   -- 0x36E : 0xE5
    "11100101",   -- 0x36F : 0xE5
    "11100101",   -- 0x370 : 0xE5
    "11100101",   -- 0x371 : 0xE5
    "11100110",   -- 0x372 : 0xE6
    "11100110",   -- 0x373 : 0xE6
    "11100110",   -- 0x374 : 0xE6
    "11100110",   -- 0x375 : 0xE6
    "11100110",   -- 0x376 : 0xE6
    "11100111",   -- 0x377 : 0xE7
    "11100111",   -- 0x378 : 0xE7
    "11100111",   -- 0x379 : 0xE7
    "11100111",   -- 0x37A : 0xE7
    "11100111",   -- 0x37B : 0xE7
    "11100111",   -- 0x37C : 0xE7
    "11101000",   -- 0x37D : 0xE8
    "11101000",   -- 0x37E : 0xE8
    "11101000",   -- 0x37F : 0xE8
    "11101000",   -- 0x380 : 0xE8
    "11101000",   -- 0x381 : 0xE8
    "11101001",   -- 0x382 : 0xE9
    "11101001",   -- 0x383 : 0xE9
    "11101001",   -- 0x384 : 0xE9
    "11101001",   -- 0x385 : 0xE9
    "11101001",   -- 0x386 : 0xE9
    "11101010",   -- 0x387 : 0xEA
    "11101010",   -- 0x388 : 0xEA
    "11101010",   -- 0x389 : 0xEA
    "11101010",   -- 0x38A : 0xEA
    "11101010",   -- 0x38B : 0xEA
    "11101011",   -- 0x38C : 0xEB
    "11101011",   -- 0x38D : 0xEB
    "11101011",   -- 0x38E : 0xEB
    "11101011",   -- 0x38F : 0xEB
    "11101011",   -- 0x390 : 0xEB
    "11101100",   -- 0x391 : 0xEC
    "11101100",   -- 0x392 : 0xEC
    "11101100",   -- 0x393 : 0xEC
    "11101100",   -- 0x394 : 0xEC
    "11101100",   -- 0x395 : 0xEC
    "11101100",   -- 0x396 : 0xEC
    "11101101",   -- 0x397 : 0xED
    "11101101",   -- 0x398 : 0xED
    "11101101",   -- 0x399 : 0xED
    "11101101",   -- 0x39A : 0xED
    "11101101",   -- 0x39B : 0xED
    "11101110",   -- 0x39C : 0xEE
    "11101110",   -- 0x39D : 0xEE
    "11101110",   -- 0x39E : 0xEE
    "11101110",   -- 0x39F : 0xEE
    "11101110",   -- 0x3A0 : 0xEE
    "11101111",   -- 0x3A1 : 0xEF
    "11101111",   -- 0x3A2 : 0xEF
    "11101111",   -- 0x3A3 : 0xEF
    "11101111",   -- 0x3A4 : 0xEF
    "11101111",   -- 0x3A5 : 0xEF
    "11101111",   -- 0x3A6 : 0xEF
    "11110000",   -- 0x3A7 : 0xF0
    "11110000",   -- 0x3A8 : 0xF0
    "11110000",   -- 0x3A9 : 0xF0
    "11110000",   -- 0x3AA : 0xF0
    "11110000",   -- 0x3AB : 0xF0
    "11110001",   -- 0x3AC : 0xF1
    "11110001",   -- 0x3AD : 0xF1
    "11110001",   -- 0x3AE : 0xF1
    "11110001",   -- 0x3AF : 0xF1
    "11110001",   -- 0x3B0 : 0xF1
    "11110010",   -- 0x3B1 : 0xF2
    "11110010",   -- 0x3B2 : 0xF2
    "11110010",   -- 0x3B3 : 0xF2
    "11110010",   -- 0x3B4 : 0xF2
    "11110010",   -- 0x3B5 : 0xF2
    "11110011",   -- 0x3B6 : 0xF3
    "11110011",   -- 0x3B7 : 0xF3
    "11110011",   -- 0x3B8 : 0xF3
    "11110011",   -- 0x3B9 : 0xF3
    "11110011",   -- 0x3BA : 0xF3
    "11110011",   -- 0x3BB : 0xF3
    "11110100",   -- 0x3BC : 0xF4
    "11110100",   -- 0x3BD : 0xF4
    "11110100",   -- 0x3BE : 0xF4
    "11110100",   -- 0x3BF : 0xF4
    "11110100",   -- 0x3C0 : 0xF4
    "11110101",   -- 0x3C1 : 0xF5
    "11110101",   -- 0x3C2 : 0xF5
    "11110101",   -- 0x3C3 : 0xF5
    "11110101",   -- 0x3C4 : 0xF5
    "11110101",   -- 0x3C5 : 0xF5
    "11110101",   -- 0x3C6 : 0xF5
    "11110110",   -- 0x3C7 : 0xF6
    "11110110",   -- 0x3C8 : 0xF6
    "11110110",   -- 0x3C9 : 0xF6
    "11110110",   -- 0x3CA : 0xF6
    "11110110",   -- 0x3CB : 0xF6
    "11110111",   -- 0x3CC : 0xF7
    "11110111",   -- 0x3CD : 0xF7
    "11110111",   -- 0x3CE : 0xF7
    "11110111",   -- 0x3CF : 0xF7
    "11110111",   -- 0x3D0 : 0xF7
    "11111000",   -- 0x3D1 : 0xF8
    "11111000",   -- 0x3D2 : 0xF8
    "11111000",   -- 0x3D3 : 0xF8
    "11111000",   -- 0x3D4 : 0xF8
    "11111000",   -- 0x3D5 : 0xF8
    "11111000",   -- 0x3D6 : 0xF8
    "11111001",   -- 0x3D7 : 0xF9
    "11111001",   -- 0x3D8 : 0xF9
    "11111001",   -- 0x3D9 : 0xF9
    "11111001",   -- 0x3DA : 0xF9
    "11111001",   -- 0x3DB : 0xF9
    "11111010",   -- 0x3DC : 0xFA
    "11111010",   -- 0x3DD : 0xFA
    "11111010",   -- 0x3DE : 0xFA
    "11111010",   -- 0x3DF : 0xFA
    "11111010",   -- 0x3E0 : 0xFA
    "11111010",   -- 0x3E1 : 0xFA
    "11111011",   -- 0x3E2 : 0xFB
    "11111011",   -- 0x3E3 : 0xFB
    "11111011",   -- 0x3E4 : 0xFB
    "11111011",   -- 0x3E5 : 0xFB
    "11111011",   -- 0x3E6 : 0xFB
    "11111100",   -- 0x3E7 : 0xFC
    "11111100",   -- 0x3E8 : 0xFC
    "11111100",   -- 0x3E9 : 0xFC
    "11111100",   -- 0x3EA : 0xFC
    "11111100",   -- 0x3EB : 0xFC
    "11111100",   -- 0x3EC : 0xFC
    "11111101",   -- 0x3ED : 0xFD
    "11111101",   -- 0x3EE : 0xFD
    "11111101",   -- 0x3EF : 0xFD
    "11111101",   -- 0x3F0 : 0xFD
    "11111101",   -- 0x3F1 : 0xFD
    "11111110",   -- 0x3F2 : 0xFE
    "11111110",   -- 0x3F3 : 0xFE
    "11111110",   -- 0x3F4 : 0xFE
    "11111110",   -- 0x3F5 : 0xFE
    "11111110",   -- 0x3F6 : 0xFE
    "11111110",   -- 0x3F7 : 0xFE
    "11111111",   -- 0x3F8 : 0xFF
    "11111111",   -- 0x3F9 : 0xFF
    "11111111",   -- 0x3FA : 0xFF
    "11111111",   -- 0x3FB : 0xFF
    "11111111",   -- 0x3FC : 0xFF
    "00000000",   -- 0x3FD : 0x0
    "00000000",   -- 0x3FE : 0x0
    "00000000");  -- 0x3FF : 0x0

begin
  process(clk) begin
    if(clk'event and clk='1') then
      outdata <= brom(CONV_INTEGER(indata));
    end if;
  end process;
end rtl;
                                                           
library ieee;                                              
use ieee.std_logic_1164.all;                               
                                                           
entity pg_log_shift_1 is                          
  generic (PG_WIDTH: integer);                             
  port( x : in std_logic_vector(PG_WIDTH-1 downto 0);      
	   y : out std_logic_vector(PG_WIDTH-1 downto 0);    
	   clk : in std_logic);                              
end pg_log_shift_1;                               
                                                           
architecture rtl of pg_log_shift_1 is             
                                                           
begin                                                      
                                                           
  y <= '0' & x(PG_WIDTH-2) & x(PG_WIDTH-4 downto 0) & '0';     
                                                           
end rtl;                                                   
-- P: 1[-], 2[O], 3[O], 4[-], 5[-], 6[O], 7[-], 8[-], 9[O], 
-- *************************************************************** 
-- * PGPG UNSIGNED LOGARITHMIC ADDER(INTERPOLATED) MODULE        * 
-- *  AUTHOR: Tsuyoshi Hamada                                    * 
-- *  VERSION: 1.03                                              * 
-- *  LAST MODIFIED AT Tue Mar 25 10:52:09 JST 2003              * 
-- *************************************************************** 
-- Nman	8-bit
-- Ncut	6-bit
-- Npipe	4
-- rom_c0(address)	6-bit
-- rom_c1(address)	6-bit
-- rom_c0(data)	10-bit
-- rom_c1(data)	9-bit

library ieee;
use ieee.std_logic_1164.all;

entity pg_log_unsigned_add_itp_17_8_6_4 is
  port( x,y : in std_logic_vector(16 downto 0);
        z : out std_logic_vector(16 downto 0);
        clock : in std_logic);
end pg_log_unsigned_add_itp_17_8_6_4;

architecture rtl of pg_log_unsigned_add_itp_17_8_6_4 is

  component pg_log_unsigned_add_umult_6_9_0
  port (
    clk : in std_logic; 
    x : in std_logic_vector(5 downto 0); 
    y : in std_logic_vector(8 downto 0); 
    z : out std_logic_vector(14 downto 0));
  end component;

-- This part has a bug potentially.
-- The MULTIPLE DECLARATION will be occure!!
-- But I don't have time to fix it today. (2004/02/19)
-- I will kill the bug for future.
-- If your VHDL code bumps this MULTIPLE DECLARATION error at synthesis,
-- Please contact me(hamada@provence.c.u-tokyo.ac.jp).
  -- u1 --
  component pg_adder_RCA_SUB_17_0
    port (x,y: in std_logic_vector(16 downto 0);
          clk: in std_logic;
          z: out std_logic_vector(16 downto 0));
  end component;

  -- u2 --
  component pg_adder_RCA_SUB_16_0
    port (x,y: in std_logic_vector(15 downto 0);
          clk: in std_logic;
          z: out std_logic_vector(15 downto 0));
  end component;

  -- itp_sub --
  component pg_adder_RCA_SUB_11_0
    port (x,y: in std_logic_vector(10 downto 0);
          clk: in std_logic;
          z: out std_logic_vector(10 downto 0));
  end component;

  -- u4 --
  component pg_adder_RCA_ADD_16_0
    port (x,y: in std_logic_vector(15 downto 0);
          clk: in std_logic;
          z: out std_logic_vector(15 downto 0));
  end component;

  component lcell_rom_a106_6_10_1
   port (indata: in std_logic_vector(5 downto 0);
         clk: in std_logic;
         outdata: out std_logic_vector(9 downto 0));
  end component;

  component lcell_rom_a906_6_9_1
   port (indata: in std_logic_vector(5 downto 0);
         clk: in std_logic;
         outdata: out std_logic_vector(8 downto 0));
  end component;


  signal x1,y1,xy : std_logic_vector(16 downto 0);
  signal yx : std_logic_vector(15 downto 0);
  signal xd,yd : std_logic_vector(15 downto 0);
  signal x2,x3,x4,x5,x6,x7,x8 : std_logic_vector(15 downto 0);
  signal d0,d1,d4 : std_logic_vector(15 downto 0);
  signal z0 : std_logic_vector(15 downto 0);
  signal sign0,sign1,sign2,sign3,sign4,sign5,sign6,sign7,sign8 : std_logic;
  signal signxy : std_logic_vector(1 downto 0);
  -- FOR TABLE SUB LOGIC
  signal df0,df1,df2,df3,df4,df5 : std_logic;
  signal d_isz0,d_isz1,d_isz2,d_isz3,d_isz4,d_isz5 : std_logic;
  signal d2 : std_logic_vector(8 downto 0);
  signal itp_x : std_logic_vector(5 downto 0);
  signal itp_dx0,itp_dx1 : std_logic_vector(5 downto 0);
  signal itp_c0,itp_c0d0,itp_c0d1,itp_c0d2 : std_logic_vector(9 downto 0);
  signal itp_c1 : std_logic_vector(8 downto 0);
  signal itp_c1dx : std_logic_vector(14 downto 0);
  signal itp_c1dx_shift : std_logic_vector(9 downto 0);
  signal itp_c1dx2: std_logic_vector(9 downto 0);
  signal itp_subx,itp_suby,itp_subz: std_logic_vector(10 downto 0);
  signal itp_c0_c1dx: std_logic_vector(7 downto 0);
  signal itp_out0,itp_out1: std_logic_vector(7 downto 0);

begin

  x1 <= '0' & x(15 downto 0);
  y1 <= '0' & y(15 downto 0);

  --- PIPELINE 1(OFF) ---
  u1: pg_adder_RCA_SUB_17_0  port map(x=>x1,y=>y1,z=>xy,clk=>clock);
  u2: pg_adder_RCA_SUB_16_0  port map(x=>y(15 downto 0),y=>x(15 downto 0),z=>yx,clk=>clock);
  xd <= x(15 downto 0);
  yd <= y(15 downto 0);
  sign1 <= sign0;
  ------------------.


  x2 <= xd when xy(16)='0' else yd;
  d0 <= xy(15 downto 0) when xy(16)='0' else yx;

  signxy <= x(16)&y(16);
  with signxy select
    sign0 <= y(16) when "01",
             x(16) when others;

  --- PIPELINE 2 ---
  process(clock) begin
    if(clock'event and clock='1') then
      x3 <= x2;
      d1 <= d0;
      sign2 <= sign1;
    end if;
  end process;
  ------------------.


-- TABLE PART (START) ---------------------------------------------
-- INPUT  d1 : 16-bit
-- OUTPUT d4 : 16-bit
  df0 <= '1' when d1(15 downto 12)="0000" else '0';
  
  -- ALL OR -> NOT (PLUS) --
  d_isz0 <= '1' when d1(11 downto 0)="000000000000" else '0';

-- TABLE (INTERPOLATION) --
-- *************************************************************** 
-- * PGPG UNSIGNED LOGARITHMIC ADDER MODULE OF                   * 
-- * INTERPORATED TABLE LOGIC : f(x+dx) ~= c0(x) + c1(x)dx       * 
-- *  c0(x) and c1(x) are chebyshev coefficients.                * 
-- *************************************************************** 
  itp_x   <= d1(11 downto 6);
  itp_dx0 <= d1(5 downto 0);

  --- PIPELINE 3 ---

  -- OUT REGISTERED TABLE --                          
  -- c0(x) --                                         
  itp_c0_rom: lcell_rom_a106_6_10_1
  port map(indata=>itp_x,outdata=>itp_c0,clk=>clock);

  -- c1(x) --                                         
  itp_c1_rom: lcell_rom_a906_6_9_1
  port map(indata=>itp_x,outdata=>itp_c1,clk=>clock);

  process(clock) begin
    if(clock'event and clock='1') then
      df1 <= df0;
      d_isz1 <= d_isz0;
      itp_dx1 <= itp_dx0;
    end if;
  end process;
  ------------------.


  --- PIPELINE 4,5 ---
  -- ITP MULT --  6-bit * 9-bit -> 15-bit
  itp_mult: pg_log_unsigned_add_umult_6_9_0
    port map (       
    clk  => clock,   
    x  => itp_dx1,   
    y  => itp_c1,    
    z  => itp_c1dx); 
  ------------------.
  --- PIPELINE 4(OFF) ---
  df2 <= df1;
  d_isz2 <= d_isz1;
  itp_c0d0 <= itp_c0;
  ------------------.
  --- PIPELINE 5(OFF) ---
  df3 <= df2;
  d_isz3 <= d_isz2;
  itp_c0d1 <= itp_c0d0;
  ------------------.


  -- SHIFT >> 8-bit , JOINE ZERO-VECTORS TO THE UPPER-BIT
  itp_c1dx_shift <= "000" & itp_c1dx(14 downto 8);

  --- PIPELINE 6 ---
  process(clock) begin
    if(clock'event and clock='1') then
      df4 <= df3;
      d_isz4 <= d_isz3;
      itp_c0d2 <= itp_c0d1;
      itp_c1dx2 <= itp_c1dx_shift;
    end if;
  end process;
  ------------------.


  itp_subx <= '0' & itp_c0d2;
  itp_suby <= '0' & itp_c1dx2;
  itp_sub: pg_adder_RCA_SUB_11_0  port map(x=>itp_subx,y=>itp_suby,z=>itp_subz,clk=>clock);

  -- IF [f(x+dx)=c0(x)-c1(x)dx<0] THEN [f(x+dx) := 0] ELSE SHIFT >> 2-bit
  itp_c0_c1dx <= "00000000" when (itp_subz(10)='1') else itp_subz(9 downto 2);


  itp_out0 <= itp_c0_c1dx when (d_isz4='0') else "00000000";


  --- PIPELINE 7(OFF) ---
  df5 <= df4;
  d_isz5 <= d_isz4;
  itp_out1 <= itp_out0;
  ------------------.

  d2(8) <= d_isz5;
  d2(7 downto 0) <= itp_out1;
  d4(8 downto 0) <= d2 when (df5 = '1') else "000000000";
  d4(15 downto 9) <= "0000000";

-- TABLE PART (END) ---------------------------------------------


  --- PIPELINE 3 ---
  process(clock) begin
    if(clock'event and clock='1') then
      x4 <= x3;
      sign3 <= sign2;
    end if;
  end process;
  ------------------.

  --- PIPELINE 4(OFF) ---
  x5 <= x4;
  sign4 <= sign3;
  ------------------.

  --- PIPELINE 5(OFF) ---
  x6 <= x5;
  sign5 <= sign4;
  ------------------.

  --- PIPELINE 6 ---
  process(clock) begin
    if(clock'event and clock='1') then
      x7 <= x6;
      sign6 <= sign5;
    end if;
  end process;
  ------------------.

  --- PIPELINE 7(OFF) ---
  x8 <= x7;
  sign7 <= sign6;
  ------------------.

  --- PIPELINE 8(OFF) ---
  u4: pg_adder_RCA_ADD_16_0  port map(x=>x8,y=>d4,z=>z0,clk=>clock);

  sign8 <= sign7;
  ------------------.

  --- PIPELINE 9 ---
  process(clock) begin
    if(clock'event and clock='1') then
      z(15 downto 0) <= z0;
      z(16) <= sign8;
    end if;
  end process;
  ------------------.

end rtl;
-- ============= END  pg_log_unsigned_add interporation version    
                                   
-- ROM using Lcell not ESB         
-- Author: Tsuyoshi Hamada         
-- Last Modified at May 29,2003    
-- In 6 Out 10 Stage 1 Type"a106"
library ieee;                      
use ieee.std_logic_1164.all;       
                                   
entity lcell_rom_a106_6_10_1 is
  port( indata : in std_logic_vector(5 downto 0);
        clk : in std_logic;
        outdata : out std_logic_vector(9 downto 0));
end lcell_rom_a106_6_10_1;

architecture rtl of lcell_rom_a106_6_10_1 is

  component pg_lcell
    generic (MASK : bit_vector  := X"ffff";
             FF   : integer :=0);
    port (x   : in  std_logic_vector(3 downto 0);
          z   : out std_logic;
          clk : in  std_logic);
  end component;

  signal adr0 : std_logic_vector(5 downto 0);
  signal adr1 : std_logic_vector(5 downto 0);
  signal adr2 : std_logic_vector(5 downto 0);
  signal lc_4_0 : std_logic_vector(9 downto 0);
  signal lc_4_1 : std_logic_vector(9 downto 0);
  signal lc_4_2 : std_logic_vector(9 downto 0);
  signal lc_4_3 : std_logic_vector(9 downto 0);
  signal lut_5_0,lc_5_0 : std_logic_vector(9 downto 0);
  signal lut_5_1,lc_5_1 : std_logic_vector(9 downto 0);
  signal lut_6_0,lc_6_0 : std_logic_vector(9 downto 0);

begin

  LC_000_00 : pg_lcell
  generic map(MASK=>X"6305",FF=>0)
  port map( x=>adr0(3 downto 0),clk=>clk,
            z=>lc_4_0(0));

  LC_000_01 : pg_lcell
  generic map(MASK=>X"B071",FF=>0)
  port map( x=>adr0(3 downto 0),clk=>clk,
            z=>lc_4_0(1));

  LC_000_02 : pg_lcell
  generic map(MASK=>X"5877",FF=>0)
  port map( x=>adr0(3 downto 0),clk=>clk,
            z=>lc_4_0(2));

  LC_000_03 : pg_lcell
  generic map(MASK=>X"DB41",FF=>0)
  port map( x=>adr0(3 downto 0),clk=>clk,
            z=>lc_4_0(3));

  LC_000_04 : pg_lcell
  generic map(MASK=>X"665D",FF=>0)
  port map( x=>adr0(3 downto 0),clk=>clk,
            z=>lc_4_0(4));

  LC_000_05 : pg_lcell
  generic map(MASK=>X"D449",FF=>0)
  port map( x=>adr0(3 downto 0),clk=>clk,
            z=>lc_4_0(5));

  LC_000_06 : pg_lcell
  generic map(MASK=>X"CD11",FF=>0)
  port map( x=>adr0(3 downto 0),clk=>clk,
            z=>lc_4_0(6));

  LC_000_07 : pg_lcell
  generic map(MASK=>X"3CCB",FF=>0)
  port map( x=>adr0(3 downto 0),clk=>clk,
            z=>lc_4_0(7));

  LC_000_08 : pg_lcell
  generic map(MASK=>X"03C7",FF=>0)
  port map( x=>adr0(3 downto 0),clk=>clk,
            z=>lc_4_0(8));

  LC_000_09 : pg_lcell
  generic map(MASK=>X"003F",FF=>0)
  port map( x=>adr0(3 downto 0),clk=>clk,
            z=>lc_4_0(9));

  LC_001_00 : pg_lcell
  generic map(MASK=>X"9393",FF=>0)
  port map( x=>adr0(3 downto 0),clk=>clk,
            z=>lc_4_1(0));

  LC_001_01 : pg_lcell
  generic map(MASK=>X"BBAA",FF=>0)
  port map( x=>adr0(3 downto 0),clk=>clk,
            z=>lc_4_1(1));

  LC_001_02 : pg_lcell
  generic map(MASK=>X"8938",FF=>0)
  port map( x=>adr0(3 downto 0),clk=>clk,
            z=>lc_4_1(2));

  LC_001_03 : pg_lcell
  generic map(MASK=>X"7893",FF=>0)
  port map( x=>adr0(3 downto 0),clk=>clk,
            z=>lc_4_1(3));

  LC_001_04 : pg_lcell
  generic map(MASK=>X"0789",FF=>0)
  port map( x=>adr0(3 downto 0),clk=>clk,
            z=>lc_4_1(4));

  LC_001_05 : pg_lcell
  generic map(MASK=>X"0078",FF=>0)
  port map( x=>adr0(3 downto 0),clk=>clk,
            z=>lc_4_1(5));

  LC_001_06 : pg_lcell
  generic map(MASK=>X"0007",FF=>0)
  port map( x=>adr0(3 downto 0),clk=>clk,
            z=>lc_4_1(6));

--LC_001_07 
  lc_4_1(7) <= '0';

--LC_001_08 
  lc_4_1(8) <= '0';

--LC_001_09 
  lc_4_1(9) <= '0';

  LC_002_00 : pg_lcell
  generic map(MASK=>X"001A",FF=>0)
  port map( x=>adr0(3 downto 0),clk=>clk,
            z=>lc_4_2(0));

  LC_002_01 : pg_lcell
  generic map(MASK=>X"0079",FF=>0)
  port map( x=>adr0(3 downto 0),clk=>clk,
            z=>lc_4_2(1));

  LC_002_02 : pg_lcell
  generic map(MASK=>X"0007",FF=>0)
  port map( x=>adr0(3 downto 0),clk=>clk,
            z=>lc_4_2(2));

--LC_002_03 
  lc_4_2(3) <= '0';

--LC_002_04 
  lc_4_2(4) <= '0';

--LC_002_05 
  lc_4_2(5) <= '0';

--LC_002_06 
  lc_4_2(6) <= '0';

--LC_002_07 
  lc_4_2(7) <= '0';

--LC_002_08 
  lc_4_2(8) <= '0';

--LC_002_09 
  lc_4_2(9) <= '0';

--LC_003_00 
  lc_4_3(0) <= '0';

--LC_003_01 
  lc_4_3(1) <= '0';

--LC_003_02 
  lc_4_3(2) <= '0';

--LC_003_03 
  lc_4_3(3) <= '0';

--LC_003_04 
  lc_4_3(4) <= '0';

--LC_003_05 
  lc_4_3(5) <= '0';

--LC_003_06 
  lc_4_3(6) <= '0';

--LC_003_07 
  lc_4_3(7) <= '0';

--LC_003_08 
  lc_4_3(8) <= '0';

--LC_003_09 
  lc_4_3(9) <= '0';

  adr0 <= indata;
  adr1(5 downto 4) <= adr0(5 downto 4);
  process(clk) begin
    if(clk'event and clk='1') then
      adr2(5) <= adr1(5);
    end if;
  end process;

--  =================================
  with adr1(4) select
    lut_5_0 <= lc_4_0 when '0',
              lc_4_1 when others;

  with adr1(4) select
    lut_5_1 <= lc_4_2 when '0',
              lc_4_3 when others;

--  =================================
  with adr2(5) select
    lut_6_0 <= lc_5_0 when '0',
              lc_5_1 when others;


--  =================================
  process(clk) begin
    if(clk'event and clk='1') then
      lc_5_0 <= lut_5_0;
      lc_5_1 <= lut_5_1;
    end if;
  end process;
--  =================================
    lc_6_0 <= lut_6_0;
  outdata <= lc_6_0;
end rtl;
                                   
-- ROM using Lcell not ESB         
-- Author: Tsuyoshi Hamada         
-- Last Modified at May 29,2003    
-- In 6 Out 9 Stage 1 Type"a906"
library ieee;                      
use ieee.std_logic_1164.all;       
                                   
entity lcell_rom_a906_6_9_1 is
  port( indata : in std_logic_vector(5 downto 0);
        clk : in std_logic;
        outdata : out std_logic_vector(8 downto 0));
end lcell_rom_a906_6_9_1;

architecture rtl of lcell_rom_a906_6_9_1 is

  component pg_lcell
    generic (MASK : bit_vector  := X"ffff";
             FF   : integer :=0);
    port (x   : in  std_logic_vector(3 downto 0);
          z   : out std_logic;
          clk : in  std_logic);
  end component;

  signal adr0 : std_logic_vector(5 downto 0);
  signal adr1 : std_logic_vector(5 downto 0);
  signal adr2 : std_logic_vector(5 downto 0);
  signal lc_4_0 : std_logic_vector(8 downto 0);
  signal lc_4_1 : std_logic_vector(8 downto 0);
  signal lc_4_2 : std_logic_vector(8 downto 0);
  signal lc_4_3 : std_logic_vector(8 downto 0);
  signal lut_5_0,lc_5_0 : std_logic_vector(8 downto 0);
  signal lut_5_1,lc_5_1 : std_logic_vector(8 downto 0);
  signal lut_6_0,lc_6_0 : std_logic_vector(8 downto 0);

begin

  LC_000_00 : pg_lcell
  generic map(MASK=>X"DD64",FF=>0)
  port map( x=>adr0(3 downto 0),clk=>clk,
            z=>lc_4_0(0));

  LC_000_01 : pg_lcell
  generic map(MASK=>X"2F5F",FF=>0)
  port map( x=>adr0(3 downto 0),clk=>clk,
            z=>lc_4_0(1));

  LC_000_02 : pg_lcell
  generic map(MASK=>X"47A2",FF=>0)
  port map( x=>adr0(3 downto 0),clk=>clk,
            z=>lc_4_0(2));

  LC_000_03 : pg_lcell
  generic map(MASK=>X"7DEB",FF=>0)
  port map( x=>adr0(3 downto 0),clk=>clk,
            z=>lc_4_0(3));

  LC_000_04 : pg_lcell
  generic map(MASK=>X"29E6",FF=>0)
  port map( x=>adr0(3 downto 0),clk=>clk,
            z=>lc_4_0(4));

  LC_000_05 : pg_lcell
  generic map(MASK=>X"1B4B",FF=>0)
  port map( x=>adr0(3 downto 0),clk=>clk,
            z=>lc_4_0(5));

  LC_000_06 : pg_lcell
  generic map(MASK=>X"F8D9",FF=>0)
  port map( x=>adr0(3 downto 0),clk=>clk,
            z=>lc_4_0(6));

  LC_000_07 : pg_lcell
  generic map(MASK=>X"07C7",FF=>0)
  port map( x=>adr0(3 downto 0),clk=>clk,
            z=>lc_4_0(7));

  LC_000_08 : pg_lcell
  generic map(MASK=>X"003F",FF=>0)
  port map( x=>adr0(3 downto 0),clk=>clk,
            z=>lc_4_0(8));

  LC_001_00 : pg_lcell
  generic map(MASK=>X"5892",FF=>0)
  port map( x=>adr0(3 downto 0),clk=>clk,
            z=>lc_4_1(0));

  LC_001_01 : pg_lcell
  generic map(MASK=>X"350A",FF=>0)
  port map( x=>adr0(3 downto 0),clk=>clk,
            z=>lc_4_1(1));

  LC_001_02 : pg_lcell
  generic map(MASK=>X"F352",FF=>0)
  port map( x=>adr0(3 downto 0),clk=>clk,
            z=>lc_4_1(2));

  LC_001_03 : pg_lcell
  generic map(MASK=>X"0F37",FF=>0)
  port map( x=>adr0(3 downto 0),clk=>clk,
            z=>lc_4_1(3));

  LC_001_04 : pg_lcell
  generic map(MASK=>X"00F1",FF=>0)
  port map( x=>adr0(3 downto 0),clk=>clk,
            z=>lc_4_1(4));

  LC_001_05 : pg_lcell
  generic map(MASK=>X"000F",FF=>0)
  port map( x=>adr0(3 downto 0),clk=>clk,
            z=>lc_4_1(5));

--LC_001_06 
  lc_4_1(6) <= '0';

--LC_001_07 
  lc_4_1(7) <= '0';

--LC_001_08 
  lc_4_1(8) <= '0';

  LC_002_00 : pg_lcell
  generic map(MASK=>X"0046",FF=>0)
  port map( x=>adr0(3 downto 0),clk=>clk,
            z=>lc_4_2(0));

  LC_002_01 : pg_lcell
  generic map(MASK=>X"003E",FF=>0)
  port map( x=>adr0(3 downto 0),clk=>clk,
            z=>lc_4_2(1));

  LC_002_02 : pg_lcell
  generic map(MASK=>X"0001",FF=>0)
  port map( x=>adr0(3 downto 0),clk=>clk,
            z=>lc_4_2(2));

--LC_002_03 
  lc_4_2(3) <= '0';

--LC_002_04 
  lc_4_2(4) <= '0';

--LC_002_05 
  lc_4_2(5) <= '0';

--LC_002_06 
  lc_4_2(6) <= '0';

--LC_002_07 
  lc_4_2(7) <= '0';

--LC_002_08 
  lc_4_2(8) <= '0';

--LC_003_00 
  lc_4_3(0) <= '0';

--LC_003_01 
  lc_4_3(1) <= '0';

--LC_003_02 
  lc_4_3(2) <= '0';

--LC_003_03 
  lc_4_3(3) <= '0';

--LC_003_04 
  lc_4_3(4) <= '0';

--LC_003_05 
  lc_4_3(5) <= '0';

--LC_003_06 
  lc_4_3(6) <= '0';

--LC_003_07 
  lc_4_3(7) <= '0';

--LC_003_08 
  lc_4_3(8) <= '0';

  adr0 <= indata;
  adr1(5 downto 4) <= adr0(5 downto 4);
  process(clk) begin
    if(clk'event and clk='1') then
      adr2(5) <= adr1(5);
    end if;
  end process;

--  =================================
  with adr1(4) select
    lut_5_0 <= lc_4_0 when '0',
              lc_4_1 when others;

  with adr1(4) select
    lut_5_1 <= lc_4_2 when '0',
              lc_4_3 when others;

--  =================================
  with adr2(5) select
    lut_6_0 <= lc_5_0 when '0',
              lc_5_1 when others;


--  =================================
  process(clk) begin
    if(clk'event and clk='1') then
      lc_5_0 <= lut_5_0;
      lc_5_1 <= lut_5_1;
    end if;
  end process;
--  =================================
    lc_6_0 <= lut_6_0;
  outdata <= lc_6_0;
end rtl;

--+--------------------------------+
--| PGPG unsigned multiplier       |
--|  2004/02/16 for Xilinx Devices |
--|      by Tsuyoshi Hamada        |
--+--------------------------------+
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity pg_log_unsigned_add_umult_6_9_0 is
  port(x : in std_logic_vector(5 downto 0);
       y : in std_logic_vector(8 downto 0);
       z : out std_logic_vector(14 downto 0);
     clk : in std_logic);
end pg_log_unsigned_add_umult_6_9_0;

architecture rtl of pg_log_unsigned_add_umult_6_9_0 is

  signal s : std_logic_vector(14 downto 0);
begin
  s <= x * y;
  z <= s;
end rtl;

--+--------------------------------+
--| PGPG Ripple-Carry Adder        |
--|  2004/02/12 for Xilinx Devices |
--|      by Tsuyoshi Hamada        |
--+--------------------------------+
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity pg_adder_RCA_SUB_17_0 is
  port(x,y : in std_logic_vector(16 downto 0);
       z : out std_logic_vector(16 downto 0);
       clk : in std_logic);
end pg_adder_RCA_SUB_17_0;

architecture rtl of pg_adder_RCA_SUB_17_0 is

  signal sum : std_logic_vector(16 downto 0);
begin
  sum <= x - y;
  z <= sum;
end rtl;

--+--------------------------------+
--| PGPG Ripple-Carry Adder        |
--|  2004/02/12 for Xilinx Devices |
--|      by Tsuyoshi Hamada        |
--+--------------------------------+
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity pg_adder_RCA_SUB_16_0 is
  port(x,y : in std_logic_vector(15 downto 0);
       z : out std_logic_vector(15 downto 0);
       clk : in std_logic);
end pg_adder_RCA_SUB_16_0;

architecture rtl of pg_adder_RCA_SUB_16_0 is

  signal sum : std_logic_vector(15 downto 0);
begin
  sum <= x - y;
  z <= sum;
end rtl;

--+--------------------------------+
--| PGPG Ripple-Carry Adder        |
--|  2004/02/12 for Xilinx Devices |
--|      by Tsuyoshi Hamada        |
--+--------------------------------+
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity pg_adder_RCA_SUB_11_0 is
  port(x,y : in std_logic_vector(10 downto 0);
       z : out std_logic_vector(10 downto 0);
       clk : in std_logic);
end pg_adder_RCA_SUB_11_0;

architecture rtl of pg_adder_RCA_SUB_11_0 is

  signal sum : std_logic_vector(10 downto 0);
begin
  sum <= x - y;
  z <= sum;
end rtl;

--+--------------------------------+
--| PGPG Ripple-Carry Adder        |
--|  2004/02/12 for Xilinx Devices |
--|      by Tsuyoshi Hamada        |
--+--------------------------------+
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity pg_adder_RCA_ADD_16_0 is
  port(x,y : in std_logic_vector(15 downto 0);
       z : out std_logic_vector(15 downto 0);
       clk : in std_logic);
end pg_adder_RCA_ADD_16_0;

architecture rtl of pg_adder_RCA_ADD_16_0 is

  signal sum : std_logic_vector(15 downto 0);
begin
  sum <= x + y;
  z <= sum;
end rtl;
                                                           
library ieee;                                              
use ieee.std_logic_1164.all;                               
                                                           
entity pg_log_shift_m1 is                          
  generic (PG_WIDTH: integer);                             
  port( x : in std_logic_vector(PG_WIDTH-1 downto 0);      
	   y : out std_logic_vector(PG_WIDTH-1 downto 0);    
	   clk : in std_logic);                              
end pg_log_shift_m1;                               
                                                           
architecture rtl of pg_log_shift_m1 is             
                                                           
begin                                                      
                                                           
  y <= '0' & x(PG_WIDTH-2) & '0' & x(PG_WIDTH-3 downto 1);   
                                                           
end rtl;                                                   

library ieee;
use ieee.std_logic_1164.all;

entity pg_log_mul_17_1 is
  port( x,y : in std_logic_vector(16 downto 0);
          z : out std_logic_vector(16 downto 0);
        clk : in std_logic);
end pg_log_mul_17_1;

architecture rtl of pg_log_mul_17_1 is

  component pg_adder_RCA_ADD_15_1
    port (x,y: in std_logic_vector(14 downto 0);
          clk: in std_logic;
          z: out std_logic_vector(14 downto 0));
  end component;

 signal addx,addy,addz: std_logic_vector(14 downto 0); 

begin

  process(clk) begin
    if(clk'event and clk='1') then
      z(16) <= x(16) xor y(16);
      z(15) <= x(15) and y(15);
    end if;
  end process;
  addx <= x(14 downto 0);
  addy <= y(14 downto 0);

  u1: pg_adder_RCA_ADD_15_1  port map(x=>addx,y=>addy,clk=>clk,z=>addz);
  z(14 downto 0) <= addz;

end rtl;

--+--------------------------------+
--| PGPG Ripple-Carry Adder        |
--|  2004/02/12 for Xilinx Devices |
--|      by Tsuyoshi Hamada        |
--+--------------------------------+
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity pg_adder_RCA_ADD_15_1 is
  port(x,y : in std_logic_vector(14 downto 0);
       z : out std_logic_vector(14 downto 0);
       clk : in std_logic);
end pg_adder_RCA_ADD_15_1;

architecture rtl of pg_adder_RCA_ADD_15_1 is

  signal sum : std_logic_vector(14 downto 0);
begin
  sum <= x + y;
  process(clk) begin
    if(clk'event and clk='1') then
      z <= sum;
    end if;
  end process;
end rtl;

library ieee;
use ieee.std_logic_1164.all;

entity pg_log_div_17_1 is
  port( x,y : in std_logic_vector(16 downto 0);
          z : out std_logic_vector(16 downto 0);
        clk : in std_logic);
end pg_log_div_17_1;

architecture rtl of pg_log_div_17_1 is

  component pg_adder_RCA_SUB_15_1
    port (x,y: in std_logic_vector(14 downto 0);
          clk: in std_logic;
          z: out std_logic_vector(14 downto 0));
  end component;

 signal addx,addy,addz: std_logic_vector(14 downto 0); 

begin

  process(clk) begin
    if(clk'event and clk='1') then
      z(16) <= x(16) xor y(16);
      z(15) <= x(15) and y(15);
    end if;
  end process;
  addx <= x(14 downto 0);
  addy <= y(14 downto 0);

  u1: pg_adder_RCA_SUB_15_1  port map(x=>addx,y=>addy,clk=>clk,z=>addz);
  z(14 downto 0) <= addz;

end rtl;

--+--------------------------------+
--| PGPG Ripple-Carry Adder        |
--|  2004/02/12 for Xilinx Devices |
--|      by Tsuyoshi Hamada        |
--+--------------------------------+
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity pg_adder_RCA_SUB_15_1 is
  port(x,y : in std_logic_vector(14 downto 0);
       z : out std_logic_vector(14 downto 0);
       clk : in std_logic);
end pg_adder_RCA_SUB_15_1;

architecture rtl of pg_adder_RCA_SUB_15_1 is

  signal sum : std_logic_vector(14 downto 0);
begin
  sum <= x - y;
  process(clk) begin
    if(clk'event and clk='1') then
      z <= sum;
    end if;
  end process;
end rtl;

library ieee;
use ieee.std_logic_1164.all;

entity pg_log_sdiv_17_1 is
  port( x,y : in std_logic_vector(16 downto 0);
          z : out std_logic_vector(16 downto 0);
        clk : in std_logic);
end pg_log_sdiv_17_1;

architecture rtl of pg_log_sdiv_17_1 is

  component pg_adder_RCA_SUB_16_1
    port (x,y: in std_logic_vector(15 downto 0);
          clk: in std_logic;
          z: out std_logic_vector(15 downto 0));
  end component;

 signal addx,addy,addz: std_logic_vector(15 downto 0);

begin

  process(clk) begin
    if(clk'event and clk='1') then
      z(16) <= x(16) xor y(16);
      z(15) <= x(15) and y(15);
    end if;
  end process;
  addx <= '0' & x(14 downto 0);
  addy <= '0' & y(14 downto 0);

  u1: pg_adder_RCA_SUB_16_1  port map(x=>addx,y=>addy,clk=>clk,z=>addz);
  with addz(15) select
    z(14 downto 0) <= "000000000000000" when '1',
    addz(14 downto 0) when others;

end rtl;

--+--------------------------------+
--| PGPG Ripple-Carry Adder        |
--|  2004/02/12 for Xilinx Devices |
--|      by Tsuyoshi Hamada        |
--+--------------------------------+
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity pg_adder_RCA_SUB_16_1 is
  port(x,y : in std_logic_vector(15 downto 0);
       z : out std_logic_vector(15 downto 0);
       clk : in std_logic);
end pg_adder_RCA_SUB_16_1;

architecture rtl of pg_adder_RCA_SUB_16_1 is

  signal sum : std_logic_vector(15 downto 0);
begin
  sum <= x - y;
  process(clk) begin
    if(clk'event and clk='1') then
      z <= sum;
    end if;
  end process;
end rtl;
-- ***************************************************************
-- * PGPG LOGARITHMIC TO FIXED-POINT FORMAT CONVERTER            *
-- *  AUTHOR: Tsuyoshi Hamada                                    *
-- *  VERSION: 2.00                                              *
-- *  LAST MODIFIED AT Tue Jun 03 22:52:01 JST 2003              *
-- ***************************************************************
library ieee;
use ieee.std_logic_1164.all;

entity pg_conv_ltof_17_8_57_2 is
  port(logdata : in std_logic_vector(16 downto 0);
       fixdata : out std_logic_vector(56 downto 0);
       clk : in std_logic);
end pg_conv_ltof_17_8_57_2;

architecture rtl of pg_conv_ltof_17_8_57_2 is

  component bram_rom_8f28_8_8_1
    port(indata : in std_logic_vector(7 downto 0);
         outdata : out std_logic_vector(7 downto 0);
         clk : in std_logic);
  end component;

  component unreg_shift_ltof_9_7_56
    port( indata : in std_logic_vector(8 downto 0);
          control : in std_logic_vector(6 downto 0);
          outdata : out std_logic_vector(55 downto 0)); 
  end component;

  signal frac1 : std_logic_vector(7 downto 0);
  signal frac2 : std_logic_vector(8 downto 0);
  signal sign1 : std_logic;
  signal sign2 : std_logic;
  signal sign3 : std_logic;
  signal sign4 : std_logic;
  signal sign5 : std_logic;
  signal sign6 : std_logic;
  signal nz1 : std_logic;
  signal exp1 : std_logic_vector(6 downto 0);
  signal fix1 : std_logic_vector(55 downto 0);

begin

  process(clk) begin
    if(clk'event and clk='1') then
      sign1 <= logdata(16);
      nz1 <= logdata(15);
      exp1 <= logdata(14 downto 8);
    end if;
  end process;

  u1: bram_rom_8f28_8_8_1
          port map(indata=>logdata(7 downto 0),outdata=>frac1,clk=>clk);

  with nz1 select
    frac2 <= '1' & frac1 when '1',
             "000000000" when others;

  -------------------------------------------------------------------
  -- PIPELINE 3,4,5 STAGES
  u3: unreg_shift_ltof_9_7_56
            port map (indata=>frac2,control=>exp1,outdata=>fix1);
  sign6 <= sign5;
  sign5 <= sign4;
  sign4 <= sign3;
  sign3 <= sign2;
  sign2 <= sign1;
  -------------------------------------------------------------------

  process(clk) begin                
    if(clk'event and clk='1') then  
      fixdata(56) <= sign6;         
      fixdata(55 downto 0) <= fix1; 
    end if;                         
  end process;                      

end rtl;
-- Pipelined Shifter for Log to Fix Converter
-- for Xilinx Devices                        
-- Author: Tsuyoshi Hamada                   
-- Last Modified at Feb 14,2003              
                                             
library ieee;                                
use ieee.std_logic_1164.all;                 

entity unreg_shift_ltof_9_7_56 is
  port( indata : in std_logic_vector(8 downto 0);       
        control : in std_logic_vector(6 downto 0);     
        outdata : out std_logic_vector(55 downto 0));   
end unreg_shift_ltof_9_7_56;

architecture rtl of unreg_shift_ltof_9_7_56 is
                                                                    
  signal c0 : std_logic_vector(5 downto 0);
  signal c1 : std_logic_vector(5 downto 0);
  signal c2 : std_logic_vector(5 downto 0);
  signal c3 : std_logic_vector(5 downto 0);
  signal c4 : std_logic_vector(5 downto 0);
  signal c5 : std_logic_vector(5 downto 0);
  signal o0,o0d : std_logic_vector(8 downto 0);
  signal o1,o1d : std_logic_vector(9 downto 0);
  signal o2,o2d : std_logic_vector(11 downto 0);
  signal o3,o3d : std_logic_vector(15 downto 0);
  signal o4,o4d : std_logic_vector(23 downto 0);
  signal o5,o5d : std_logic_vector(39 downto 0);
  signal o6,o6d : std_logic_vector(71 downto 0);
                                                                    
begin                                                               
                                                                    
  c0 <= control(5 downto 0);
  outdata <= o6(63 downto 8);

  o0d <= indata;
  with c0(0) select
    o1 <= o0d & '0' when '1',
          '0' & o0d when others;

  with c1(1) select
    o2 <= o1d & "00" when '1',
          "00" & o1d when others;

  with c2(2) select
    o3 <= o2d & "0000" when '1',
          "0000" & o2d when others;

  with c3(3) select
    o4 <= o3d & "00000000" when '1',
          "00000000" & o3d when others;

  with c4(4) select
    o5 <= o4d & "0000000000000000" when '1',
          "0000000000000000" & o4d when others;

  with c5(5) select
    o6 <= o5d & "00000000000000000000000000000000" when '1',
          "00000000000000000000000000000000" & o5d when others;

--  process(clk) begin
--    if(clk'event and clk='1') then 
      o1d <= o1;
      c1 <= c0;
--    end if;
--  end process;

--  process(clk) begin
--    if(clk'event and clk='1') then 
      o2d <= o2;
      c2 <= c1;
--    end if;
--  end process;

--  process(clk) begin
--    if(clk'event and clk='1') then 
      o3d <= o3;
      c3 <= c2;
--    end if;
--  end process;

--  process(clk) begin
--    if(clk'event and clk='1') then 
      o4d <= o4;
      c4 <= c3;
--    end if;
--  end process;

--  process(clk) begin
--    if(clk'event and clk='1') then 
      o5d <= o5;
      c5 <= c4;
--    end if;
--  end process;

                                                                    
end rtl;                                                            

-- ROM using Xilinx BlockRAM       
-- Author: Tsuyoshi Hamada         
-- Last Modified at Jun 2, 2004    
-- In 8 Out 8 Stage 1 Type"8f28"
library ieee;                      
use ieee.std_logic_1164.all;       
use ieee.std_logic_arith.all;      
use ieee.std_logic_unsigned.all;   

entity bram_rom_8f28_8_8_1 is
  port( indata : in std_logic_vector(7 downto 0);
        clk : in std_logic;
        outdata : out std_logic_vector(7 downto 0));
end bram_rom_8f28_8_8_1;

architecture rtl of bram_rom_8f28_8_8_1 is

  type romarray is array(0 to 255) of std_logic_vector(7 downto 0);
  constant brom : romarray :=(
    "00000000",   -- 0x0 : 0x0
    "00000001",   -- 0x1 : 0x1
    "00000001",   -- 0x2 : 0x1
    "00000010",   -- 0x3 : 0x2
    "00000011",   -- 0x4 : 0x3
    "00000011",   -- 0x5 : 0x3
    "00000100",   -- 0x6 : 0x4
    "00000101",   -- 0x7 : 0x5
    "00000110",   -- 0x8 : 0x6
    "00000110",   -- 0x9 : 0x6
    "00000111",   -- 0xA : 0x7
    "00001000",   -- 0xB : 0x8
    "00001000",   -- 0xC : 0x8
    "00001001",   -- 0xD : 0x9
    "00001010",   -- 0xE : 0xA
    "00001011",   -- 0xF : 0xB
    "00001011",   -- 0x10 : 0xB
    "00001100",   -- 0x11 : 0xC
    "00001101",   -- 0x12 : 0xD
    "00001110",   -- 0x13 : 0xE
    "00001110",   -- 0x14 : 0xE
    "00001111",   -- 0x15 : 0xF
    "00010000",   -- 0x16 : 0x10
    "00010000",   -- 0x17 : 0x10
    "00010001",   -- 0x18 : 0x11
    "00010010",   -- 0x19 : 0x12
    "00010011",   -- 0x1A : 0x13
    "00010011",   -- 0x1B : 0x13
    "00010100",   -- 0x1C : 0x14
    "00010101",   -- 0x1D : 0x15
    "00010110",   -- 0x1E : 0x16
    "00010110",   -- 0x1F : 0x16
    "00010111",   -- 0x20 : 0x17
    "00011000",   -- 0x21 : 0x18
    "00011001",   -- 0x22 : 0x19
    "00011001",   -- 0x23 : 0x19
    "00011010",   -- 0x24 : 0x1A
    "00011011",   -- 0x25 : 0x1B
    "00011100",   -- 0x26 : 0x1C
    "00011101",   -- 0x27 : 0x1D
    "00011101",   -- 0x28 : 0x1D
    "00011110",   -- 0x29 : 0x1E
    "00011111",   -- 0x2A : 0x1F
    "00100000",   -- 0x2B : 0x20
    "00100000",   -- 0x2C : 0x20
    "00100001",   -- 0x2D : 0x21
    "00100010",   -- 0x2E : 0x22
    "00100011",   -- 0x2F : 0x23
    "00100100",   -- 0x30 : 0x24
    "00100100",   -- 0x31 : 0x24
    "00100101",   -- 0x32 : 0x25
    "00100110",   -- 0x33 : 0x26
    "00100111",   -- 0x34 : 0x27
    "00101000",   -- 0x35 : 0x28
    "00101000",   -- 0x36 : 0x28
    "00101001",   -- 0x37 : 0x29
    "00101010",   -- 0x38 : 0x2A
    "00101011",   -- 0x39 : 0x2B
    "00101100",   -- 0x3A : 0x2C
    "00101100",   -- 0x3B : 0x2C
    "00101101",   -- 0x3C : 0x2D
    "00101110",   -- 0x3D : 0x2E
    "00101111",   -- 0x3E : 0x2F
    "00110000",   -- 0x3F : 0x30
    "00110000",   -- 0x40 : 0x30
    "00110001",   -- 0x41 : 0x31
    "00110010",   -- 0x42 : 0x32
    "00110011",   -- 0x43 : 0x33
    "00110100",   -- 0x44 : 0x34
    "00110101",   -- 0x45 : 0x35
    "00110101",   -- 0x46 : 0x35
    "00110110",   -- 0x47 : 0x36
    "00110111",   -- 0x48 : 0x37
    "00111000",   -- 0x49 : 0x38
    "00111001",   -- 0x4A : 0x39
    "00111010",   -- 0x4B : 0x3A
    "00111010",   -- 0x4C : 0x3A
    "00111011",   -- 0x4D : 0x3B
    "00111100",   -- 0x4E : 0x3C
    "00111101",   -- 0x4F : 0x3D
    "00111110",   -- 0x50 : 0x3E
    "00111111",   -- 0x51 : 0x3F
    "01000000",   -- 0x52 : 0x40
    "01000001",   -- 0x53 : 0x41
    "01000001",   -- 0x54 : 0x41
    "01000010",   -- 0x55 : 0x42
    "01000011",   -- 0x56 : 0x43
    "01000100",   -- 0x57 : 0x44
    "01000101",   -- 0x58 : 0x45
    "01000110",   -- 0x59 : 0x46
    "01000111",   -- 0x5A : 0x47
    "01001000",   -- 0x5B : 0x48
    "01001000",   -- 0x5C : 0x48
    "01001001",   -- 0x5D : 0x49
    "01001010",   -- 0x5E : 0x4A
    "01001011",   -- 0x5F : 0x4B
    "01001100",   -- 0x60 : 0x4C
    "01001101",   -- 0x61 : 0x4D
    "01001110",   -- 0x62 : 0x4E
    "01001111",   -- 0x63 : 0x4F
    "01010000",   -- 0x64 : 0x50
    "01010001",   -- 0x65 : 0x51
    "01010001",   -- 0x66 : 0x51
    "01010010",   -- 0x67 : 0x52
    "01010011",   -- 0x68 : 0x53
    "01010100",   -- 0x69 : 0x54
    "01010101",   -- 0x6A : 0x55
    "01010110",   -- 0x6B : 0x56
    "01010111",   -- 0x6C : 0x57
    "01011000",   -- 0x6D : 0x58
    "01011001",   -- 0x6E : 0x59
    "01011010",   -- 0x6F : 0x5A
    "01011011",   -- 0x70 : 0x5B
    "01011100",   -- 0x71 : 0x5C
    "01011101",   -- 0x72 : 0x5D
    "01011110",   -- 0x73 : 0x5E
    "01011110",   -- 0x74 : 0x5E
    "01011111",   -- 0x75 : 0x5F
    "01100000",   -- 0x76 : 0x60
    "01100001",   -- 0x77 : 0x61
    "01100010",   -- 0x78 : 0x62
    "01100011",   -- 0x79 : 0x63
    "01100100",   -- 0x7A : 0x64
    "01100101",   -- 0x7B : 0x65
    "01100110",   -- 0x7C : 0x66
    "01100111",   -- 0x7D : 0x67
    "01101000",   -- 0x7E : 0x68
    "01101001",   -- 0x7F : 0x69
    "01101010",   -- 0x80 : 0x6A
    "01101011",   -- 0x81 : 0x6B
    "01101100",   -- 0x82 : 0x6C
    "01101101",   -- 0x83 : 0x6D
    "01101110",   -- 0x84 : 0x6E
    "01101111",   -- 0x85 : 0x6F
    "01110000",   -- 0x86 : 0x70
    "01110001",   -- 0x87 : 0x71
    "01110010",   -- 0x88 : 0x72
    "01110011",   -- 0x89 : 0x73
    "01110100",   -- 0x8A : 0x74
    "01110101",   -- 0x8B : 0x75
    "01110110",   -- 0x8C : 0x76
    "01110111",   -- 0x8D : 0x77
    "01111000",   -- 0x8E : 0x78
    "01111001",   -- 0x8F : 0x79
    "01111010",   -- 0x90 : 0x7A
    "01111011",   -- 0x91 : 0x7B
    "01111100",   -- 0x92 : 0x7C
    "01111101",   -- 0x93 : 0x7D
    "01111110",   -- 0x94 : 0x7E
    "01111111",   -- 0x95 : 0x7F
    "10000000",   -- 0x96 : 0x80
    "10000001",   -- 0x97 : 0x81
    "10000010",   -- 0x98 : 0x82
    "10000011",   -- 0x99 : 0x83
    "10000100",   -- 0x9A : 0x84
    "10000101",   -- 0x9B : 0x85
    "10000111",   -- 0x9C : 0x87
    "10001000",   -- 0x9D : 0x88
    "10001001",   -- 0x9E : 0x89
    "10001010",   -- 0x9F : 0x8A
    "10001011",   -- 0xA0 : 0x8B
    "10001100",   -- 0xA1 : 0x8C
    "10001101",   -- 0xA2 : 0x8D
    "10001110",   -- 0xA3 : 0x8E
    "10001111",   -- 0xA4 : 0x8F
    "10010000",   -- 0xA5 : 0x90
    "10010001",   -- 0xA6 : 0x91
    "10010010",   -- 0xA7 : 0x92
    "10010011",   -- 0xA8 : 0x93
    "10010101",   -- 0xA9 : 0x95
    "10010110",   -- 0xAA : 0x96
    "10010111",   -- 0xAB : 0x97
    "10011000",   -- 0xAC : 0x98
    "10011001",   -- 0xAD : 0x99
    "10011010",   -- 0xAE : 0x9A
    "10011011",   -- 0xAF : 0x9B
    "10011100",   -- 0xB0 : 0x9C
    "10011101",   -- 0xB1 : 0x9D
    "10011111",   -- 0xB2 : 0x9F
    "10100000",   -- 0xB3 : 0xA0
    "10100001",   -- 0xB4 : 0xA1
    "10100010",   -- 0xB5 : 0xA2
    "10100011",   -- 0xB6 : 0xA3
    "10100100",   -- 0xB7 : 0xA4
    "10100101",   -- 0xB8 : 0xA5
    "10100110",   -- 0xB9 : 0xA6
    "10101000",   -- 0xBA : 0xA8
    "10101001",   -- 0xBB : 0xA9
    "10101010",   -- 0xBC : 0xAA
    "10101011",   -- 0xBD : 0xAB
    "10101100",   -- 0xBE : 0xAC
    "10101101",   -- 0xBF : 0xAD
    "10101111",   -- 0xC0 : 0xAF
    "10110000",   -- 0xC1 : 0xB0
    "10110001",   -- 0xC2 : 0xB1
    "10110010",   -- 0xC3 : 0xB2
    "10110011",   -- 0xC4 : 0xB3
    "10110100",   -- 0xC5 : 0xB4
    "10110110",   -- 0xC6 : 0xB6
    "10110111",   -- 0xC7 : 0xB7
    "10111000",   -- 0xC8 : 0xB8
    "10111001",   -- 0xC9 : 0xB9
    "10111010",   -- 0xCA : 0xBA
    "10111100",   -- 0xCB : 0xBC
    "10111101",   -- 0xCC : 0xBD
    "10111110",   -- 0xCD : 0xBE
    "10111111",   -- 0xCE : 0xBF
    "11000000",   -- 0xCF : 0xC0
    "11000010",   -- 0xD0 : 0xC2
    "11000011",   -- 0xD1 : 0xC3
    "11000100",   -- 0xD2 : 0xC4
    "11000101",   -- 0xD3 : 0xC5
    "11000110",   -- 0xD4 : 0xC6
    "11001000",   -- 0xD5 : 0xC8
    "11001001",   -- 0xD6 : 0xC9
    "11001010",   -- 0xD7 : 0xCA
    "11001011",   -- 0xD8 : 0xCB
    "11001101",   -- 0xD9 : 0xCD
    "11001110",   -- 0xDA : 0xCE
    "11001111",   -- 0xDB : 0xCF
    "11010000",   -- 0xDC : 0xD0
    "11010010",   -- 0xDD : 0xD2
    "11010011",   -- 0xDE : 0xD3
    "11010100",   -- 0xDF : 0xD4
    "11010110",   -- 0xE0 : 0xD6
    "11010111",   -- 0xE1 : 0xD7
    "11011000",   -- 0xE2 : 0xD8
    "11011001",   -- 0xE3 : 0xD9
    "11011011",   -- 0xE4 : 0xDB
    "11011100",   -- 0xE5 : 0xDC
    "11011101",   -- 0xE6 : 0xDD
    "11011110",   -- 0xE7 : 0xDE
    "11100000",   -- 0xE8 : 0xE0
    "11100001",   -- 0xE9 : 0xE1
    "11100010",   -- 0xEA : 0xE2
    "11100100",   -- 0xEB : 0xE4
    "11100101",   -- 0xEC : 0xE5
    "11100110",   -- 0xED : 0xE6
    "11101000",   -- 0xEE : 0xE8
    "11101001",   -- 0xEF : 0xE9
    "11101010",   -- 0xF0 : 0xEA
    "11101100",   -- 0xF1 : 0xEC
    "11101101",   -- 0xF2 : 0xED
    "11101110",   -- 0xF3 : 0xEE
    "11110000",   -- 0xF4 : 0xF0
    "11110001",   -- 0xF5 : 0xF1
    "11110010",   -- 0xF6 : 0xF2
    "11110100",   -- 0xF7 : 0xF4
    "11110101",   -- 0xF8 : 0xF5
    "11110110",   -- 0xF9 : 0xF6
    "11111000",   -- 0xFA : 0xF8
    "11111001",   -- 0xFB : 0xF9
    "11111010",   -- 0xFC : 0xFA
    "11111100",   -- 0xFD : 0xFC
    "11111101",   -- 0xFE : 0xFD
    "11111111");  -- 0xFF : 0xFF

begin
  process(clk) begin
    if(clk'event and clk='1') then
      outdata <= brom(CONV_INTEGER(indata));
    end if;
  end process;
end rtl;

-- pg_fix_accum
-- Pipelined, Virtual Multiple Pipelined Fixed-Point Accumulator for Programmable GRAPE
-- Author: Tsuyoshi Hamada
-- Last Modified at May 9 13:33:33
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity pg_fix_accum_57_64_1 is
  port (fdata: in std_logic_vector(56 downto 0);
        sdata: out std_logic_vector(63 downto 0);
        run : in std_logic;
        clk : in std_logic);
end pg_fix_accum_57_64_1;

architecture rtl of pg_fix_accum_57_64_1 is

  component fix_accum_reg_1
    generic (WIDTH: integer);
    port (indata: in std_logic_vector(WIDTH-1 downto 0);
          cin : in std_logic;
          run : in std_logic;
          addsub : in std_logic;
          addsubd : out std_logic;
          rund : out std_logic;
          cout : out std_logic;
          reg0 : out std_logic_vector(WIDTH-1 downto 0);
          clk : in std_logic);
  end component;

  component fix_accum_reg_last_1
    generic (WIDTH: integer);
    port (indata: in std_logic_vector(WIDTH-1 downto 0);
          cin : in std_logic;
          run : in std_logic;
          addsub : in std_logic;
--        countd : out std_logic_vector(-1 downto 0);
--        addsubd : out std_logic;
--        rund : out std_logic;
--        cout : out std_logic;
          reg0 : out std_logic_vector(WIDTH-1 downto 0);
          clk : in std_logic);
  end component;

  signal fx: std_logic_vector(63 downto 0);
  signal fx_0_0: std_logic_vector(63 downto 0);
  signal rsig : std_logic_vector(1 downto 0);
  signal addsub : std_logic_vector(0 downto 0);
  signal carry : std_logic_vector(0 downto 0);

begin

  fx <= "00000000" & fdata(55 downto 0);

  fx_0_0 <= fx(63 downto 0);
  addsub(0) <= not fdata(56);
  carry(0) <= fdata(56);
  rsig(0)  <= run;


  process(clk) begin              
    if(clk'event and clk='1') then
      rsig(1) <= rsig(0);         
    end if;                       
  end process;                    

  u0: fix_accum_reg_last_1        
    generic map(WIDTH=>64)                
    port map(indata=>fx_0_0,            
             cin=>'0',                
             run=>rsig(0),               
             addsub=>addsub(0),          
--           countd=>count1,           
--           addsubd=>addsub(1),       
--           rund=>rsig(1),            
--           cout=>carry(1),           
             reg0=>sdata(63 downto 0),
             clk=>clk);                   
                                          
end rtl;                                                            
                                                                    
library ieee;                                                       
use ieee.std_logic_1164.all;                                        
use ieee.std_logic_arith.all;                                        
use ieee.std_logic_unsigned.all;                                    
                                                                    
entity fix_accum_reg_last_1 is
  generic(WIDTH: integer := 28);                                    
  port(indata : in std_logic_vector(WIDTH-1 downto 0);              
       cin : in std_logic;     
       run : in std_logic;     
       addsub : in std_logic;  
--     countd : out std_logic_vector(-1 downto 0);
--     addsubd : out std_logic;
--     rund : out std_logic;   
--     cout : out std_logic;   
       reg0 : out std_logic_vector(WIDTH-1 downto 0);
       clk : in std_logic);    
end fix_accum_reg_last_1;
                                                                    
architecture rtl of fix_accum_reg_last_1 is                                           
                                                                    
                                                                    
signal sum : std_logic_vector(WIDTH-1 downto 0);
signal zeros : std_logic_vector(WIDTH-2 downto 0);
signal sx : std_logic_vector(WIDTH-1 downto 0);                     
signal zero : std_logic_vector(WIDTH-1 downto 0);                   
signal addout : std_logic_vector(WIDTH-1 downto 0);                 
signal run1 : std_logic;                                            
--signal cout0 : std_logic;                                       
signal reg_vmp0 : std_logic_vector(WIDTH-1 downto 0);            

begin                                                               

  forgen1 : for i in 0 to WIDTH-1 generate
    zero(i) <= '0';                       
  end generate;                           

  process(clk) begin                                              
    if(clk'event and clk='1') then                                
      if(run1 = '1') then                                         
        reg_vmp0 <= addout;                                       
      else                                                        
        if(run = '1') then                                        
          reg_vmp0 <= zero;                                       
        end if;                                                   
      end if;                                                     
    end if;                                                       
  end process;                                                    
  reg0 <= reg_vmp0;                                               

    sx <= reg_vmp0;

  forgen2 : for i in 0 to WIDTH-2 generate
    zeros(i) <= '0';                      
  end generate;                           

  process(sx,cin,addsub,indata) begin
    if(addsub='1') then
      sum <= sx+indata+(zeros&cin);
    else
      sum <= sx-indata-(zeros&cin);
    end if;
  end process;
  addout <= sum;

  process(clk) begin              
    if(clk'event and clk='1') then
      run1 <= run;                
    end if;                       
  end process;                    

--process(clk) begin              
--  if(clk'event and clk='1') then
--    addsubd <= addsub;          
--    cout <= cout0;              
--    countd <= count;            
--  end if;                       
--end process;                    

--rund <= run1;

end rtl;                            
                                    

library ieee;
use ieee.std_logic_1164.all;

entity pg_pdelay_17_3 is
  port( x : in std_logic_vector(16 downto 0);
	   y : out std_logic_vector(16 downto 0);
	   clk : in std_logic);
end pg_pdelay_17_3;

architecture rtl of pg_pdelay_17_3 is

  signal x0 : std_logic_vector(16 downto 0);
  signal x1 : std_logic_vector(16 downto 0);
  signal x2 : std_logic_vector(16 downto 0);
  signal x3 : std_logic_vector(16 downto 0);

begin

  x0 <= x;

  process(clk) begin
    if(clk'event and clk='1') then
      x3 <= x2;
      x2 <= x1;
      x1 <= x0;
    end if;
  end process;

  y <= x3;

end rtl;

library ieee;
use ieee.std_logic_1164.all;

entity pg_pdelay_17_12 is
  port( x : in std_logic_vector(16 downto 0);
	   y : out std_logic_vector(16 downto 0);
	   clk : in std_logic);
end pg_pdelay_17_12;

architecture rtl of pg_pdelay_17_12 is

  signal x0 : std_logic_vector(16 downto 0);
  signal x1 : std_logic_vector(16 downto 0);
  signal x2 : std_logic_vector(16 downto 0);
  signal x3 : std_logic_vector(16 downto 0);
  signal x4 : std_logic_vector(16 downto 0);
  signal x5 : std_logic_vector(16 downto 0);
  signal x6 : std_logic_vector(16 downto 0);
  signal x7 : std_logic_vector(16 downto 0);
  signal x8 : std_logic_vector(16 downto 0);
  signal x9 : std_logic_vector(16 downto 0);
  signal x10 : std_logic_vector(16 downto 0);
  signal x11 : std_logic_vector(16 downto 0);
  signal x12 : std_logic_vector(16 downto 0);

begin

  x0 <= x;

  process(clk) begin
    if(clk'event and clk='1') then
      x12 <= x11;
      x11 <= x10;
      x10 <= x9;
      x9 <= x8;
      x8 <= x7;
      x7 <= x6;
      x6 <= x5;
      x5 <= x4;
      x4 <= x3;
      x3 <= x2;
      x2 <= x1;
      x1 <= x0;
    end if;
  end process;

  y <= x12;

end rtl;

library ieee;
use ieee.std_logic_1164.all;

entity pg_pdelay_17_10 is
  port( x : in std_logic_vector(16 downto 0);
	   y : out std_logic_vector(16 downto 0);
	   clk : in std_logic);
end pg_pdelay_17_10;

architecture rtl of pg_pdelay_17_10 is

  signal x0 : std_logic_vector(16 downto 0);
  signal x1 : std_logic_vector(16 downto 0);
  signal x2 : std_logic_vector(16 downto 0);
  signal x3 : std_logic_vector(16 downto 0);
  signal x4 : std_logic_vector(16 downto 0);
  signal x5 : std_logic_vector(16 downto 0);
  signal x6 : std_logic_vector(16 downto 0);
  signal x7 : std_logic_vector(16 downto 0);
  signal x8 : std_logic_vector(16 downto 0);
  signal x9 : std_logic_vector(16 downto 0);
  signal x10 : std_logic_vector(16 downto 0);

begin

  x0 <= x;

  process(clk) begin
    if(clk'event and clk='1') then
      x10 <= x9;
      x9 <= x8;
      x8 <= x7;
      x7 <= x6;
      x6 <= x5;
      x5 <= x4;
      x4 <= x3;
      x3 <= x2;
      x2 <= x1;
      x1 <= x0;
    end if;
  end process;

  y <= x10;

end rtl;

library ieee;
use ieee.std_logic_1164.all;

entity pg_pdelay_17_14 is
  port( x : in std_logic_vector(16 downto 0);
	   y : out std_logic_vector(16 downto 0);
	   clk : in std_logic);
end pg_pdelay_17_14;

architecture rtl of pg_pdelay_17_14 is

  signal x0 : std_logic_vector(16 downto 0);
  signal x1 : std_logic_vector(16 downto 0);
  signal x2 : std_logic_vector(16 downto 0);
  signal x3 : std_logic_vector(16 downto 0);
  signal x4 : std_logic_vector(16 downto 0);
  signal x5 : std_logic_vector(16 downto 0);
  signal x6 : std_logic_vector(16 downto 0);
  signal x7 : std_logic_vector(16 downto 0);
  signal x8 : std_logic_vector(16 downto 0);
  signal x9 : std_logic_vector(16 downto 0);
  signal x10 : std_logic_vector(16 downto 0);
  signal x11 : std_logic_vector(16 downto 0);
  signal x12 : std_logic_vector(16 downto 0);
  signal x13 : std_logic_vector(16 downto 0);
  signal x14 : std_logic_vector(16 downto 0);

begin

  x0 <= x;

  process(clk) begin
    if(clk'event and clk='1') then
      x14 <= x13;
      x13 <= x12;
      x12 <= x11;
      x11 <= x10;
      x10 <= x9;
      x9 <= x8;
      x8 <= x7;
      x7 <= x6;
      x6 <= x5;
      x5 <= x4;
      x4 <= x3;
      x3 <= x2;
      x2 <= x1;
      x1 <= x0;
    end if;
  end process;

  y <= x14;

end rtl;

--+-------------------------------+
--| PG_LCELL/PG_LCELL_ARI         |
--| For Xilinx Devices            |
--| Multidevice Logic Cell Module |.GKey:hYj8zgUkjgdkfhB3ozXM
--| 2004/02/06                    |
--|            by Tsuyoshi Hamada |
--+-------------------------------+
--+-------------+----------+
--| x3,x2,x1,x0 |    z     |
--+-------------+----------+
--|  0, 0, 0, 0 | MASK(0)  |
--|  0, 0, 0, 1 | MASK(1)  |
--|  0, 0, 1, 0 | MASK(2)  |
--|  0, 0, 1, 1 | MASK(3)  |
--|  0, 1, 0, 0 | MASK(4)  |
--|  0, 1, 0, 1 | MASK(5)  |
--|  .......... | .......  |
--|  1, 1, 1, 1 | MASK(16) |
--+-------------+----------+
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
LIBRARY UNISIM;
USE UNISIM.Vcomponents.ALL;
entity pg_lcell is
  generic(MASK: bit_vector  := X"ffff";
            FF: integer := 0);
    port(x : in std_logic_vector(3 downto 0);
         z : out std_logic;
         clk : in std_logic);
end pg_lcell;

architecture schematic of pg_lcell is
   ATTRIBUTE BOX_TYPE : STRING;
   ATTRIBUTE INIT : STRING ;
   COMPONENT LUT4
   GENERIC( INIT : BIT_VECTOR := X"0000");
      PORT ( I0	:	IN	STD_LOGIC;
             I1	:	IN	STD_LOGIC;
             I2	:	IN	STD_LOGIC;
             I3	:	IN	STD_LOGIC;
             O	:	OUT	STD_LOGIC);
   END COMPONENT;
   ATTRIBUTE BOX_TYPE OF LUT4 : COMPONENT IS "BLACK_BOX";

   signal z0 : std_logic;

BEGIN

   xlcell : LUT4 GENERIC MAP (INIT => MASK)
      PORT MAP (I0=>x(0), I1=>x(1), I2=>x(2), I3=>x(3), O=>z0);

-- unreged output
ifgen0: if (FF=0) generate
  z <= z0;
end generate;

-- reged output
ifgen1: if (FF>0) generate
  process(clk) begin
    if(clk'event and clk='1') then
      z <= z0;
    end if;
  end process;
end generate;

end schematic;

--
-- PGR: Pipeline-processors Generator for Reconfigurable Systems
-- Copyright(c) 2004 by Tsuyoshi Hamada & Naohito Nakasato.
-- All rights reserved.
-- Generated from 'list.ln17man8cut6.pgpp'
-- NPIPE : 2
-- NVMP  : 1
-- Target Platform : TD-BD-BIOLER3
--                    - 64/66 PCI DMA : Enable
--                    - 100MHz Pipe   : Enable
library ieee;
use ieee.std_logic_1164.all;

entity pg_pipe is
  generic(JDATA_WIDTH : integer := 312;
          IDATA_WIDTH : integer := 64);
  port(
    p_jdata : in std_logic_vector(JDATA_WIDTH-1 downto 0);
    p_run : in std_logic;
    p_we :  in std_logic;
    p_adri : in std_logic_vector(11 downto 0);
    p_datai : in std_logic_vector(IDATA_WIDTH-1 downto 0);
    p_adro : in std_logic_vector(11 downto 0);
    p_datao : out std_logic_vector(IDATA_WIDTH-1 downto 0);
    p_runret : out std_logic;
    clk  : in std_logic;
    pclk : in std_logic;
    pipe_sts : in std_logic;            -- xd1
    rst  : in std_logic
  );
end pg_pipe;

architecture std of pg_pipe is

  component pipe
    generic(JDATA_WIDTH : integer;
            IDATA_WIDTH : integer);
    port(
      p_jdata: in std_logic_vector(JDATA_WIDTH-1 downto 0);
      p_run : in std_logic;
      p_we : in std_logic;
      p_adri : in std_logic_vector(3 downto 0);
      p_adrivp : in std_logic_vector(3 downto 0);
      p_datai : in std_logic_vector(IDATA_WIDTH-1 downto 0);
      p_adro : in std_logic_vector(3 downto 0);
      p_adrovp : in std_logic_vector(3 downto 0);
      p_datao : out std_logic_vector(IDATA_WIDTH-1 downto 0);
      p_runret : out std_logic;
      rst,pclk,clk : in std_logic );
  end component;

  signal u_adri,u_adro: std_logic_vector(7 downto 0);
  signal adrivp,adrovp: std_logic_vector(3 downto 0);
  signal we,runret: std_logic_vector(1 downto 0);
  signal datao: std_logic_vector(127 downto 0);
  signal l_adro: std_logic_vector(3 downto 0);
  constant pipe_sts_z : std_logic_vector(IDATA_WIDTH-1 downto 1) := (others=>'0'); -- xd1

begin

  u_adri <= p_adri(11 downto 4);

  u_adro <= p_adro(11 downto 4);
  l_adro <= p_adro(3 downto 0);

  process(u_adri,p_we) begin
    if(p_we = '1') then
     if(u_adri = "00000000" ) then
        we(0) <= '1';
      else
        we(0) <= '0';
      end if;
    else
      we(0) <= '0';
    end if;
  end process;

  process(u_adri,p_we) begin
    if(p_we = '1') then
     if(u_adri = "00000001" ) then
        we(1) <= '1';
      else
        we(1) <= '0';
      end if;
    else
      we(1) <= '0';
    end if;
  end process;

  with u_adri select
    adrivp <= "0000" when "00000000", 
              "0000" when "00000001", 
              "0000" when others;

  with u_adro select
    adrovp <= "0000" when "00000000", 
              "0000" when "00000001", 
              "0000" when others;

  forgen1: for i in 0 to 1 generate
    upipe: pipe GENERIC MAP(JDATA_WIDTH=>JDATA_WIDTH,
                            IDATA_WIDTH=>IDATA_WIDTH)
	      PORT MAP(p_jdata=>p_jdata, p_run=>p_run,
                 p_we=>we(i),p_adri=>p_adri(3 downto 0),p_adrivp=>adrivp,
	               p_datai=>p_datai,p_adro=>l_adro,p_adrovp=>adrovp, 
	               p_datao=>datao(IDATA_WIDTH*(i+1)-1 downto IDATA_WIDTH*i), p_runret=>runret(i), 
		       rst=>rst,pclk=>pclk,clk=>clk);
  end generate forgen1;

  p_runret <= runret(0);

  with u_adro select
    p_datao <= datao(IDATA_WIDTH-1 downto 0) when "00000000", 
               datao(((IDATA_WIDTH*2)-1) downto (IDATA_WIDTH*1)) when "00000001", 
               pipe_sts_z & pipe_sts         when others;  -- xd1

end std;

library ieee;
use ieee.std_logic_1164.all;

entity pipe is
  generic(JDATA_WIDTH : integer := 312;
          IDATA_WIDTH : integer := 64);
port(p_jdata : in std_logic_vector(JDATA_WIDTH-1 downto 0);
     p_run : in std_logic;
     p_we :  in std_logic;
     p_adri : in std_logic_vector(3 downto 0);
     p_adrivp : in std_logic_vector(3 downto 0);
     p_datai : in std_logic_vector(IDATA_WIDTH-1 downto 0);
     p_adro : in std_logic_vector(3 downto 0);
     p_adrovp : in std_logic_vector(3 downto 0);
     p_datao : out std_logic_vector(IDATA_WIDTH-1 downto 0);
     p_runret : out std_logic;
     rst,pclk,clk : in std_logic);
end pipe;

architecture std of pipe is

  component pg_fix_sub_32_1
    port(x,y : in std_logic_vector(31 downto 0);
         z : out std_logic_vector(31 downto 0);
         clk : in std_logic);
  end component;

  component pg_conv_ftol_32_17_8_2
    port(fixdata : in std_logic_vector(31 downto 0);
         logdata : out std_logic_vector(16 downto 0);
         clk : in std_logic);
  end component;

  component pg_log_shift_1                        
    generic (PG_WIDTH: integer);                           
    port( x : in std_logic_vector(PG_WIDTH-1 downto 0);    
	     y : out std_logic_vector(PG_WIDTH-1 downto 0);  
	     clk: in std_logic);                             
  end component;                                           
                                                           
  component pg_log_unsigned_add_itp_17_8_6_4
    port( x,y : in std_logic_vector(16 downto 0);
          z : out std_logic_vector(16 downto 0);
          clock : in std_logic);
  end component;

  component pg_log_shift_m1                        
    generic (PG_WIDTH: integer);                           
    port( x : in std_logic_vector(PG_WIDTH-1 downto 0);    
	     y : out std_logic_vector(PG_WIDTH-1 downto 0);  
	     clk: in std_logic);                             
  end component;                                           
                                                           
  component pg_log_mul_17_1
    port( x,y : in std_logic_vector(16 downto 0);
            z : out std_logic_vector(16 downto 0);  
          clk : in std_logic);
  end component;

  component pg_log_div_17_1
    port( x,y : in std_logic_vector(16 downto 0);
            z : out std_logic_vector(16 downto 0);  
          clk : in std_logic);
  end component;

  component pg_log_sdiv_17_1
    port( x,y : in std_logic_vector(16 downto 0);
            z : out std_logic_vector(16 downto 0);  
          clk : in std_logic);
  end component;

  component pg_conv_ltof_17_8_57_2      
    port(logdata : in std_logic_vector(16 downto 0);
	     fixdata : out std_logic_vector(56 downto 0);
	     clk : in std_logic);
  end component;
                                                                  
  component pg_fix_accum_57_64_1
    port (fdata: in std_logic_vector(56 downto 0);
          sdata: out std_logic_vector(63 downto 0);
          run: in std_logic;
          clk: in std_logic);
  end component;

  component pg_pdelay_17_3
    port( x : in std_logic_vector(16 downto 0);
	        y : out std_logic_vector(16 downto 0);
	       clk: in std_logic);
  end component;

  component pg_pdelay_17_12
    port( x : in std_logic_vector(16 downto 0);
	        y : out std_logic_vector(16 downto 0);
	       clk: in std_logic);
  end component;

  component pg_pdelay_17_10
    port( x : in std_logic_vector(16 downto 0);
	        y : out std_logic_vector(16 downto 0);
	       clk: in std_logic);
  end component;

  component pg_pdelay_17_14
    port( x : in std_logic_vector(16 downto 0);
	        y : out std_logic_vector(16 downto 0);
	       clk: in std_logic);
  end component;

  signal xi_0: std_logic_vector(31 downto 0);
  signal xj_0: std_logic_vector(31 downto 0);
  signal xi_1: std_logic_vector(31 downto 0);
  signal xj_1: std_logic_vector(31 downto 0);
  signal xi_2: std_logic_vector(31 downto 0);
  signal xj_2: std_logic_vector(31 downto 0);
  signal xij_0: std_logic_vector(31 downto 0);
  signal xij_1: std_logic_vector(31 downto 0);
  signal xij_2: std_logic_vector(31 downto 0);
  signal dx_0: std_logic_vector(16 downto 0);
  signal dx_1: std_logic_vector(16 downto 0);
  signal dx_2: std_logic_vector(16 downto 0);
  signal x2_0: std_logic_vector(16 downto 0);
  signal x2_1: std_logic_vector(16 downto 0);
  signal x2_2: std_logic_vector(16 downto 0);
  signal ieps2r: std_logic_vector(16 downto 0);
  signal x2y2: std_logic_vector(16 downto 0);
  signal z2e2: std_logic_vector(16 downto 0);
  signal r2: std_logic_vector(16 downto 0);
  signal r1: std_logic_vector(16 downto 0);
  signal mjr: std_logic_vector(16 downto 0);
  signal r3: std_logic_vector(16 downto 0);
  signal mf: std_logic_vector(16 downto 0);
  signal dx_0r: std_logic_vector(16 downto 0);
  signal dx_1r: std_logic_vector(16 downto 0);
  signal dx_2r: std_logic_vector(16 downto 0);
  signal fx_0: std_logic_vector(16 downto 0);
  signal f_shiftr2: std_logic_vector(16 downto 0);
  signal fx_1: std_logic_vector(16 downto 0);
  signal f_shiftr: std_logic_vector(16 downto 0);
  signal fx_2: std_logic_vector(16 downto 0);
  signal f_shiftr1: std_logic_vector(16 downto 0);
  signal fxs_0: std_logic_vector(16 downto 0);    
  signal fxs_1: std_logic_vector(16 downto 0);    
  signal fxs_2: std_logic_vector(16 downto 0);    
  signal ffx_0: std_logic_vector(56 downto 0);
  signal sx_0: std_logic_vector(63 downto 0);
  signal ffx_1: std_logic_vector(56 downto 0);
  signal sx_1: std_logic_vector(63 downto 0);
  signal ffx_2: std_logic_vector(56 downto 0);
  signal sx_2: std_logic_vector(63 downto 0);
  signal ieps2: std_logic_vector(16 downto 0);
  signal mj: std_logic_vector(16 downto 0);
  signal f_shift: std_logic_vector(16 downto 0);
-- pg_rundelay(18)
  signal run: std_logic_vector(22 downto 0);
  signal ireg_xi_0: std_logic_vector(31 downto 0);
  signal ireg_xi_1: std_logic_vector(31 downto 0);
  signal ireg_xi_2: std_logic_vector(31 downto 0);
  signal ireg_ieps2: std_logic_vector(16 downto 0);

begin

  f_shift(16 downto 0) <= "01001011100000000";

  xj_0(31 downto 0) <= p_jdata(31 downto 0);
  xj_1(31 downto 0) <= p_jdata(63 downto 32);
  xj_2(31 downto 0) <= p_jdata(95 downto 64);
  mj(16 downto 0) <= p_jdata(112 downto 96);

  process(clk) begin
    if(clk'event and clk='1') then
      if(p_we ='1') then
        if(p_adri = "0000") then
          ireg_xi_0 <= p_datai(31 downto 0);
          ireg_xi_1 <= p_datai(63 downto 32);
        elsif(p_adri = "0001") then
          ireg_xi_2 <= p_datai(31 downto 0);
          ireg_ieps2 <= p_datai(48 downto 32);
        end if;
      end if;
    end if;
  end process;

  process(pclk) begin
    if(pclk'event and pclk='1') then
      xi_0 <= ireg_xi_0;
      xi_1 <= ireg_xi_1;
      xi_2 <= ireg_xi_2;
      ieps2 <= ireg_ieps2;
    end if;
  end process;

  u0: pg_fix_sub_32_1
       port map (x=>xi_0,y=>xj_0,z=>xij_0,clk=>pclk);

  u1: pg_fix_sub_32_1
       port map (x=>xi_1,y=>xj_1,z=>xij_1,clk=>pclk);

  u2: pg_fix_sub_32_1
       port map (x=>xi_2,y=>xj_2,z=>xij_2,clk=>pclk);

  u3: pg_conv_ftol_32_17_8_2 port map (fixdata=>xij_0,logdata=>dx_0,clk=>pclk);

  u4: pg_conv_ftol_32_17_8_2 port map (fixdata=>xij_1,logdata=>dx_1,clk=>pclk);

  u5: pg_conv_ftol_32_17_8_2 port map (fixdata=>xij_2,logdata=>dx_2,clk=>pclk);

  u6: pg_log_shift_1 generic map(PG_WIDTH=>17)       
                    port map(x=>dx_0,y=>x2_0,clk=>pclk);         
                                                                  
  u7: pg_log_shift_1 generic map(PG_WIDTH=>17)       
                    port map(x=>dx_1,y=>x2_1,clk=>pclk);         
                                                                  
  u8: pg_log_shift_1 generic map(PG_WIDTH=>17)       
                    port map(x=>dx_2,y=>x2_2,clk=>pclk);         
                                                                  
  u9: pg_log_unsigned_add_itp_17_8_6_4
            port map(x=>x2_0,y=>x2_1,z=>x2y2,clock=>pclk);

  u10: pg_log_unsigned_add_itp_17_8_6_4
            port map(x=>x2_2,y=>ieps2r,z=>z2e2,clock=>pclk);

  u11: pg_log_unsigned_add_itp_17_8_6_4
            port map(x=>x2y2,y=>z2e2,z=>r2,clock=>pclk);

  u12: pg_log_shift_m1 generic map(PG_WIDTH=>17)       
                    port map(x=>r2,y=>r1,clk=>pclk);         
                                                                  
  u13: pg_log_mul_17_1 port map(x=>r2,y=>r1,z=>r3,clk=>pclk);

  u14: pg_log_div_17_1 port map(x=>mjr,y=>r3,z=>mf,clk=>pclk);

  u15: pg_log_mul_17_1 port map(x=>mf,y=>dx_0r,z=>fx_0,clk=>pclk);

  u16: pg_log_mul_17_1 port map(x=>mf,y=>dx_1r,z=>fx_1,clk=>pclk);

  u17: pg_log_mul_17_1 port map(x=>mf,y=>dx_2r,z=>fx_2,clk=>pclk);

  u18: pg_log_sdiv_17_1 port map(x=>fx_0,y=>f_shiftr2,z=>fxs_0,clk=>pclk);

  u19: pg_log_sdiv_17_1 port map(x=>fx_1,y=>f_shiftr,z=>fxs_1,clk=>pclk);

  u20: pg_log_sdiv_17_1 port map(x=>fx_2,y=>f_shiftr1,z=>fxs_2,clk=>pclk);

  u21: pg_conv_ltof_17_8_57_2 port map (logdata=>fxs_0,fixdata=>ffx_0,clk=>pclk);

  u22: pg_conv_ltof_17_8_57_2 port map (logdata=>fxs_1,fixdata=>ffx_1,clk=>pclk);

  u23: pg_conv_ltof_17_8_57_2 port map (logdata=>fxs_2,fixdata=>ffx_2,clk=>pclk);

  u24: pg_fix_accum_57_64_1 port map(fdata=>ffx_0,sdata=>sx_0,run=>run(16),clk=>pclk);

  u25: pg_fix_accum_57_64_1 port map(fdata=>ffx_1,sdata=>sx_1,run=>run(16),clk=>pclk);

  u26: pg_fix_accum_57_64_1 port map(fdata=>ffx_2,sdata=>sx_2,run=>run(16),clk=>pclk);

  u27: pg_pdelay_17_3 port map(x=>ieps2,y=>ieps2r,clk=>pclk);

  u28: pg_pdelay_17_12 port map(x=>mj,y=>mjr,clk=>pclk);

  u29: pg_pdelay_17_10 port map(x=>dx_0,y=>dx_0r,clk=>pclk);

  u30: pg_pdelay_17_10 port map(x=>dx_1,y=>dx_1r,clk=>pclk);

  u31: pg_pdelay_17_10 port map(x=>dx_2,y=>dx_2r,clk=>pclk);

  u32: pg_pdelay_17_14 port map(x=>f_shift,y=>f_shiftr,clk=>pclk);

  u33: pg_pdelay_17_14 port map(x=>f_shift,y=>f_shiftr1,clk=>pclk);

  u34: pg_pdelay_17_14 port map(x=>f_shift,y=>f_shiftr2,clk=>pclk);

  process(pclk) begin
    if(pclk'event and pclk='1') then
      run(0) <= p_run;
      for i in 0 to 21 loop
        run(i+1) <= run(i);
      end loop;
    end if;
  end process;

  process(pclk) begin
    if(pclk'event and pclk='1') then
      p_runret <= run(22) or run(21) or run(20) or run(19);
    end if;
  end process;

  process(clk) begin
    if(clk'event and clk='1') then
      case (p_adro) is
      when "0000" => 
        p_datao <=  sx_0;
      when "0001" => 
        p_datao <=  sx_1;
      when others => 
        p_datao <=  sx_2;
      end case;
    end if;
  end process;

end std;

-- PGR ALLCORE
-- by Tsuyoshi Hamada
-- Last Modified at 2005/01/02
-- Last Modified at 2004/11/20
--
-- SYS_CLK   __~~ __~~ __~~ __~~ __~~ __~~ __~~ __~~ __~~ __
-- WE        __/~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\____
--(WRITE)
-- ADR         < 0 >< 1 >< 2 >< 3 >< 4 >< 5 >< 6 >< 7 >
-- DTI         < 0 >< 1 >< 2 >< 3 >< 4 >< 5 >< 6 >< 7 >
--(READ)
-- ADR         < 0 >< 1 >< 2 >< 3 >< 4 >< 5 >< 6 >< 7 >
-- DTO              < 0 >< 1 >< 2 >< 3 >< 4 >< 5 >< 6 >< 7 >


library ieee;
LIBRARY UNISIM;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
USE UNISIM.Vcomponents.ALL;

entity pgpg_mem is
  port (
    RST           : in  std_logic;
    SYS_CLK       : in  std_logic;
    PIPE_CLK      : in  std_logic;
    ADR           : in  std_logic_vector(18 downto 0);
    WE            : in  std_logic;
    DTI           : in  std_logic_vector(63 downto 0);
    DTO           : out std_logic_vector(63 downto 0);
--    STS           : out std_logic;    -- xd1
    FPGA_NO       : in std_logic_vector(1 downto 0));
end pgpg_mem;

architecture RTL of pgpg_mem is

component adr_dec
  port (
    clk        : in std_logic;
    adr        : in std_logic_vector(18 downto 0);
    is_jpw     : out std_logic;
    is_ipw     : out std_logic;
    is_fo      : out std_logic;
    is_setn    : out std_logic;
    is_run     : out std_logic;
    FPGA_NO    : in std_logic_vector(1 downto 0));
end component;

component pipe_sts
  port (
    rst        : in  std_logic;
    clk        : in  std_logic;
    run        : in  std_logic;
    runret     : in  std_logic;
    status     : out std_logic_vector(31 downto 0));
end component;

component calc is
  port (
    start      : in  std_logic;
    clk        : in  std_logic;
    pclk       : in  std_logic;
    n          : in  std_logic_vector(31 downto 0);
    run        : out  std_logic;
    mem_adr    : out  std_logic_vector(31 downto 0));
end component;

component setn
  port (
    clk       : in std_logic;
    we        : in std_logic;
    idata     : in std_logic_vector(31 downto 0);
    odata     : out std_logic_vector(31 downto 0));
end component;

component jmem
  port (
    wadr        : in  std_logic_vector(15 downto 0);
    wclk        : in  std_logic;
    radr        : in  std_logic_vector(15 downto 0);
    rclk        : in  std_logic;
    rst        : in  std_logic; -- not used
    we         : in  std_logic;
    idata      : in  std_logic_vector(63 downto 0);
    odata      : out  std_logic_vector(127 downto 0));  -- for G5            (JDIM 4)
--  odata      : out  std_logic_vector(255 downto 0));  -- for SPH 1st stage (JDIM 8)
--  odata      : out  std_logic_vector(511 downto 0));  -- for SPH 2nd stage (JDIM 16)
end component;

-- pg_pipe
component pg_pipe
  generic(JDATA_WIDTH : integer := 384;
          IDATA_WIDTH : integer := 64  );
  port(
    p_jdata : in std_logic_vector(JDATA_WIDTH-1 downto 0);
    p_run : in std_logic;
    p_we :  in std_logic;
    p_adri : in std_logic_vector(11 downto 0);
    p_datai : in std_logic_vector(IDATA_WIDTH-1 downto 0);
    p_adro : in std_logic_vector(11 downto 0);
    p_datao : out std_logic_vector(IDATA_WIDTH-1 downto 0);
    p_runret : out std_logic;
--  aclk : in std_logic;                -- for pg_float_accum
    rst,pclk,clk,pipe_sts : in std_logic); -- xd1
end component;

-- adr_dec
signal is_jpw : std_logic;
signal is_ipw : std_logic;
signal is_fo  : std_logic;
signal is_setn : std_logic;
signal is_run : std_logic;

-- pipe_sts
signal p_runret  : std_logic;
signal odata_sts : std_logic_vector(31 downto 0);

-- calc
signal calc_we : std_logic;
signal calc_jadr : std_logic_vector(31 downto 0);
signal p_run : std_logic;

-- setn
signal setn_we : std_logic;
signal odata_setn : std_logic_vector(31 downto 0);

-- fo
signal odata_fo : std_logic_vector(63 downto 0);
signal p_adro   : std_logic_vector(11 downto 0);

-- ipw
signal p_we    : std_logic;
signal p_adri : std_logic_vector(11 downto 0);

-- jmem
signal jmem_d : std_logic_vector(127 downto 0);  -- for G5
--signal jmem_d : std_logic_vector(255 downto 0);  -- for SHP 1st Stage
--signal jmem_d : std_logic_vector(511 downto 0);  -- for SHP 2nd Stage
signal jpw_we : std_logic;
signal jmem_adr : std_logic_vector(63 downto 0);
signal jmem_adr_outside : std_logic_vector(15 downto 0);


signal idata : std_logic_vector(63 downto 0);
signal clk : std_logic;
signal pclk : std_logic;
constant zero32 : std_logic_vector(31 downto 0) := (others=>'0');
signal ADR_ff : std_logic_vector(18 downto 0) := (others=>'0');
signal odata_jmem : std_logic_vector(63 downto 0) := (others=>'0');

-- DEBUG ---------------------------------------------
signal debug_p_jdata : std_logic_vector(511 downto 0);
constant c_zero : std_logic_vector(1023 downto 0) := (others=>'0');
------------------------------------------------------

begin

clk  <= SYS_CLK;
pclk <= PIPE_CLK;
--pclk <= SYS_CLK;

idata <= DTI;

-- calc status
--process(clk) begin                   -- xd1
--  if(clk'event and clk='1') then
--    STS <= odata_sts(0);
--  end if;
--end process;



----------
-- DTO ---
----------

DTO <= odata_fo;

unit0: adr_dec port map(
    clk=>clk,
    adr=>ADR,
    is_jpw =>is_jpw,  -- jmem
    is_ipw =>is_ipw,  -- ireg
    is_fo  =>is_fo,   -- fo
    is_setn=>is_setn, -- setn
    is_run =>is_run, -- do calc
    FPGA_NO => FPGA_NO);

-------------------------------------------------------------------------------
-- pg_pipe
-------------------------------------------------------------------------------
p_we <= is_ipw and WE;
--- ADR CONVERSION XI ---
p_adri(3 downto 0)  <= '0' & ADR(2 downto 0); --  16 xi       (2004/01/01)
p_adri(10 downto 4) <= ADR(9 downto 3);       -- 128 pipes    (2004/01/01)
p_adri(11)          <= '0';                   -- chipsel mask (2005/01/01)
--- ADR CONVERSION AI ---
p_adro(3 downto 0)  <= '0' & ADR(2 downto 0); --   8 ai       (2004/01/02)
p_adro(10 downto 4) <= ADR(9 downto 3);       -- 128 pipes    (2004/01/02)
p_adro(11)          <= '0';                   -- chipsel mask

unit1 : pg_pipe
    generic map (JDATA_WIDTH =>128,     -- for G5
--  generic map (JDATA_WIDTH =>113,     -- for G5
--  generic map (JDATA_WIDTH =>208,     -- for SPH 1st Stage
--  generic map (JDATA_WIDTH =>384,     -- for SPH 2nd Stage
                 IDATA_WIDTH =>64 )
    port map(
--  p_jdata => jmem_d(73 downto 0),     -- G3
    p_jdata => jmem_d(127 downto 0),    -- G5
--  p_jdata => jmem_d(112 downto 0),    -- G5
--  p_jdata => jmem_d(207 downto 0),    -- SPH 1st Stage
--  p_jdata => jmem_d(383 downto 0),    -- SPH 2nd Stage
    p_run   => p_run,
    p_we    => p_we,
    p_adri  => p_adri,
    p_datai => idata,
    p_adro  => p_adro,
    p_datao => odata_fo,
    p_runret=> p_runret,
    rst => '0',
    pclk => pclk,
    clk =>clk, pipe_sts=>odata_sts(0));-- xd1

-- calc ---------------------------------------------
calc_we <= is_run AND WE;
unit2 : calc port map(
       start   => calc_we,
       clk     => clk,
       pclk    => pclk,
       n       => odata_setn,
       run     => p_run,
       mem_adr => calc_jadr);

-- pipe_sts
unit3 : pipe_sts port map(
           rst => RST,
           clk => pclk,
           run => p_run,
           runret=>p_runret,
           status=>odata_sts);

-- setn access -------------------------------------
setn_we <= is_setn AND WE;
unit8 : setn port map(
       clk=>clk,
       we=>setn_we,
       idata=>idata(31 downto 0),
       odata=>odata_setn);

-- jmem access -------------------------------------
jpw_we <= is_jpw AND WE;

--jmem_adr_outside <= "0" & ADR(14 downto 0);
jmem_adr_outside <= ADR(15 downto 0);


unit9: jmem port map(
    rst=>'0',
    we=>jpw_we,
    wadr=>jmem_adr_outside(15 downto 0),  -- ADDRESS for WRITE 
    wclk=>clk,                            -- CLOCK   for WRITE
    radr => calc_jadr(15 downto 0),       -- ADDRESS for READ 
    rclk=>pclk,                           -- CLOCK   for READ
    idata=>idata,
    odata=>jmem_d);

end rtl;

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;                                        
use ieee.std_logic_unsigned.all;                                    

entity pipe_sts is
  port (
    rst        : in  std_logic;
    clk        : in  std_logic;
    run        : in  std_logic;
    runret     : in  std_logic;
    status     : out std_logic_vector(31 downto 0)
  );
end pipe_sts;

architecture rtl of pipe_sts is
signal sts_reg  : std_logic_vector(7 downto 0) :=X"77";
signal rund,sts : std_logic;
signal cntr : std_logic_vector(7 downto 0);
signal irun : std_logic := '0';

begin

-- clk    ____~~~~____~~~~____~~~~____~~~~__
-- runret _____~~~~~~~~_____________________
-- rund   _____________~~~~~~~~_____________
-- status                      <finish     >

-- status
status(31 downto 8) <= (others=>'0');
process(clk,rst) begin
  if(rst='1') then
    status(7 downto 0) <= (others=>'1');
  elsif(clk'event and clk='1') then
    if((runret='0') AND (rund='1')) then  -- �v�Z�I��
      status(7 downto 0) <= (others=>'1');
    elsif((run='1') AND (irun='0')) then -- �v�Z�J�n
      status(7 downto 0) <= (others=>'0');
    end if;
  end if;
end process;

process(clk) begin
  if(clk'event and clk='1') then
    rund  <= runret;
  end if;
end process;

process(clk) begin
  if(clk'event and clk='1') then
    irun  <= run;
  end if;
end process;


end rtl;
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;                                        
use ieee.std_logic_unsigned.all;                                    

entity setn is
  port (
    clk       : in std_logic;
    we        : in std_logic;
    idata     : in std_logic_vector(31 downto 0);
    odata     : out std_logic_vector(31 downto 0));
end setn;

architecture rtl of setn is
signal nreg :  std_logic_vector(31 downto 0) := "00000000000000000000000000000011"; -- default 3
begin

odata <= nreg;
--odata <= "00000000000000000000000000000011";

process (clk) begin
  if(clk'event and clk='1') then
    if(we = '1') then
      nreg <= idata;
    end if;
  end if;
end process;

end rtl;