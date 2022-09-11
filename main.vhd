    ----------------------------------------------------------------------------------
    -- 
    -- Prova Finale (Progetto di Reti Logiche)
    -- Prof. Fabio Salice - Anno Accademico 2021/2022
    -- 
    -- Roberto Giandomenico (Codice Persona:  Matricola:)
    -- 
    ----------------------------------------------------------------------------------


    LIBRARY IEEE;
    USE IEEE.STD_LOGIC_1164.ALL;
    USE IEEE.NUMERIC_STD.ALL;

    ENTITY project_reti_logiche IS
        PORT (
            i_clk : IN STD_LOGIC;
            i_start : IN STD_LOGIC;
            i_rst : IN STD_LOGIC;
            i_data : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
            o_address : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
            o_done : OUT STD_LOGIC;
            o_en : OUT STD_LOGIC;
            o_we : OUT STD_LOGIC;
            o_data : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
        );
    END project_reti_logiche;

    ARCHITECTURE Behavioral OF project_reti_logiche IS

        --stati della fsm
        TYPE fsm_state IS (
            S00, S01, S10, S11,
            IDLE, W_SAVE,
            WORD_READ_SETUP, WORD_READ,
            RECORD_ENCODED_BIT, UPDATE_BIT_COUNTER,
            CHECK_WORD_END, WRITE_WORD_1, WRITE_WORD_2,
            UPDATE_COUNTER, CHECK_END, DONE
        );

        --registri di stato
        SIGNAL next_state: fsm_state := IDLE;
        SIGNAL curr_state: fsm_state;
        --registro per seguire il codificatore
        SIGNAL encoder_state: fsm_state := S00;
        --registri dove salvare i dati in input
        SIGNAL loaded_word: STD_LOGIC_VECTOR(7 DOWNTO 0);
        SIGNAL words_num: STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
        --registri dove salvare i dati in output
        SIGNAL encoder_output: STD_LOGIC_VECTOR(1 DOWNTO 0) := (OTHERS => '0');
        SIGNAL encoded_word: STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS => '0');
        --contatori delle parole e dei singoli bit di ogni parola
        SIGNAL words_counter: STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
        SIGNAL word_bit_counter: STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '0');

    BEGIN

        main: PROCESS (i_clk, i_rst)
        VARIABLE tmp: INTEGER;
        BEGIN            
            --reset, tutto a 0
            IF (i_rst = '1') THEN
                curr_state <= IDLE;
                next_state <= IDLE;
                encoder_state <= S00;
                encoded_word <= (OTHERS => '0');
                words_counter <= (OTHERS => '0');
                word_bit_counter <= (OTHERS => '0');
                loaded_word <= (OTHERS => '0');
                words_num <= (OTHERS => '0');
                encoder_output <= (OTHERS => '0');

            ELSIF (rising_edge(i_clk)) THEN
                curr_state <= next_state;

                o_en <= '0';
                o_we <= '0';
                o_done <= '0';
                o_data <= (OTHERS => '0');

                CASE curr_state IS

                    --stato di partenza
                    WHEN IDLE =>
                        encoder_state <= S00;
                        encoded_word <= (OTHERS => '0');
                        words_counter <= (OTHERS => '0');
                        word_bit_counter <= (OTHERS => '0');
                        loaded_word <= (OTHERS => '0');
                        words_num <= (OTHERS => '0');
                        encoder_output <= (OTHERS => '0');

                        IF (i_start = '0') THEN
                            next_state <= IDLE;
                        ELSE
                            o_en <= '1';
                            o_we <= '0';
                            o_address <= (OTHERS => '0');
                            next_state <= W_SAVE;
                        END IF;


                    --lettura e salvataggio di W
                    WHEN W_SAVE =>
                        IF (i_data = (i_data'RANGE => '0')) THEN
                            next_state <= DONE;
                        ELSE
                            o_done <= '0';
                            words_num <= i_data;
                            next_state <= WORD_READ_SETUP;
                            
                        END IF;


                    --preaparazione dell'indirizzo per leggere la parola
                    WHEN WORD_READ_SETUP =>
                        o_en <= '1';
                        o_we <= '0';
                        o_address <= (0 TO 7 => '0') & STD_LOGIC_VECTOR(unsigned(words_counter) + 1);
                        encoded_word <= (OTHERS => '0');
                        word_bit_counter <= (OTHERS => '0');
                        
                        next_state <= WORD_READ;


                    --lettura parola
                    WHEN WORD_READ =>
                        loaded_word <= i_data;

                        next_state <= encoder_state;


                    --codificatore stato S00
                    WHEN S00 =>
                        IF (loaded_word(7 - to_integer(unsigned(word_bit_counter))) = '1') THEN
                            encoder_output <= "11";
                            encoder_state <= S10;
                        ELSE
                            encoder_output <= "00";
                            encoder_state <= S00;
                        END IF;
                        
                        next_state <= RECORD_ENCODED_BIT;


                    --codificatore stato S01
                    WHEN S01 =>
                        IF (loaded_word(7 - to_integer(unsigned(word_bit_counter))) = '1') THEN
                            encoder_output <= "00";
                            encoder_state <= S10;
                        ELSE
                            encoder_output <= "11";
                            encoder_state <= S00;
                        END IF;
                        
                        next_state <= RECORD_ENCODED_BIT;


                    --codificatore stato S10
                    WHEN S10 =>
                        IF (loaded_word(7 - to_integer(unsigned(word_bit_counter))) = '1') THEN
                            encoder_output <= "10";
                            encoder_state <= S11;
                        ELSE
                            encoder_output <= "01";
                            encoder_state <= S01;
                        END IF;
                        
                        next_state <= RECORD_ENCODED_BIT;


                    --codificatore stato S11
                    WHEN S11 =>
                        IF (loaded_word(7 - to_integer(unsigned(word_bit_counter))) = '1') THEN
                            encoder_output <= "01";
                            encoder_state <= S11;
                        ELSE
                            encoder_output <= "10";
                            encoder_state <= S01;
                        END IF;
                        
                        next_state <= RECORD_ENCODED_BIT;


                    --copio l'output del codificatore su una parola da 16bit
                    WHEN RECORD_ENCODED_BIT =>
                        encoded_word((15 - to_integer(shift_left(unsigned(word_bit_counter), 1))) DOWNTO (14 - to_integer(shift_left(unsigned(word_bit_counter), 1)))) <= encoder_output;
                        tmp := to_integer(unsigned(word_bit_counter));

                        next_state <= UPDATE_BIT_COUNTER;


                    --aggiornamento contatore dei bit della singola parola
                    WHEN UPDATE_BIT_COUNTER =>                    
                        word_bit_counter <= STD_LOGIC_VECTOR(to_unsigned(tmp + 1, 4));
                        
                        next_state <= CHECK_WORD_END;


                    --controllo se ho codificato abbastanza bit per scrivere in RAM il risultato
                    WHEN CHECK_WORD_END =>
                        IF (to_integer(unsigned(word_bit_counter)) = 4) THEN
                            next_state <= WRITE_WORD_1;
                        ELSIF (to_integer(unsigned(word_bit_counter)) = 8) THEN
                            next_state <= WRITE_WORD_2;
                        ELSE
                            next_state <= encoder_state;
                        END IF;


                    --scrivo prima parte della codifica
                    WHEN WRITE_WORD_1 =>
                        o_en <= '1';
                        o_we <= '1';
                        o_address <= STD_LOGIC_VECTOR(to_unsigned(1000 + to_integer(unsigned(words_counter & '0')), 16));
                        o_data <= encoded_word(15 DOWNTO 8);
                        
                        next_state <= encoder_state;


                    --scrivo seconda parte della codifica
                    WHEN WRITE_WORD_2 =>
                        o_en <= '1';
                        o_we <= '1';
                        o_address <= STD_LOGIC_VECTOR(to_unsigned(1000 + to_integer(unsigned(words_counter & '0')) + 1, 16));
                        o_data <= encoded_word(7 DOWNTO 0);
                        tmp := to_integer(unsigned(words_counter));
                        
                        next_state <= UPDATE_COUNTER;


                    --aggiorno il contatore delle parole totali
                    WHEN UPDATE_COUNTER =>
                        words_counter <= STD_LOGIC_VECTOR(to_unsigned(tmp + 1, 8));
                        
                        next_state <= CHECK_END;


                    --controllo se ci sono altre parole da codificare
                    WHEN CHECK_END =>
                        IF (words_counter = words_num) THEN  
                            o_done <= '1';
                            next_state <= DONE;
                        ELSE
                            o_done <= '0';
                            next_state <= WORD_READ_SETUP;
                        END IF;


                    --stato finale
                    WHEN DONE =>
                        o_done <= '1';

                        IF (i_start = '1') THEN
                            next_state <= DONE;
                        ELSE
                            next_state <= IDLE;
                        END IF;

                END CASE;

            END IF;

        END PROCESS;

    END Behavioral;