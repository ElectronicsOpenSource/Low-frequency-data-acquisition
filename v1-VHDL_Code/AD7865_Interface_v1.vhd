----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Felix Vietmeyer
-- 
-- Create Date:    19:19:23 09/06/2014 
-- Design Name: 
-- Module Name:    ADS7818_Interface - Behavioral 
-- Project Name: Test for AD7685 board (v1)
-- Target Devices: Papilio Pro
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 1.0 - File Created
-- Additional Comments: 
-- Currently needs a 20 MHz clock to run at 250 kSPS
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL; 

entity AD7685_Interface_v1 is
    Port ( ADC1_CLK : out  STD_LOGIC := '0';
			  ADC1_DATA : in  STD_LOGIC := '0';
			  ADC1_CONV : out  STD_LOGIC := '1';

			  Trigger_out : out STD_LOGIC := '0';
			  ADC_OUT : out STD_LOGIC_VECTOR(15 downto 0);
				
			  clk : in  STD_LOGIC); --Should be 20 MHz for 250 kSPS
end AD7685_Interface_v1;

architecture Behavioral of AD7685_Interface_v1 is

	signal counter : STD_LOGIC_VECTOR(6 downto 0) := (others => '0');
	signal ADC1value : STD_LOGIC_VECTOR(15 downto 0) := (others => '0'); --16-bit ADC output

begin

	clk_proc: process(clk)
	begin
		if rising_edge(clk) then
			if counter = "1001110" then
					counter <= (others => '1');
			else 
				counter <= counter+1;
			end if;
			
			Trigger_out <= '0';
			
			if counter(0) = '1' then
					ADC1_CLK <= '1';
				else
					ADC1_CLK <= '0';
			end if;
			
			case counter is
				when "0000000" =>
					ADC1_CONV <= '1';
				when "0101101" =>
					ADC1_CONV <= '0';
				when "0101110" =>
					ADC1value(15) <= ADC1_DATA;
				when "0110000" =>
					ADC1value(14) <= ADC1_DATA;
				when "0110001" =>
				when "0110010" =>
					ADC1value(13) <= ADC1_DATA;
				when "0110011" =>
				when "0110100" =>
					ADC1value(12) <= ADC1_DATA;
				when "0110110" =>
					ADC1value(11) <= ADC1_DATA;
				when "0111000" =>
					ADC1value(10) <= ADC1_DATA;
				when "0111010" =>
					ADC1value(9) <= ADC1_DATA;
				when "0111100" =>
					ADC1value(8) <= ADC1_DATA;
				when "0111110" =>
					ADC1value(7) <= ADC1_DATA;
				when "1000000" =>
					ADC1value(6) <= ADC1_DATA;
				when "1000010" =>
					ADC1value(5) <= ADC1_DATA;
				when "1000100" =>
					ADC1value(4) <= ADC1_DATA;
				when "1000110" =>
					ADC1value(3) <= ADC1_DATA;
				when "1001000" =>
					ADC1value(2) <= ADC1_DATA;
				when "1001010" =>
					ADC1value(1) <= ADC1_DATA;
				when "1001100" =>
					ADC1value(0) <= ADC1_DATA;
				when "1001101" =>
					Trigger_out <= '1';
				when others =>
			end case;
		end if;
				
	end process;

ADC_OUT <= ADC1value;
	
end Behavioral;

