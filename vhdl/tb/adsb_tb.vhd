library ieee ;
    use ieee.std_logic_1164.all ;
    use ieee.numeric_std.all ;

library std ;
    use std.textio.all ;

library work ;
    use work.adsb_decoder_p.all ;

entity adsb_tb is
end entity ;

architecture arch of adsb_tb is

    procedure nop( signal clock : in std_logic ; count : natural ) is
    begin
        for i in 1 to count loop
            wait until rising_edge( clock ) ;
        end loop ;
    end procedure ;

    constant Thp            :   time                                := 1.0/16.0e6/2.0 * 1 sec ;
    constant FNAME          :   string                              := "input.dat" ;

    constant NUM_DECODERS   :   positive                            := 8 ;

    signal clock            :   std_logic                           := '1' ;
    signal reset            :   std_logic                           := '1' ;

    signal edge_init        :   std_logic                           := '0' ;
    signal edge_in_power    :   signed(INPUT_POWER_WIDTH-1 downto 0) ;
    signal edge_in_valid    :   std_logic ;

    signal msgs             :   messages_t(NUM_DECODERS-1 downto 0) ;
    signal msgs_valid       :   std_logic_vector(NUM_DECODERS-1 downto 0) ;

begin

    clock <= not clock after Thp ;

    U_adsb_top : entity work.adsb_decoder
      generic map (
        NUM_DECODERS    =>  NUM_DECODERS
      ) port map(
        clock           => clock,
        reset           => reset,

        init            => edge_init,

        in_power        => edge_in_power,
        in_valid        => edge_in_valid,

        debug_rpl       => open,

        out_messages    => msgs,
        out_valid       => msgs_valid
    );

    tb : process
        variable status :   file_open_status ;
        type binfile is file of character ;
        file fin        :   binfile ;
        variable c      :   character ;
        variable i, q   :   integer ;
        variable sample_count : integer := 0 ;
    begin
        nop( clock, 100 ) ;

        reset <= '0' ;
        edge_in_valid <= '0';
        nop( clock, 100 ) ;

        edge_init <= '1' ;
        nop( clock, 1 ) ;
        edge_init <= '0' ;
        nop( clock, 100 ) ;

        -- Open up sample file
        file_open( status, fin, FNAME ) ;
        assert status = OPEN_OK
            report "Could not open file: " & fname
            severity failure ;

        -- Iterate through the file
        while not endfile(fin) loop

            -- Read the 16-bit I sample
            read(fin, c) ;
            i := character'pos(c) ;
            read(fin, c) ;
            i := i + character'pos(c)*256 ;
            read(fin, c) ;

            -- Read the 16-bit Q sample
            q := character'pos(c) ;
            read(fin, c) ;
            q := q + character'pos(c)*256 ;

            -- Handle negative numbers
            if( i > 32767 ) then
                i := i - 65536 ;
            end if ;

            if( q > 32767 ) then
                q := q - 65536 ;
            end if ;

            -- Feed it into the front end
            sample_count := sample_count + 1 ;
            edge_in_power <= to_signed( i*i+q*q, edge_in_power'length) ;
            edge_in_valid <= '1' ;
            nop( clock, 1 ) ;
            edge_in_valid <= '0' ;
            nop( clock, 1 ) ;
        end loop ;

        -- Done with the file, so close it
        file_close( fin ) ;

        -- Wait a little bit
        nop( clock, 1000 ) ;

        report "-- End of Simulation --" severity failure ;
    end process ;

end architecture ;

