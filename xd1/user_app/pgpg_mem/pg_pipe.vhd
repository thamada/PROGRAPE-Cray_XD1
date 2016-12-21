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

