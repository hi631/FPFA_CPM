`default_nettype none

module Microcomputer(
	input			clk_50M,
	// SRAM
	output [16:0] 	SRAMAD,
	inout   [7:0]  		SRAMIO,
	output				SRAMCEn,SRAMCE2,SRAMWEn,SRAMOEn,
	// SDCARD
	output 		SD_CS,		// CS
	output 		SD_SCK,		// SCLK
	output 		SD_CMD,		// MOSI
	input  		SD_DAT0,		// MISO
	// I/O
	input				rxd1,rxd2,cts1,cts2,
	output			txd1,txd2,rts1,rts2,
	input    	[0:0]	BTN,
	output	[3:0]	LED
	);

	wire		clk = clk_50M;
	(* KEEP *)wire			n_reset;
	wire			n_WR;
	wire			n_RD;
	wire	[15:0]	cpuAddress;
	wire	[7:0]	cpuDataOut;
	wire	[7:0]	cpuDataIn;

//	wire	[7:0]	internalRam2DataOut;
	wire	[7:0]	basRomData;
	wire	[7:0]	internalRam1DataOut;
	wire	[7:0]	sdCardDataOut;
	wire	[7:0]	interface1DataOut, interface2DataOut;
	wire	[7:0]	interface3DataOut, interface3Datain;
	reg 	[7:0]	interface4DataOut;
	wire	[7:0]	interface4Datain;
	wire	[7:0]	dmramData;
	
	wire			n_memWR;	// :='1';
	wire			n_memRD;	// :='1';

	wire			n_ioWR;	// :='1';
	wire			n_ioRD;	// :='1';
	wire			n_MREQ;	// :='1';
	wire			n_IORQ;	// :='1';	

	wire			n_int1;	// :='1';	
	wire			n_int2;	// :='1';	
	wire			n_internalRam1CS;	// :='1';
	wire			n_internalRam2CS;	// :='1';
	wire			n_externalRamCS;
	wire			n_basRomCS;	// :='1';
	wire			n_sdCardCS;	// :='1';
//	wire			n_interface1CS;	// :='1';
	wire			n_aaronCS;	// :='1';
	wire			n_interface1CS, n_interface2CS;	// :='1';
	wire			n_interface3CS, n_interface4CS;	// :='1';
	wire			n_dmramCS;
	
	wire			locked,clk128,clk32;
	wire			driveLED;
	wire [7:0]  leds,stsout;
	assign n_reset  = locked && BTN[0];
	assign LED = ledf[3:0] | ledf[7:4];
	//assign LED[1]   = cpuClock && cpuClockx1 && cpuClockx2;
	//assign LED[0]   = !driveLED;

	//CPM
	reg 			n_RomActive;	// :='1';
	//CPM
	// Disable ROM if out 38. Re-enable when (asynchronous) reset pressed
	always @(posedge n_ioWR) begin
		if (n_reset == 1'b0) begin
			n_RomActive	<= 1'b0;
		end else //if (rising_edge[n_ioWR]) begin
			if (cpuAddress[7:0] == 8'b00111000) begin	// $38
				n_RomActive	<= 1'b1;
			end
		//end
	end

	clkgen	clkgen_inst (
		.inclk0 (clk_50M), .c0 (cpuClockx2), .locked ( locked ) );
	
  t80s #(	1,	1,	0	) cpu1 (
		.reset_n(n_reset), .clk_n(cpuClock), .wait_n(1'b1),
		.int_n(1'b1), .nmi_n(1'b1), .busrq_n(1'b1), 
		.mreq_n(n_MREQ), .iorq_n(n_IORQ), .rd_n(n_RD), .wr_n(n_WR),
		.a(cpuAddress), .di(cpuDataIn), .do(cpuDataOut) );

	// 8KB BASIC
	Z80_CPM_BASIC_ROM	rom1 (
		.address(cpuAddress[12:0]),
		.clock(clk),
		.q(basRomData)
	);
/*
		InternalRam2K	ram1 (
		.address(cpuAddress[10:0]),
		.clock(clk),
		.data(cpuDataOut),
		.wren( ~(n_memWR | n_internalRam1CS)),
		.q(internalRam1DataOut)
	);
*/
	//  SRAM (external)
	assign	SRAMAD   = {1'b0,cpuAddress[15:0]};
	assign	SRAMIO    = (n_memWR == 1'b0) ? (cpuDataOut) : ({(7 - 0 + 1){1'bZ}});
	assign	SRAMWEn	= n_memWR | n_externalRamCS;
	assign	SRAMOEn	= n_memRD | n_externalRamCS;
	assign	SRAMCEn	= n_externalRamCS ;
	assign	SRAMCE2	= ~SRAMCEn;

	//assign	SRAMAD   = {1'b0,8'h00,ledf};
	//assign	SRAMIO   = ledf;

	bufferedUART	io1 (
		.clk(cpuClock),
		.n_wr(n_interface1CS | n_ioWR), .n_rd(n_interface1CS | n_ioRD),
		.n_int(n_int1), .regSel(cpuAddress[0]),
		.dataIn(cpuDataOut), .dataOut(interface1DataOut),
		.rxClock(serialClock), .txClock(serialClock),
		.rxd(rxd1),	.txd(txd1), .n_cts(1'b0), .n_dcd(1'b0) , .n_rts(rts1) );

	bufferedUART	io2 (
		.clk(clk),
		.n_wr(n_interface2CS | n_ioWR), .n_rd(n_interface2CS | n_ioRD),
		.n_int(n_int2), .regSel(cpuAddress[0]),
		.dataIn(cpuDataOut), .dataOut(interface2DataOut),
		.rxClock(serialClock), .txClock(serialClock),
		.rxd(rxd2), .txd(txd2), .n_cts(1'b0), .n_dcd(1'b0), .n_rts(rts2) );

	sd_controller	sd1 (
		.sdCS(SD_CS),
		.sdMOSI(SD_CMD),
		.sdMISO(SD_DAT0),
		.sdSCLK(SD_SCK),
		.n_wr(n_sdCardCS | n_ioWR),
		.n_rd(n_sdCardCS | n_ioRD),
		.n_reset(n_reset),
		.dataIn(cpuDataOut),
		.dataOut(sdCardDataOut),
		//.stsout(stsout),
		.regAddr(cpuAddress[2:0]),
		.driveLED(driveLED),
		.clk(sdClock)
	);


	assign	n_ioWR	= n_WR | n_IORQ;
	assign	n_memWR	= n_WR | n_MREQ;
	assign	n_ioRD	= n_RD | n_IORQ;
	assign	n_memRD	= n_RD | n_MREQ;

	assign	n_basRomCS	= (cpuAddress[15:13] == 3'b000 && n_RomActive == 1'b0) ? (1'b0) : (1'b1);	//8KB at 0000 - 1FFF
	assign   n_externalRamCS =  ~n_basRomCS;
	//assign	n_internalRam1CS	= (cpuAddress[15:11] == 5'b00100) ? (1'b0) : (1'b1); // 2KB 2000 - 27FF
	assign	n_interface1CS	= (cpuAddress[7:1] == 7'b1000000 && (n_ioWR == 1'b0 || n_ioRD == 1'b0)) ? (1'b0)	: (1'b1); // 2 Bytes $80-$81
	assign	n_interface2CS	= (cpuAddress[7:1] == 7'b1000001 && (n_ioWR == 1'b0 || n_ioRD == 1'b0)) ? (1'b0)	: (1'b1); // 2 Bytes $82-$83
	assign	n_interface3CS	= (cpuAddress[7:2] == 6'b100001 && (n_ioWR == 1'b0 || n_ioRD == 1'b0)) ? (1'b0) : (1'b1);	// 4 Bytes $84-$87(132 -
	assign	n_sdCardCS	= (cpuAddress[7:3] == 5'b10001 && (n_ioWR == 1'b0 || n_ioRD == 1'b0)) ? (1'b0)	: (1'b1); // 8 Bytes $88-$8F
	assign	n_interface4CS	= (cpuAddress[7:1] == 7'b1001000 && (n_ioWR == 1'b0 || n_ioRD == 1'b0)) ? (1'b0)	: (1'b1); // 2 Bytes $90-$91(144 -
	assign	n_aaronCS	= (cpuAddress[7:1] == 7'b1001000 && (n_ioWR == 1'b0 || n_ioRD == 1'b0)) ? (1'b0) : (1'b1);	// 2 Bytes $90-$91

	assign	cpuDataIn	= (n_interface1CS == 1'b0) ? (interface1DataOut)
				: (n_interface2CS == 1'b0) ? (interface2DataOut)
				: (n_interface3CS == 1'b0) ? (interface3Datain)
				: (n_interface4CS == 1'b0) ? (interface4Datain)
				: (n_sdCardCS == 1'b0) ? (sdCardDataOut)
				: (n_basRomCS == 1'b0) ? (basRomData)
				//: (n_internalRam1CS == 1'b0) ? (internalRam1DataOut)
				: (n_externalRamCS  == 1'b0) ? (SRAMIO)
				: (8'hFF);

(* KEEP *)wire 	cpuClock,cpuClockx2;
(* Preserve *)reg	cpuClockx1;
	reg 	[5:0]		cpuClkCount;
	wire	sdClock,serialClock;
	wire 			cpuenable;
//	assign cpuenable = cpuClockx1; // x1
//	assign cpuClock  = cpuClockx1; // x1
	assign cpuenable = 1'b1;       // x2
	assign cpuClock  = cpuClockx2; // x2
	always @(posedge cpuClockx2) begin cpuClockx1 <= !cpuClockx1;	end
	
	reg [15:0]	serialClkCount;
	reg [5:0]	sdClkCount;
	assign sdClock   = cpuClockx1;
	assign	serialClock	= serialClkCount[15];
	
	//assign txd1 = 1'b1;
	
	always @(posedge clk_50M) begin
		//if (cpuClkCount < 2) begin	// 4 = 10MHz, 3 = 12.5MHz, 2=16.6MHz, 1=25MHz
		//	cpuClkCount	<= cpuClkCount + 1; end else begin cpuClkCount	<= {(5 - 0 + 1){1'b0}}; end
		//if (cpuClkCount < 2) begin	// 2 when 10MHz, 2 when 12.5MHz, 2 when 16.6MHz, 1 when 25MHz
		//	cpuClock	<= 1'b0; end else begin cpuClock	<= 1'b1; end
	//	if (sdClkCount < 10) begin sdClkCount <= sdClkCount + 1; end
	//	else 					  begin sdClkCount <= {(5 - 0 + 1){1'b0}}; end
	//	if (sdClkCount < 5) begin sdClock <= 1'b0; end 
	//	else 					  begin sdClock <= 1'b1; end
		// Serial clock // 50MHz master input clock: // Baud Increment
		// 115200 2416	// 38400 805	// 19200 403	// 9600 201	// 4800 101	// 2400 50
		serialClkCount	<= serialClkCount + 2416;
	end

reg[24:0] count;
reg [7:0] ledf;
parameter CNT_MAX = 25'd12500000; //25'd25000000;

always@( posedge clk_50M )
begin
	if( count == CNT_MAX ) begin
		count <= 0; 
		if(ledf[7:0]==8'h00) ledf <= 1;
		else           ledf <= {ledf[6:0],1'b0};
	end else
		count <= count + 1'b1;
end

endmodule
`default_nettype wire
