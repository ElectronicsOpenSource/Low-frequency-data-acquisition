----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Felix Vietmeyer
-- 
-- Create Date:    17:37:49 09/10/2014 
-- Design Name: 
-- Module Name:    Main module 
-- Project Name: 	Test for AD7685 board (v1)
-- Target Devices: Papilio Pro
-- Tool versions: 14.7
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 1.0 - File Created
-- Additional Comments: 
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.NUMERIC_STD.all;

entity Main_module_v1 is
    Port ( 		  
			  --ADC1
			  ADC1_CLK : out  STD_LOGIC := '0';
			  ADC1_DATA : in  STD_LOGIC := '0';
			  ADC1_CONV : out  STD_LOGIC := '0';	
			
			  --RS_232
			  TX : in STD_LOGIC;
			  RX : out STD_LOGIC;
			  
			  --32 MHz FPGA XTAL
			  clk : in  STD_LOGIC);
end Main_module_v1;

architecture Behavioral of Main_module_v1 is

--Clocks and counters
signal ctr32 : STD_LOGIC_VECTOR(25 downto 0) := (others => '0'); --overflows roughly once every two seconds
signal ctr32_global : STD_LOGIC_VECTOR(43 downto 0) := (others => '0'); --overflows roughly once a week
signal clk32_out : STD_LOGIC;
signal clk20_out : STD_LOGIC;

--ADC1
signal adc1_value : STD_LOGIC_VECTOR(15 downto 0) := (others => '0');
signal adc1_value_hold : STD_LOGIC_VECTOR(15 downto 0) := (others => '0');
signal AD7685_Trigger : STD_LOGIC := '0';


--Buffers for the ADC
type ADC_buf is array (8191 downto 0) of std_logic_vector(15 downto 0); 
signal ADC_Buffer : ADC_buf;
signal ADC_index : integer := 0;

type ADC_buf2 is array (8191 downto 0) of std_logic_vector(7 downto 0); 
signal ADC_Buffer2 : ADC_buf2;
signal ADC_Buffer2_index : std_logic_vector(7 downto 0) := (others => '0');


--RS_232
signal RS232_rx_data : std_logic_vector(7 downto 0) := (others => '0');
signal RS232_tx_data : std_logic_vector(7 downto 0) := (others => '0');
signal RS232_reset : std_logic := '0';
signal RS232_tx_req : std_logic := '0';
signal RS232_rx_req : std_logic := '0';
signal RS232_tx_busy : std_logic := '0';
signal RS232_delay : std_logic_vector(7 downto 0) := (others => '0');


--Some FSMs and flags to control flow
type datatransferstate is (idle, pack1, send1,wait1,pack2,send2,wait2,pack3,send3,wait3);
signal state : datatransferstate := idle;

type ADCstate is (reading,writing,writing2,waiting);
signal ADC_state : ADCstate := writing;

signal ADC_writeflag : std_logic := '0';



component DCM
port
 (-- Clock in ports
  CLK_IN1           : in     std_logic;
  -- Clock out ports
  CLK_OUT1          : out    std_logic;
  CLK_OUT2          : out    std_logic;
  -- Status and control signals
  LOCKED            : out    std_logic
 );
end component;

component AD7685_Interface_v1
port
 (
			  ADC1_CLK : out  STD_LOGIC := '0';
			  ADC1_DATA : in  STD_LOGIC := '0';
			  ADC1_CONV : out  STD_LOGIC := '1';

			  ADC_OUT : out STD_LOGIC_VECTOR(15 downto 0);
			  Trigger_out : out STD_LOGIC := '0';
			  
			  clk : in  STD_LOGIC
 );
end component;

COMPONENT RS232_Interface_v1
	PORT(
		clk : IN std_logic;
		rs232_rxd : IN std_logic;
		rs232_tra_en : IN std_logic;
		rs232_dat_in : IN std_logic_vector(7 downto 0);          
		rs232_txd : OUT std_logic;
		rs232_rec_en : OUT std_logic;
		rs232_txd_busy : OUT std_logic;
		rs232_dat_out : OUT std_logic_vector(7 downto 0)
		);
	END COMPONENT;

begin

DCM_Global : DCM
  port map
   (-- Clock in ports
    CLK_IN1 => clk,
    -- Clock out ports
    CLK_OUT1 => clk32_out,
    CLK_OUT2 => clk20_out,
    -- Status and control signals
    LOCKED => open);  

ADC1: AD7685_Interface_v1 PORT MAP(
		ADC1_CLK => ADC1_CLK,
		ADC1_DATA => ADC1_DATA,
		ADC1_CONV => ADC1_CONV,
		ADC_OUT => adc1_value,
		Trigger_out => AD7685_Trigger,
		clk => clk20_out
	);
	
UART1: RS232_Interface_v1 PORT MAP(
	clk => clk32_out,
	rs232_rxd => TX,
	rs232_tra_en => RS232_tx_req,
	rs232_dat_in => RS232_tx_data,
	rs232_txd => RX,
	rs232_rec_en => RS232_rx_req,
	rs232_txd_busy => RS232_tx_busy,
	rs232_dat_out => RS232_rx_data
);

clk32_proc: process(clk32_out)
begin
if rising_edge(clk32_out) then
	ctr32 <= ctr32+1;
	ctr32_global <= ctr32_global+1;
end if;
end process;

datacq1 : process(clk32_out)
begin

if rising_edge(clk32_out) then
	RS232_tx_req <= '0';
	RS232_reset <= '0';
	
	case ADC_state is
		--write ADC value to buffer until full (8192 entries)
		when writing => 
				ADC_writeflag <= '1';
				if ADC_index = 8192 then
					ADC_state <= reading;
					ADC_index <= 8191;
				elsif AD7685_Trigger = '1' then
					ADC_state <= writing2;
				end if;
		when writing2 =>
				if ADC_writeflag = '1' then
					ADC_buffer(ADC_index) <= adc1_value;
					ADC_buffer2(ADC_index) <= ADC_buffer2_index;
					ADC_buffer2_index <= ADC_buffer2_index + 1;
					ADC_index <= ADC_index + 1;
					ADC_writeflag <= '0';
				elsif AD7685_Trigger = '0' then
					ADC_state <= writing;
				end if;
		--Read from buffer and output on RS232 via USB
		when reading =>
			case state is
				when idle =>
						if ADC_index = -1 then
							ADC_state <= waiting;
						else
						state <= pack1;
						end if;
				when pack1 =>
					RS232_tx_data <= adc1_value_hold(15 downto 8);
					state <= send1;
				when send1 =>
					RS232_tx_req <= '1';
					state <= wait1;
					RS232_delay <= (others => '0');
				when wait1 =>
					if RS232_tx_busy = '0' then
						if RS232_delay = "11111111" then
							state <= pack2;
						else
							RS232_delay <= RS232_delay + 1;
						end if;
					end if;
				when pack2 =>
					RS232_tx_data <= adc1_value_hold(7 downto 0);
					state <= send2;
				when send2 =>
					RS232_tx_req <= '1';
					state <= wait2;
					RS232_delay <= (others => '0');
				when wait2 =>
					if RS232_tx_busy = '0' then
						if RS232_delay = "11111111" then
							state <= pack3;
						else
							RS232_delay <= RS232_delay + 1;
						end if;
					end if;
				when pack3 =>
					RS232_tx_data <= ADC_buffer2(ADC_index);
					state <= send3;
				when send3 =>
					RS232_tx_req <= '1';
					state <= wait3;
					ADC_buffer(ADC_index) <= (others => '0');
					RS232_delay <= (others => '0');
				when wait3 =>
					if RS232_tx_busy = '0' then
						if RS232_delay = "11111111" then
							ADC_index <= ADC_index-1;
							state <= idle;
						else
							RS232_delay <= RS232_delay + 1;
						end if;
					end if;
			end case;
		--wait for a short while after writing one block
		when waiting =>
			if ctr32 = 0 then
				ADC_index <= 0;
				ADC_state <= writing;
			end if;
	end case;
	
end if;
end process;

--Update the ADC value asynchroneously
adc1_value_hold <= ADC_buffer(ADC_index);

end Behavioral;

