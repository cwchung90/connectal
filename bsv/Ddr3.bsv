// Copyright (c) 2015 Connectal Project

// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without
// restriction, including without limitation the rights to use, copy,
// modify, merge, publish, distribute, sublicense, and/or sell copies
// of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
// BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
// ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import Clocks          ::*;
import GetPut          ::*;
import ClientServer    ::*;
import AxiDdr3Wrapper  ::*;
import AxiBits         ::*;
import AxiGather       ::*; 
import Axi4MasterSlave ::*;
import ConnectalClocks ::*;
`include "ConnectalProjectConfig.bsv"

typedef 30 Ddr3AddrWidth;
typedef 512 Ddr3DataWidth;

interface Ddr3;
   interface Axi4Slave#(Ddr3AddrWidth,Ddr3DataWidth,6) slave;
   interface AxiDdr3Ddr3 ddr3; // pins
   interface Clock uiClock;
   interface Reset uiReset;
endinterface

function Axi4SlaveBits#(Ddr3AddrWidth,Ddr3DataWidth,6,Empty) toAxiSlaveBits(AxiDdr3S_axi s_axi);
   return (interface Axi4SlaveBits;
      method araddr = s_axi.araddr;
      method arburst = s_axi.arburst;
      method arcache = s_axi.arcache;
      method Bit#(1) aresetn(); return 1; endmethod
      method arid = s_axi.arid;
      method arlen = s_axi.arlen;
      method Action arlock(Bit#(2) l); s_axi.arlock(truncate(l)); endmethod //unused
      method arprot = s_axi.arprot;
      method arqos = s_axi.arqos;
      method arready = s_axi.arready;
      method arsize = s_axi.arsize;
      method arvalid = s_axi.arvalid;
      method awaddr = s_axi.awaddr;
      method awburst = s_axi.awburst;
      method awcache = s_axi.awcache;
      method awid = s_axi.awid;
      method awlen = s_axi.awlen;
      method Action awlock(Bit#(2) l); s_axi.awlock(truncate(l)); endmethod //unused
      method awprot = s_axi.awprot;
      method awqos = s_axi.awqos;
      method awready = s_axi.awready;
      method awsize = s_axi.awsize;
      method awvalid = s_axi.awvalid;
      method bid = s_axi.bid;
      method bready = s_axi.bready;
      method bresp = s_axi.bresp;
      method bvalid = s_axi.bvalid;
      method rdata = s_axi.rdata;
      method rlast = s_axi.rlast;
      method rready = s_axi.rready;
      method rresp = s_axi.rresp;
      method rvalid = s_axi.rvalid;
      method wdata = s_axi.wdata;
      method Action wid(Bit#(6) tag); /* no wid method */ endmethod
      method wlast = s_axi.wlast;
      method wready = s_axi.wready;
      method wstrb = s_axi.wstrb;
      method wvalid = s_axi.wvalid;
      method rid = s_axi.rid;
      interface Empty extra; endinterface
      endinterface);
endfunction

(* synthesize *)
module mkDdr3#(Clock ddr3Clock)(Ddr3);
   let clock <- exposeCurrentClock();
   let reset <- exposeCurrentReset();
`ifndef BSV_POSITIVE_RESET
   let positiveReset <- mkPositiveReset(10, reset, clock);
   let mcReset = positiveReset.positiveReset;
`else
   let mcReset = reset;
`endif

   //fixme mc.aresetn

   AxiDdr3     mc <- mkAxiDdr3(clock, mcReset, clock); // fixme clocks
   let ui_reset_n <- mkResetInverter(mc.ui_clk_sync_rst, clocked_by mc.ui_clk);
   let axiBits = toAxiSlaveBits(mc.s_axi);
   Axi4SlaveCommon#(Ddr3AddrWidth,Ddr3DataWidth,6,Empty) axiSlaveCommon <- mkAxi4SlaveGather(axiBits, clocked_by mc.ui_clk, reset_by ui_reset_n);

   rule misc_pins;
      mc.app.ref_req(0);
      mc.app.sr_req(0);
      mc.app.zq_req(0);
   endrule
   
   interface slave = axiSlaveCommon.server;
   interface ddr3 = mc.ddr3;
   interface Clock uiClock = mc.ui_clk;
   interface Reset uiReset = ui_reset_n;
endmodule
