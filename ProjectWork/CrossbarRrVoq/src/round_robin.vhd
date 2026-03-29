-------------------------------------------------------------------------------
-- round_robin.vhd
-- Round-Robin Arbiter mit Frame-Lock für einen Ausgangs-MUX
--
-- Zustandsmaschine:
--   IDLE:   Sucht nächsten Eingang mit frame_rdy (ab rr_ptr)
--   LOCKED: Hält sel stabil bis eof kommt, dann zurück zu IDLE
--
-- Signale:
--   frame_rdy(3:0)  IN  — welche VOQs haben einen fertigen Frame
--   eof              IN  — letztes Byte des aktuellen Frames
--   sel(1:0)         OUT — an den Crossbar-MUX
--   grant(3:0)       OUT — one-hot, sagt VOQ dass sie senden darf
--   active           OUT — '1' wenn gerade ein Frame übertragen wird
--
-- 4 Instanzen davon — eine pro Ausgangsport
--
-- DTU Fotonik - FPGA Design for Communications Systems
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity round_robin is
    port (
        clk       : in  std_logic;
        reset     : in  std_logic;

        -- VOQ Status
        frame_rdy : in  std_logic_vector(3 downto 0);  -- welche VOQs bereit
        eof       : in  std_logic;                       -- Ende des Frames

        -- Ausgänge
        sel       : out std_logic_vector(1 downto 0);   -- MUX select
        grant     : out std_logic_vector(3 downto 0);   -- one-hot grant
        active    : out std_logic                        -- Frame wird übertragen
    );
end entity round_robin;

architecture rtl of round_robin is

    type state_t is (IDLE, LOCKED);
    signal state   : state_t;
    signal rr_ptr  : std_logic_vector(1 downto 0);  -- nächste Priorität
    signal sel_reg : std_logic_vector(1 downto 0);  -- aktueller Gewinner

begin

    fsm_proc : process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state   <= IDLE;
                rr_ptr  <= "00";
                sel_reg <= "00";
                grant   <= "0000";
                active  <= '0';

            else
                case state is

                    -------------------------------------------------------
                    -- IDLE: Suche nächsten Eingang mit frame_rdy
                    -- Reihenfolge ab rr_ptr (Round-Robin)
                    -------------------------------------------------------
                    when IDLE =>
                        grant  <= "0000";
                        active <= '0';

                        case rr_ptr is
                            when "00" =>
                                if    frame_rdy(0) = '1' then
                                    sel_reg <= "00"; grant <= "0001";
                                    active <= '1';   state <= LOCKED;
                                elsif frame_rdy(1) = '1' then
                                    sel_reg <= "01"; grant <= "0010";
                                    active <= '1';   state <= LOCKED;
                                elsif frame_rdy(2) = '1' then
                                    sel_reg <= "10"; grant <= "0100";
                                    active <= '1';   state <= LOCKED;
                                elsif frame_rdy(3) = '1' then
                                    sel_reg <= "11"; grant <= "1000";
                                    active <= '1';   state <= LOCKED;
                                end if;

                            when "01" =>
                                if    frame_rdy(1) = '1' then
                                    sel_reg <= "01"; grant <= "0010";
                                    active <= '1';   state <= LOCKED;
                                elsif frame_rdy(2) = '1' then
                                    sel_reg <= "10"; grant <= "0100";
                                    active <= '1';   state <= LOCKED;
                                elsif frame_rdy(3) = '1' then
                                    sel_reg <= "11"; grant <= "1000";
                                    active <= '1';   state <= LOCKED;
                                elsif frame_rdy(0) = '1' then
                                    sel_reg <= "00"; grant <= "0001";
                                    active <= '1';   state <= LOCKED;
                                end if;

                            when "10" =>
                                if    frame_rdy(2) = '1' then
                                    sel_reg <= "10"; grant <= "0100";
                                    active <= '1';   state <= LOCKED;
                                elsif frame_rdy(3) = '1' then
                                    sel_reg <= "11"; grant <= "1000";
                                    active <= '1';   state <= LOCKED;
                                elsif frame_rdy(0) = '1' then
                                    sel_reg <= "00"; grant <= "0001";
                                    active <= '1';   state <= LOCKED;
                                elsif frame_rdy(1) = '1' then
                                    sel_reg <= "01"; grant <= "0010";
                                    active <= '1';   state <= LOCKED;
                                end if;

                            when others =>  -- "11"
                                if    frame_rdy(3) = '1' then
                                    sel_reg <= "11"; grant <= "1000";
                                    active <= '1';   state <= LOCKED;
                                elsif frame_rdy(0) = '1' then
                                    sel_reg <= "00"; grant <= "0001";
                                    active <= '1';   state <= LOCKED;
                                elsif frame_rdy(1) = '1' then
                                    sel_reg <= "01"; grant <= "0010";
                                    active <= '1';   state <= LOCKED;
                                elsif frame_rdy(2) = '1' then
                                    sel_reg <= "10"; grant <= "0100";
                                    active <= '1';   state <= LOCKED;
                                end if;
                        end case;

                    -------------------------------------------------------
                    -- LOCKED: Frame wird übertragen, sel bleibt stabil
                    -- Bei eof: Pointer weiterdrehen, zurück zu IDLE
                    -------------------------------------------------------
                    when LOCKED =>
                        if eof = '1' then
                            -- Pointer auf nächsten nach Gewinner
                            case sel_reg is
                                when "00"   => rr_ptr <= "01";
                                when "01"   => rr_ptr <= "10";
                                when "10"   => rr_ptr <= "11";
                                when others => rr_ptr <= "00";
                            end case;
                            grant  <= "0000";
                            active <= '0';
                            state  <= IDLE;
                        end if;
                        -- sel_reg und grant bleiben stabil solange LOCKED

                end case;
            end if;
        end if;
    end process fsm_proc;

    -- sel Ausgang
    sel <= sel_reg;

end architecture rtl;
